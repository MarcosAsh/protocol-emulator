// SPDX-License-Identifier: Apache-2.0
// Pico B as the bus master for the start hold act: every 20 ms the same 24LC256 read, a
// write of the address, then a read of four bytes, so two STARTs, SDA on GP2 and SCL on
// GP3 at 100 kHz. start_hold_pio calls pico-examples' pio_i2c as shipped, start_hold_hw
// the RP2040's I2C block. Once a second it prints its clocks and the hold they predict.

#include <stdio.h>

#include <hardware/clocks.h>
#include <pico/stdlib.h>

#ifdef START_HOLD_PIO
#include "pio_i2c.h"
#else
#include <hardware/i2c.h>
#endif

#define PIN_SDA 2
#define PIN_SCL 3
#define PERIOD_MS 20
#define BYTES 4

#ifdef START_HOLD_PIO

static const PIO pio = pio0;
static const uint sm = 0;

static void setup(void) {
  uint offset = pio_add_program(pio, &i2c_program);
  i2c_program_init(pio, sm, offset, PIN_SDA, PIN_SCL);
}

static int bus_write(uint8_t device, uint8_t *data, uint len) {
  return pio_i2c_write_blocking(pio, sm, device, data, len);
}

static int bus_read(uint8_t device, uint8_t *data, uint len) {
  return pio_i2c_read_blocking(pio, sm, device, data, len);
}

// pio_i2c_start runs SC1_SD0 [7], jmp x--, out exec, then SC0_SD0: SCL falls 10 PIO
// cycles after SDA
static void report(void) {
  uint32_t sys = clock_get_hz(clk_sys);
  uint32_t div = pio->sm[sm].clkdiv >> PIO_SM0_CLKDIV_FRAC_LSB;
  uint64_t hold_ps = 10ull * div * 1000000000000ull / 256 / sys;
  printf("pio_i2c: sys %lu Hz, clkdiv %lu+%lu/256, START hold 10 PIO cycles = %llu ps\n",
         (unsigned long)sys, (unsigned long)(div >> 8), (unsigned long)(div & 0xff),
         (unsigned long long)hold_ps);
}

#else

static void setup(void) {
  i2c_init(i2c1, 100000);
  gpio_set_function(PIN_SDA, GPIO_FUNC_I2C);
  gpio_set_function(PIN_SCL, GPIO_FUNC_I2C);
  gpio_pull_up(PIN_SDA);
  gpio_pull_up(PIN_SCL);
}

static int bus_write(uint8_t device, uint8_t *data, uint len) {
  return i2c_write_blocking(i2c1, device, data, len, false);
}

static int bus_read(uint8_t device, uint8_t *data, uint len) {
  return i2c_read_blocking(i2c1, device, data, len, false);
}

// the RP2040 datasheet's SCL high time is HCNT + SPKLEN + 7 cycles
static void report(void) {
  uint32_t sys = clock_get_hz(clk_sys);
  uint32_t hcnt = i2c1->hw->fs_scl_hcnt, spklen = i2c1->hw->fs_spklen;
  uint64_t high_ps = (uint64_t)(hcnt + spklen + 7) * 1000000000000ull / sys;
  printf("i2c1: sys %lu Hz, hcnt %lu, lcnt %lu, spklen %lu, SCL high %lu cycles = %llu ps\n",
         (unsigned long)sys, (unsigned long)hcnt, (unsigned long)i2c1->hw->fs_scl_lcnt,
         (unsigned long)spklen, (unsigned long)(hcnt + spklen + 7),
         (unsigned long long)high_ps);
}

#endif

int main(void) {
  stdio_init_all();
  setup();
  // the module answers at one of 0x50 to 0x57; the STARTs come whether it does or not
  uint8_t device = 0x50, byte;
  for (uint8_t probe = 0x50; probe < 0x58; probe++) {
    if (bus_read(probe, &byte, 1) >= 0) {
      device = probe;
      break;
    }
  }
  uint32_t reads = 0, nacks = 0;
  uint8_t address[2] = {0, 0}, data[BYTES] = {0};
  for (;;) {
    if (bus_write(device, address, sizeof address) < 0 || bus_read(device, data, BYTES) < 0)
      nacks++;
    if (++reads % (1000 / PERIOD_MS) == 0) {
      report();
      printf("0x%02x: %lu reads, %lu NACKed, last %02x %02x %02x %02x\n", device,
             (unsigned long)reads, (unsigned long)nacks, data[0], data[1], data[2], data[3]);
    }
    sleep_ms(PERIOD_MS);
  }
}
