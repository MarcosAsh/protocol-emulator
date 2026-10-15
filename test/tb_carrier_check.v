`default_nettype none
`timescale 1ns / 1ps

// icepi/carrier_check.v with the carrier's pulls on its pins: up on the I2C lines, DQ,
// SWDIO and the flash's CS (headers 33 35 37 36 28), down elsewhere as the pads pull. A
// test drives pin n with ext_oe[n] and ext_out[n], in carrier_check.v's order.
module tb_carrier_check ();

  initial begin
    $dumpfile("tb_carrier_check.fst");
    $dumpvars(1, tb_carrier_check);
    #1;
  end

  reg clk;
  reg button_n = 1'b1;
  reg sck = 1'b0;
  reg mosi = 1'b0;
  reg cs_n = 1'b1;
  reg [20:0] ext_oe = 0;
  reg [20:0] ext_out = 0;
  wire [7:0] ui;
  wire [7:0] uo;
  wire [7:0] uio;
  wire usb_detach;
  wire miso = uo[0];
  wire dq = uio[4];
  wire [20:0] pins = {usb_detach, uio, uo[7:1], ui[7:3]};

  assign ui[0] = sck;
  assign ui[1] = mosi;
  assign ui[2] = cs_n;
  genvar i;
  generate
    for (i = 0; i < 5; i = i + 1) begin : in_pins
      assign ui[3+i] = ext_oe[i] ? ext_out[i] : 1'bz;
      pulldown (ui[3+i]);
    end
    for (i = 0; i < 7; i = i + 1) begin : out_pins
      assign uo[1+i] = ext_oe[5+i] ? ext_out[5+i] : 1'bz;
      if (i == 6) begin : cs
        pullup (uo[1+i]);
      end else begin : down
        pulldown (uo[1+i]);
      end
    end
    for (i = 0; i < 8; i = i + 1) begin : io_pins
      assign uio[i] = ext_oe[12+i] ? ext_out[12+i] : 1'bz;
      if (i >= 2 && i <= 5) begin : up
        pullup (uio[i]);
      end else begin : down
        pulldown (uio[i]);
      end
    end
  endgenerate
  assign usb_detach = ext_oe[20] ? ext_out[20] : 1'bz;
  pulldown (usb_detach);

  carrier_check dut (
      .clk(clk),
      .button_n(button_n),
      .ui(ui),
      .uo(uo),
      .uio(uio),
      .usb_dp(1'b0),
      .usb_dn(1'b0),
      .usb_pull_dp(),
      .usb_pull_dn(),
      .usb_detach(usb_detach)
  );

endmodule
