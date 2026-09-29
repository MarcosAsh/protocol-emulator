// The IHP latch primitive, from its table in sg13cmos5l_udp.v where every input is 0 or
// 1, so that a latch cell in the netlist reads as a latch check.tcl rejects.

// follows d while clk is high
module ihp_latch (q, v, clk, d);
  output reg q;
  input v, clk, d;

  always @*
    if (clk) q = d;
endmodule
