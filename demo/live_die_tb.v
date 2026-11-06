`default_nettype none
`timescale 1ns / 1ps

// The chip on its own, for demo/live_die_stimulus.py. +dump=FILE writes the top module's
// nets to a VCD; on the gate level that is every cell's output.
module live_die_tb ();

  reg clk;
  reg rst_n;
  reg ena;
  reg [7:0] ui_in;
  reg [7:0] uio_in;
  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;

  tt_um_marcosash_protocol_emulator user_project (
      .ui_in  (ui_in),
      .uo_out (uo_out),
      .uio_in (uio_in),
      .uio_out(uio_out),
      .uio_oe (uio_oe),
      .ena    (ena),
      .clk    (clk),
      .rst_n  (rst_n)
  );

  reg [8*512-1:0] dump;
  initial begin
    if ($value$plusargs("dump=%s", dump)) begin
      $dumpfile(dump);
      $dumpvars(1, user_project);
    end
  end

endmodule
