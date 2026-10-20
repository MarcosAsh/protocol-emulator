`default_nettype none

// The ECP5 pads icepi/carrier_check.v uses, as yosys' TRELLIS_IO models them (T high lets
// go). The pulls are the testbench's.
module BB (
    input  wire I,
    input  wire T,
    output wire O,
    inout  wire B
);
  assign B = T ? 1'bz : I;
  assign O = B;
endmodule

module BBPD (
    input  wire I,
    input  wire T,
    output wire O,
    inout  wire B
);
  assign B = T ? 1'bz : I;
  assign O = B;
endmodule

module OBZ (
    input  wire I,
    input  wire T,
    output wire O
);
  assign O = T ? 1'bz : I;
endmodule
