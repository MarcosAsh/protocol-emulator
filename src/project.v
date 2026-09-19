/*
 * Copyright (c) 2026 Marcos Ashton
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// Trial hookup of the 512x16 SRAM macro. The host reads and writes one byte at a
// time: ui[4:0] is the low address, a bank register holds addr[8:5], ui[5] picks
// the byte within the word, ui[6] loads the bank from uio[3:0], ui[7] writes.
module tt_um_marcosash_sram_test (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

  assign uio_oe  = 8'b0;
  assign uio_out = 8'b0;

  wire       wen = ui_in[7];
  wire       bank_select = ui_in[6];
  wire       high_byte = ui_in[5];
  wire [4:0] addr_low = ui_in[4:0];
  reg  [3:0] bank;
  wire [8:0] addr = {bank_select ? uio_in[3:0] : bank, addr_low};
  wire [15:0] dout;

  always @(posedge clk) begin
    if (~rst_n) begin
      bank <= 0;
    end else if (bank_select) begin
      bank <= uio_in[3:0];
    end
  end

  assign uo_out = high_byte ? dout[15:8] : dout[7:0];

  RM_IHPSG13_1P_512x16_c2_bm_bist sram (
      .A_CLK(clk),
      .A_MEN(rst_n),
      .A_WEN(wen && !bank_select),
      .A_REN(~wen),
      .A_ADDR(addr),
      .A_DIN({uio_in, uio_in}),
      .A_DLY(1'b1),
      .A_DOUT(dout),
      .A_BM(high_byte ? 16'hff00 : 16'h00ff),
      .A_BIST_CLK(1'b0),
      .A_BIST_EN(1'b0),
      .A_BIST_MEN(1'b0),
      .A_BIST_WEN(1'b0),
      .A_BIST_REN(1'b0),
      .A_BIST_ADDR(9'b0),
      .A_BIST_DIN(16'b0),
      .A_BIST_BM(16'b0)
  );

  wire _unused = &{ena, 1'b0};

endmodule
