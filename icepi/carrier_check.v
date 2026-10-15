/*
 * Copyright (c) 2026 Marcos Ashton
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// The bench carrier's self-test on an Icepi Zero, in place of the chip: Pico A drives and
// reads the other 21 header pins over the host port's four, SPI mode 0, an 11-byte frame
// each way, MSB first (python/carrier_pins.py). In: oe, out, a slot byte (bit 6 on, bit 7
// its level, bits 4:0 its pin), the slot's length and its sample time in us. Out: "pin",
// the pins as CS fell, then the slot's sample in bit 0 and bit 1 once taken. A whole frame
// takes effect as CS rises; its slot then drives its pin for its length, over oe and out,
// and samples the pin at its time. Pins idle let go and pulled down, but OUT1 (CAN's D)
// and OUT6 (the flash's CS) high. The button puts that back.
module carrier_check (
    input  wire       clk,
    input  wire       button_n,
    inout  wire [7:0] ui,
    inout  wire [7:0] uo,
    inout  wire [7:0] uio,
    input  wire       usb_dp,
    input  wire       usb_dn,
    output wire       usb_pull_dp,
    output wire       usb_pull_dn,
    inout  wire       usb_detach
);

  localparam [23:0] SIGNATURE = 24'h70696e;
  // OUT1 (pin 6) and OUT6 (pin 11)
  localparam [20:0] IDLE = 21'h000840;
  // the 50 MHz oscillator's cycles in a microsecond
  localparam US = 50;

  // pin n: IN0-IN4 (header 3 5 7 11 13), OUT0-OUT6 (8 10 12 18 22 26 28), IO0-IO7
  // (29 31 35 33 37 36 38 40), then header 15
  wire [20:0] pins = {usb_detach, uio, uo[7:1], ui[7:3]};

  reg [2:0] sck_s = 0;
  reg [2:0] mosi_s = 0;
  reg [2:0] cs_s = 3'b111;
  reg [20:0] pins_m = 0;
  reg [20:0] pins_s = 0;
  always @(posedge clk) begin
    sck_s  <= {sck_s[1:0], ui[0]};
    mosi_s <= {mosi_s[1:0], ui[1]};
    cs_s   <= {cs_s[1:0], ui[2]};
    pins_m <= pins;
    pins_s <= pins_m;
  end
  wire selected = !cs_s[1];
  wire cs_fell = cs_s[2] && !cs_s[1];
  wire cs_rose = !cs_s[2] && cs_s[1];
  wire sck_rose = !sck_s[2] && sck_s[1];
  wire sck_fell = sck_s[2] && !sck_s[1];

  reg [87:0] rx = 0;
  reg [87:0] tx = 0;
  reg [6:0] count = 0;
  reg [20:0] oe = IDLE;
  reg [20:0] out = IDLE;
  reg timing = 0;
  reg level = 0;
  reg [4:0] slot_pin = 0;
  reg [15:0] slot_length = 0;
  reg [15:0] slot_sample = 0;
  reg [15:0] us = 0;
  reg [5:0] tick = 0;
  reg sample = 0;
  reg taken = 0;

  always @(posedge clk) begin
    if (!button_n) begin
      oe <= IDLE;
      out <= IDLE;
      timing <= 0;
    end else begin
      if (cs_fell) begin
        tx <= {SIGNATURE, 3'b000, pins_s, 6'b000000, taken, sample, 32'd0};
        count <= 0;
      end else if (selected && sck_rose) begin
        rx <= {rx[86:0], mosi_s[1]};
        count <= count + 1;
      end else if (selected && sck_fell) begin
        tx <= {tx[86:0], 1'b0};
      end
      if (cs_rose && count == 88) begin
        oe <= rx[84:64];
        out <= rx[60:40];
        level <= rx[39];
        timing <= rx[38];
        slot_pin <= rx[36:32];
        slot_length <= rx[31:16];
        slot_sample <= rx[15:0];
        us <= 0;
        tick <= 0;
        taken <= 0;
      end else if (timing) begin
        tick <= tick == US - 1 ? 0 : tick + 1;
        if (tick == US - 1) us <= us + 1;
        if (tick == 0 && us == slot_sample) begin
          sample <= pins_s[slot_pin];
          taken  <= 1;
        end
        if (tick == 0 && us > slot_length && us > slot_sample) timing <= 0;
      end
    end
  end

  wire [20:0] slot = timing && us < slot_length ? 21'd1 << slot_pin : 21'd0;
  wire [20:0] drive_oe = oe | slot;
  wire [20:0] drive_out = (out & ~slot) | (level ? slot : 21'd0);

  genvar i;
  generate
    for (i = 0; i < 5; i = i + 1) begin : in_pins
      assign ui[3+i] = drive_oe[i] ? drive_out[i] : 1'bz;
    end
    for (i = 0; i < 7; i = i + 1) begin : out_pins
      assign uo[1+i] = drive_oe[5+i] ? drive_out[5+i] : 1'bz;
    end
    for (i = 0; i < 8; i = i + 1) begin : io_pins
      assign uio[i] = drive_oe[12+i] ? drive_out[12+i] : 1'bz;
    end
  endgenerate
  assign usb_detach = drive_oe[20] ? drive_out[20] : 1'bz;
  assign uo[0] = tx[87];
  assign usb_pull_dp = 1'bz;
  assign usb_pull_dn = 1'bz;

endmodule
