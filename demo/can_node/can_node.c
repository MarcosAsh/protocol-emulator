// SPDX-License-Identifier: Apache-2.0
// Pico B as a CAN node at 500 kbit/s for the CAN acts: Kevin O'Connor's can2040 on PIO 0,
// RX on GP6 from the transceiver's R, TX on GP7 to its D. It ACKs and prints every whole
// frame and the parse errors it counts. ID REQUEST is answered after REPLY_DELAY_MS with
// REPLIES, REPLY_GAP_MS apart, each printed once ACKed: can2040 resends until one is.

#include <stdio.h>

#include <hardware/clocks.h>
#include <hardware/irq.h>
#include <pico/stdlib.h>

#include "can2040.h"

#define GPIO_RX 6
#define GPIO_TX 7
#define BITRATE 500000
#define REQUEST 0x7e0
// longer than Pico A takes to load the receiver into engine 0
#define REPLY_DELAY_MS 300
#define REPLY_GAP_MS 50

// python/demo_can_node.py's REPLIES, and lines demo/can_node/golden.c prints
static const struct can2040_msg replies[] = {
    {.id = 0x0a1, .dlc = 3, .data = {0x01, 0x02, 0x03}},
    {.id = 0x0a2 | CAN2040_ID_RTR, .dlc = 2},
    {.id = 0x6b1, .dlc = 8, .data = {0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff}},
    {.id = 0x000, .dlc = 2, .data = {0x00, 0x00}},
};
#define REPLIES (sizeof replies / sizeof replies[0])

static struct can2040 bus;

// written by the PIO interrupt and read by the loop: the act sends a frame every 2 ms,
// which the loop prints long before the next
static volatile struct can2040_msg last;
static volatile uint32_t received;
static volatile uint32_t overflows;
static volatile uint32_t transmitted;

static void on_bus(struct can2040 *cd, uint32_t notify, struct can2040_msg *msg) {
  if (notify == CAN2040_NOTIFY_RX) {
    last = *msg;
    received++;
  } else if (notify == CAN2040_NOTIFY_TX) {
    transmitted++;
  } else if (notify == CAN2040_NOTIFY_ERROR) {
    overflows++;
  }
}

static void print_msg(const char *what, const struct can2040_msg *msg) {
  printf("%s id 0x%03lx%s dlc %lu", what, (unsigned long)(msg->id & 0x7ff),
         (msg->id & CAN2040_ID_RTR) ? " remote" : "", (unsigned long)msg->dlc);
  if (!(msg->id & CAN2040_ID_RTR))
    for (uint32_t i = 0; i < msg->dlc && i < 8; i++) printf(" %02x", msg->data[i]);
}

static void on_pio_irq(void) { can2040_pio_irq_handler(&bus); }

int main(void) {
  stdio_init_all();
  can2040_setup(&bus, 0);
  can2040_callback_config(&bus, on_bus);
  irq_set_exclusive_handler(PIO0_IRQ_0, on_pio_irq);
  irq_set_priority(PIO0_IRQ_0, 1);
  irq_set_enabled(PIO0_IRQ_0, true);
  can2040_start(&bus, clock_get_hz(clk_sys), BITRATE, GPIO_RX, GPIO_TX);

  uint32_t printed = 0, parse_errors = 0, overflowed = 0;
  // the next reply, REPLIES when none is due, and whether it is with can2040
  uint32_t next = REPLIES, sending = 0, acked = 0, attempts = 0;
  absolute_time_t due = nil_time;
  for (;;) {
    if (received != printed) {
      struct can2040_msg msg = last;
      printed = received;
      print_msg("received", &msg);
      printf("\n");
      if ((msg.id & 0x7ff) == REQUEST && !(msg.id & CAN2040_ID_RTR) && next == REPLIES) {
        next = 0;
        due = make_timeout_time_ms(REPLY_DELAY_MS);
      }
    }
    struct can2040_stats stats;
    can2040_get_statistics(&bus, &stats);
    if (next < REPLIES && !sending && time_reached(due)) {
      acked = transmitted;
      attempts = stats.tx_attempt;
      struct can2040_msg msg = replies[next];
      can2040_transmit(&bus, &msg);
      sending = 1;
    } else if (sending && transmitted != acked) {
      print_msg("sent", &replies[next]);
      printf(", ACKed after %lu attempts\n", (unsigned long)(stats.tx_attempt - attempts));
      sending = 0;
      next++;
      due = make_timeout_time_ms(REPLY_GAP_MS);
    }
    if (stats.parse_error != parse_errors || overflows != overflowed) {
      parse_errors = stats.parse_error;
      overflowed = overflows;
      printf("parse errors %lu, overflows %lu\n", (unsigned long)parse_errors,
             (unsigned long)overflowed);
    }
  }
}
