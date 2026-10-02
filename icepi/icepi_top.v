/*
 * Copyright (c) 2026 Marcos Ashton
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// The chip on an Icepi Zero: its 50 MHz oscillator through the PLL to 48 MHz, the
// pins on the 40-pin header. With USB_UIO set, uio[1:0] are D+/D- on the first USB-C
// port with the board's pull-up on D- for low speed, and their header pins mirror the
// bus so a host can see a bus reset. The button is reset. MHZ 40 is for 10BASE-T,
// whose bit is four cycles. nextpnr times the clock from the dividers either way.
module icepi_top #(
    parameter USB_UIO = 1,
    parameter MHZ = 48
) (
    input  wire       clk,
    input  wire       button_n,
    input  wire [7:0] ui,
    output wire [7:0] uo,
    inout  wire [7:0] uio,
    inout  wire       usb_dp,
    inout  wire       usb_dn,
    output wire       usb_pull_dp,
    output wire       usb_pull_dn,
    input  wire       usb_detach
);

  wire clk_48;
  wire clk_feedback;
  wire locked;

  // ecppll -i 50 -o 48 --highres: 50 / 5 = 10 MHz at the phase detector, VCO 480 MHz,
  // which CLKOS divides by 10 for 48 MHz or 12 for 40.
  (* FREQUENCY_PIN_CLKI = "50" *)
  (* FREQUENCY_PIN_CLKOS = "48" *)
  (* ICP_CURRENT = "12" *)
  (* LPF_RESISTOR = "8" *)
  (* MFG_ENABLE_FILTEROPAMP = "1" *)
  (* MFG_GMCREF_SEL = "2" *)
  EHXPLLL #(
      .PLLRST_ENA("DISABLED"),
      .INTFB_WAKE("DISABLED"),
      .STDBY_ENABLE("DISABLED"),
      .DPHASE_SOURCE("DISABLED"),
      .OUTDIVIDER_MUXA("DIVA"),
      .OUTDIVIDER_MUXB("DIVB"),
      .OUTDIVIDER_MUXC("DIVC"),
      .OUTDIVIDER_MUXD("DIVD"),
      .CLKI_DIV(5),
      .CLKOP_ENABLE("ENABLED"),
      .CLKOP_DIV(48),
      .CLKOP_CPHASE(9),
      .CLKOP_FPHASE(0),
      .CLKOS_ENABLE("ENABLED"),
      .CLKOS_DIV(480 / MHZ),
      .CLKOS_CPHASE(0),
      .CLKOS_FPHASE(0),
      .FEEDBK_PATH("CLKOP"),
      .CLKFB_DIV(1)
  ) pll (
      .RST(1'b0),
      .STDBY(1'b0),
      .CLKI(clk),
      .CLKOP(clk_feedback),
      .CLKOS(clk_48),
      .CLKFB(clk_feedback),
      .CLKINTFB(),
      .PHASESEL0(1'b0),
      .PHASESEL1(1'b0),
      .PHASEDIR(1'b1),
      .PHASESTEP(1'b1),
      .PHASELOADREG(1'b1),
      .PLLWAKESYNC(1'b0),
      .ENCLKOP(1'b0),
      .LOCK(locked)
  );

  wire [7:0] uio_in;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;
  wire [7:0] header_in;
  wire [1:0] usb_in;

  wire [7:0] header_out = USB_UIO ? {uio_out[7:2], usb_in} : uio_out;
  wire [7:0] header_oe = USB_UIO ? {uio_oe[7:2], 2'b11} : uio_oe;
  wire [1:0] usb_oe = USB_UIO ? uio_oe[1:0] : 2'b00;

  BB uio_pad[7:0] (
      .B(uio),
      .I(header_out),
      .T(~header_oe),
      .O(header_in)
  );

  BB usb_pad[1:0] (
      .B({usb_dn, usb_dp}),
      .I(uio_out[1:0]),
      .T(~usb_oe),
      .O(usb_in)
  );

  assign uio_in = USB_UIO ? {header_in[7:2], usb_in} : header_in;

  // A pull pin driven high pulls its line up through a diode and 1.1 k; floating, it
  // leaves the line alone. Driven low it would add a host's 15 k pull-down.
  OBZ pull_dp_pad (
      .I(1'b0),
      .T(1'b1),
      .O(usb_pull_dp)
  );

  OBZ pull_dn_pad (
      .I(1'b1),
      .T(!USB_UIO || usb_detach),
      .O(usb_pull_dn)
  );

  // The core synchronises reset and its inputs itself.
  tt_um_marcosash_protocol_emulator chip (
      .ui_in(ui),
      .uo_out(uo),
      .uio_in(uio_in),
      .uio_out(uio_out),
      .uio_oe(uio_oe),
      .ena(1'b1),
      .clk(clk_48),
      .rst_n(locked & button_n)
  );

endmodule
