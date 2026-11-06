// The three user-defined primitives that the IHP standard cells in the netlist are built
// on, written as modules because yosys can't read UDP tables. Each is its table from
// sg13cmos5l_udp.v where every input is 0 or 1; the rows that carry x only matter to a
// simulator. The flop's notifier and x-clear inputs take no part, as in the original.
//
// The cell models themselves come from sg13cmos5l_stdcell.v with the specify blocks
// dropped, a name given to each primitive instance, and the delayed_ nets that the timing
// checks drive read as the pins they delay. That gives the models at zero delay. cells.ys
// proves each cell used in the netlist equal to its function in the Liberty file the flow
// synthesised against, which also checks these tables.

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
