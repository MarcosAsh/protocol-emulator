// IHP's macro core, SRAM_1P_behavioral_bm_bist at 512 x 16, as a cut point: DP16KD.v's
// instance of it on the netlist's side, the model's own on the RTL's (gold.ys).
(* blackbox *)
module sram_core (
  input [8:0] A_ADDR,
  input [15:0] A_DIN,
  input [15:0] A_BM,
  input A_MEN,
  input A_WEN,
  input A_REN,
  input A_CLK,
  input A_DLY,
  output [15:0] A_DOUT,
  input A_BIST_EN,
  input [8:0] A_BIST_ADDR,
  input [15:0] A_BIST_DIN,
  input [15:0] A_BIST_BM,
  input A_BIST_MEN,
  input A_BIST_WEN,
  input A_BIST_REN,
  input A_BIST_CLK
);
endmodule
