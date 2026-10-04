// SPDX-License-Identifier: Apache-2.0
// can2040's own frame encoder run on the host, for test/test_can_node.ml's golden lines:
// can2040_transmit stuffs each frame into its transmit queue, printed from SOF to the
// CRC delimiter. Built against the can2040 commit demo/can_node/CMakeLists.txt pins, with
// SDK=<pico-sdk>/src and the include paths -I <can2040>/src -I $SDK/rp2040/hardware_regs/include
// -I $SDK/rp2040/hardware_structs/include -I $SDK/rp2_common/hardware_base/include.

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// the SDK's register types without its platform headers, nothing mapped: its own
// address_mapped.h is found but skipped
#define _HARDWARE_ADDRESS_MAPPED_H
#include "hardware/regs/addressmap.h"
typedef volatile uint32_t io_rw_32;
typedef const volatile uint32_t io_ro_32;
typedef volatile uint32_t io_wo_32;
typedef volatile uint16_t io_rw_16;
typedef const volatile uint16_t io_ro_16;
typedef volatile uint16_t io_wo_16;
typedef volatile uint8_t io_rw_8;
typedef const volatile uint8_t io_ro_8;
typedef volatile uint8_t io_wo_8;
#define _REG_(x)
static inline void hw_set_bits(io_rw_32 *addr, uint32_t mask) { *addr |= mask; }
static inline void hw_clear_bits(io_rw_32 *addr, uint32_t mask) { *addr &= ~mask; }
static inline void hw_write_masked(io_rw_32 *addr, uint32_t values, uint32_t mask) {
  *addr = (*addr & ~mask) | (values & mask);
}
// can2040's barriers are ARM instructions
#define __asm__
#define __volatile__(...)
#include "can2040.c"

static uint8_t pio[sizeof(pio_hw_t)];

// can2040_transmit's own steps again, for the length its queue does not keep
static uint32_t length(struct can2040_msg *msg) {
  uint32_t buf[5] = {0}, crc = 0;
  struct bitstuffer_s bs = {1, 0, buf};
  uint32_t rtr = msg->id & CAN2040_ID_RTR, dlc = msg->dlc & 0x0f;
  uint32_t data_len = rtr ? 0 : dlc > 8 ? 8 : dlc;
  uint32_t hdr = ((msg->id & 0x7ff) << 7) | dlc | (rtr ? 0x40 : 0);
  crc = crc_bytes(crc, hdr, 3);
  bs_push(&bs, hdr, 19);
  for (uint32_t i = 0; i < data_len; i++) {
    crc = crc_byte(crc, msg->data[i]);
    bs_push(&bs, msg->data[i], 8);
  }
  bs_push(&bs, crc & 0x7fff, 15);
  bs_pushraw(&bs, 1, 1);
  return bs.bitpos;
}

static void line(uint32_t id, uint32_t dlc, const uint8_t *data) {
  struct can2040 cd;
  memset(&cd, 0, sizeof cd);
  cd.pio_hw = pio;
  cd.gpio_tx = 0;
  struct can2040_msg msg = {.id = id, .dlc = dlc};
  memcpy(msg.data, data, 8);
  if (can2040_transmit(&cd, &msg)) abort();
  struct can2040_transmit *qt = &cd.tx_queue[0];
  uint32_t bits = length(&msg);
  if (bits > 32 * qt->stuffed_words) abort();
  printf("0x%03x %u %s 0x%04x", (unsigned)(id & 0x7ff), (unsigned)dlc,
         (id & CAN2040_ID_RTR) ? "remote" : "data", (unsigned)qt->crc);
  for (uint32_t i = 0; i < 8; i++) printf(" %02x", msg.data[i]);
  printf(" ");
  for (uint32_t i = 0; i < bits; i++)
    putchar((qt->stuffed_data[i / 32] >> (31 - i % 32)) & 1 ? '1' : '0');
  printf("\n");
}

int main(void) {
  static const uint8_t none[8] = {0};
  static const uint8_t bench_0x123[8] = {0xde, 0xad};
  static const uint8_t bench_0x555[8] = {0x00, 0xff, 0x55, 0xaa, 0x01, 0x80, 0x7f, 0xfe};
  static const uint8_t bench_0x000[8] = {0x01};
  static const uint8_t ones[8] = {0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff};
  static const uint8_t three[8] = {0x12, 0x34, 0x56};
  static const uint8_t counting[8] = {0x01, 0x02, 0x03};
  static const uint8_t two_zeros[8] = {0x00, 0x00};
  line(0x123, 2, bench_0x123);
  line(0x555, 8, bench_0x555);
  line(0x7ef, 0, none);
  line(0x000, 1, bench_0x000);
  line(0x000, 8, none);
  line(0x7ff, 8, ones);
  line(0x0f0 | CAN2040_ID_RTR, 4, none);
  line(0x2a5, 3, three);
  line(0x6b1, 12, ones);
  // demo/can_node.c's replies to the chip's request
  line(0x0a1, 3, counting);
  line(0x0a2 | CAN2040_ID_RTR, 2, none);
  line(0x6b1, 8, ones);
  line(0x000, 2, two_zeros);
  return 0;
}
