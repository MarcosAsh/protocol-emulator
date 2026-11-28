// The three user-defined primitives the IHP standard cells are built on, as modules because
// yosys can't read UDP tables. Each is its table from sg13cmos5l_udp.v where every input is 0
// or 1; the flop's notifier and x-clear inputs take no part. The cell models come from
// sg13cmos5l_stdcell.v with the specify blocks dropped, so at zero delay. cells.ys proves each
// cell equal to its Liberty function, which also checks these tables.

// z = s ? b : a
module ihp_mux2 (z, a, b, s);
  output z;
  input a, b, s;

  assign z = s ? b : a;
endmodule

// the columns are a b c d s0 s1: s1 picks the pair and s0 picks within it
module ihp_mux4 (z, a, b, c, d, s0, s1);
  output z;
  input a, b, c, d, s0, s1;

  assign z = s1 ? (s0 ? d : c) : (s0 ? b : a);
endmodule

// takes d on a rising clk, and is 0 while r is high whatever the clock does
module ihp_dff_r (q, v, clk, d, r, xcr);
  output reg q;
  input v, clk, d, r, xcr;

  always @(posedge clk or posedge r)
    if (r) q <= 1'b0;
    else q <= d;
endmodule
