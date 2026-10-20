// The ECP5's pad, cut on both sides of icepi_equiv as the PLL is: its pins become ports.
(* blackbox *)
module TRELLIS_IO (
  inout B,
  input I,
  input T,
  output O
);
  parameter DIR = "INPUT";
endmodule

