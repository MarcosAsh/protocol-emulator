// SPDX-License-Identifier: Apache-2.0
// Pico B as a CAN node at 500 kbit/s for the CAN act: Kevin O'Connor's can2040 on PIO 0,
// RX on GP10 from the transceiver's R, TX on GP11 to its D. can2040 ACKs every frame it
// receives whole, so the sender sees a dominant ACK slot. This prints each frame over USB
// and the parse errors can2040 counts. It sends nothing of its own.

#include <stdio.h>

#include <hardware/clocks.h>
#include <hardware/irq.h>
#include <pico/stdlib.h>

#include "can2040.h"

#define GPIO_RX 10
#define GPIO_TX 11
#define BITRATE 500000

static struct can2040 bus;

// written by the PIO interrupt and read by the loop: the act sends a frame every 2 ms,
// which the loop prints long before the next
static volatile struct can2040_msg last;
static volatile uint32_t received;
static volatile uint32_t overflows;

static void on_bus(struct can2040 *cd, uint32_t notify, struct can2040_msg *msg) {
  if (notify == CAN2040_NOTIFY_RX) {
    last = *msg;
    received++;
  } else if (notify == CAN2040_NOTIFY_ERROR) {
    overflows++;
  }
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
  for (;;) {
    if (received != printed) {
      struct can2040_msg msg = last;
      printed = received;
      printf("received id 0x%03lx dlc %lu", (unsigned long)(msg.id & 0x7ff),
             (unsigned long)msg.dlc);
      for (uint32_t i = 0; i < msg.dlc && i < 8; i++) printf(" %02x", msg.data[i]);
      printf("\n");
    }
    struct can2040_stats stats;
    can2040_get_statistics(&bus, &stats);
    if (stats.parse_error != parse_errors || overflows != overflowed) {
      parse_errors = stats.parse_error;
      overflowed = overflows;
      printf("parse errors %lu, overflows %lu\n", (unsigned long)parse_errors,
             (unsigned long)overflowed);
    }
  }
}
