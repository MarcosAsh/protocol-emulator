`default_nettype none
`timescale 1ns / 1ps

// The Icepi Zero netlist behind tb.v's ports: rst_n is the button, ena attaches the USB
// pull-up, uio[1:0] are the USB pads and uio[7:2] the header's. The testbench drives a
// pad while the chip leaves it alone; uio_out and uio_oe are read off the pad cells.
module tb ();

  initial begin
    $dumpfile("tb.fst");
    $dumpvars(0, tb);
    #1;
  end

  reg clk;
  reg rst_n;
  reg ena;
  reg [7:0] ui_in;
  reg [7:0] uio_in;
  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;

  wire [7:0] uio;
  wire usb_dp;
  wire usb_dn;

  icepi_top icepi (
      .clk(clk),
      .button_n(rst_n),
      .ui(ui_in),
      .uo(uo_out),
      .uio(uio),
      .usb_dp(usb_dp),
      .usb_dn(usb_dn),
      .usb_pull_dp(),
      .usb_pull_dn(),
      .usb_detach(~ena)
  );

  assign uio_out = {
    icepi.\uio_pad[7] .I,
    icepi.\uio_pad[6] .I,
    icepi.\uio_pad[5] .I,
    icepi.\uio_pad[4] .I,
    icepi.\uio_pad[3] .I,
    icepi.\uio_pad[2] .I,
    icepi.\usb_pad[1] .I,
    icepi.\usb_pad[0] .I
  };

  assign uio_oe = ~{
    icepi.\uio_pad[7] .T,
    icepi.\uio_pad[6] .T,
    icepi.\uio_pad[5] .T,
    icepi.\uio_pad[4] .T,
    icepi.\uio_pad[3] .T,
    icepi.\uio_pad[2] .T,
    icepi.\usb_pad[1] .T,
    icepi.\usb_pad[0] .T
  };

  bufif0 header_drive[7:2] (uio[7:2], uio_in[7:2], uio_oe[7:2]);
  bufif0 usb_drive[1:0] ({usb_dn, usb_dp}, uio_in[1:0], uio_oe[1:0]);

endmodule
