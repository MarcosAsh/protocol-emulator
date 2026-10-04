`default_nettype none
`timescale 1ns / 1ps

// The chip with the outside parts BRINGUP.md wires to it. An SPI flash takes MOSI from
// OUT0, SCK from OUT1 and its chip select from the host, and answers on IN0:
// models/spiflash.v is picosoc's model from YosysHQ/picorv32 at commit ef203c2, unchanged.
// IO2 and IO3 are an I2C bus and IO4 a 1-Wire line, each pulled up: a cocotb model pulls
// one low through its *_o, the chip by enabling the pin's output, whose value is 0. A CAN
// bus is the AND of the transceivers' D: OUT1's, OUT2's once can_out2 joins it, and a
// cocotb node's can_o; each R gives it back after a loop delay, into IN1 for the chip.
module tb_outside ();

  initial begin
    $dumpfile("tb_outside.fst");
    $dumpvars(1, tb_outside);
    #1;
  end

  reg clk;
  reg rst_n;
  reg ena;
  reg [7:0] ui_in;
  reg flash_cs_n = 1'b1;
  reg sda_o = 1'b1;
  reg scl_o = 1'b1;
  reg dq_o = 1'b1;
  reg can_o = 1'b1;
  reg can_out2 = 1'b0;
  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;

  // nothing drives MISO between replies
  wire miso;
  pullup (miso);

  wire sda = sda_o & ~(uio_oe[2] & ~uio_out[2]);
  wire scl = scl_o & ~(uio_oe[3] & ~uio_out[3]);
  wire dq = dq_o & ~(uio_oe[4] & ~uio_out[4]);
  // whether the chip holds the 1-Wire line low, which a device times its slots by
  wire dq_held = uio_oe[4] & ~uio_out[4];
  // R follows the bus 100 ns late, for the transceivers and the wires
  wire can_bus = uo_out[2] & (uo_out[3] | ~can_out2) & can_o;
  wire can_rx;
  assign #100 can_rx = can_bus;

  tt_um_marcosash_protocol_emulator user_project (
      .ui_in  ({ui_in[7:5], can_rx, miso, ui_in[2:0]}),
      .uo_out (uo_out),
      .uio_in ({3'b000, dq, scl, sda, 2'b00}),
      .uio_out(uio_out),
      .uio_oe (uio_oe),
      .ena    (ena),
      .clk    (clk),
      .rst_n  (rst_n)
  );

  spiflash flash (
      .csb(flash_cs_n),
      .clk(uo_out[2]),
      .io0(uo_out[1]),
      .io1(miso),
      .io2(),
      .io3()
  );

endmodule
