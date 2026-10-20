// The ECP5 block RAM as the Icepi build uses it, after TN1264 (the ECP5 memory guide),
// trusted: port A only, 1024 x 18 at ADA[13:4], no output register, write through,
// INITVAL all 0, which is IHP's macro core (SRAM_1P_behavioral_bm_bist) on its 512 words
// with MEN and REN at CEA, WEN at WEA and every bit written. The core is cut, as gold.ys
// cuts the RTL's. Any other configuration stops the run. Port B, a reset, a chip select,
// ADA13 or a write of less than both bytes (ADA[1:0]) leaves DOA free from then on, as do
// DOA[17:16] always, so a build that uses one cannot pass.
module DP16KD (
  input DIA17, DIA16, DIA15, DIA14, DIA13, DIA12, DIA11, DIA10, DIA9, DIA8, DIA7, DIA6,
  input DIA5, DIA4, DIA3, DIA2, DIA1, DIA0,
  input ADA13, ADA12, ADA11, ADA10, ADA9, ADA8, ADA7, ADA6, ADA5, ADA4, ADA3, ADA2, ADA1,
  input ADA0,
  input CEA, OCEA, CLKA, WEA, RSTA,
  input CSA2, CSA1, CSA0,
  output DOA17, DOA16, DOA15, DOA14, DOA13, DOA12, DOA11, DOA10, DOA9, DOA8, DOA7, DOA6,
  output DOA5, DOA4, DOA3, DOA2, DOA1, DOA0,
  input DIB17, DIB16, DIB15, DIB14, DIB13, DIB12, DIB11, DIB10, DIB9, DIB8, DIB7, DIB6,
  input DIB5, DIB4, DIB3, DIB2, DIB1, DIB0,
  input ADB13, ADB12, ADB11, ADB10, ADB9, ADB8, ADB7, ADB6, ADB5, ADB4, ADB3, ADB2, ADB1,
  input ADB0,
  input CEB, OCEB, CLKB, WEB, RSTB,
  input CSB2, CSB1, CSB0,
  output DOB17, DOB16, DOB15, DOB14, DOB13, DOB12, DOB11, DOB10, DOB9, DOB8, DOB7, DOB6,
  output DOB5, DOB4, DOB3, DOB2, DOB1, DOB0
);
  parameter DATA_WIDTH_A = 18;
  parameter DATA_WIDTH_B = 18;
  parameter REGMODE_A = "NOREG";
  parameter REGMODE_B = "NOREG";
  parameter RESETMODE = "SYNC";
  parameter ASYNC_RESET_RELEASE = "SYNC";
  parameter CSDECODE_A = "0b000";
  parameter CSDECODE_B = "0b000";
  parameter WRITEMODE_A = "NORMAL";
  parameter WRITEMODE_B = "NORMAL";
  parameter CLKAMUX = "CLKA";
  parameter CLKBMUX = "CLKB";
  parameter GSR = "ENABLED";
  parameter INITVAL_00 = 320'h0;
  parameter INITVAL_01 = 320'h0;
  parameter INITVAL_02 = 320'h0;
  parameter INITVAL_03 = 320'h0;
  parameter INITVAL_04 = 320'h0;
  parameter INITVAL_05 = 320'h0;
  parameter INITVAL_06 = 320'h0;
  parameter INITVAL_07 = 320'h0;
  parameter INITVAL_08 = 320'h0;
  parameter INITVAL_09 = 320'h0;
  parameter INITVAL_0A = 320'h0;
  parameter INITVAL_0B = 320'h0;
  parameter INITVAL_0C = 320'h0;
  parameter INITVAL_0D = 320'h0;
  parameter INITVAL_0E = 320'h0;
  parameter INITVAL_0F = 320'h0;
  parameter INITVAL_10 = 320'h0;
  parameter INITVAL_11 = 320'h0;
  parameter INITVAL_12 = 320'h0;
  parameter INITVAL_13 = 320'h0;
  parameter INITVAL_14 = 320'h0;
  parameter INITVAL_15 = 320'h0;
  parameter INITVAL_16 = 320'h0;
  parameter INITVAL_17 = 320'h0;
  parameter INITVAL_18 = 320'h0;
  parameter INITVAL_19 = 320'h0;
  parameter INITVAL_1A = 320'h0;
  parameter INITVAL_1B = 320'h0;
  parameter INITVAL_1C = 320'h0;
  parameter INITVAL_1D = 320'h0;
  parameter INITVAL_1E = 320'h0;
  parameter INITVAL_1F = 320'h0;
  parameter INITVAL_20 = 320'h0;
  parameter INITVAL_21 = 320'h0;
  parameter INITVAL_22 = 320'h0;
  parameter INITVAL_23 = 320'h0;
  parameter INITVAL_24 = 320'h0;
  parameter INITVAL_25 = 320'h0;
  parameter INITVAL_26 = 320'h0;
  parameter INITVAL_27 = 320'h0;
  parameter INITVAL_28 = 320'h0;
  parameter INITVAL_29 = 320'h0;
  parameter INITVAL_2A = 320'h0;
  parameter INITVAL_2B = 320'h0;
  parameter INITVAL_2C = 320'h0;
  parameter INITVAL_2D = 320'h0;
  parameter INITVAL_2E = 320'h0;
  parameter INITVAL_2F = 320'h0;
  parameter INITVAL_30 = 320'h0;
  parameter INITVAL_31 = 320'h0;
  parameter INITVAL_32 = 320'h0;
  parameter INITVAL_33 = 320'h0;
  parameter INITVAL_34 = 320'h0;
  parameter INITVAL_35 = 320'h0;
  parameter INITVAL_36 = 320'h0;
  parameter INITVAL_37 = 320'h0;
  parameter INITVAL_38 = 320'h0;
  parameter INITVAL_39 = 320'h0;
  parameter INITVAL_3A = 320'h0;
  parameter INITVAL_3B = 320'h0;
  parameter INITVAL_3C = 320'h0;
  parameter INITVAL_3D = 320'h0;
  parameter INITVAL_3E = 320'h0;
  parameter INITVAL_3F = 320'h0;

  generate
    if (DATA_WIDTH_A != 18 || REGMODE_A != "NOREG" || WRITEMODE_A != "WRITETHROUGH"
      || CSDECODE_A != "0b000" || CLKAMUX != "CLKA" || (
      INITVAL_00 | INITVAL_01 | INITVAL_02 | INITVAL_03 | INITVAL_04 | INITVAL_05 | INITVAL_06 | INITVAL_07 |
      INITVAL_08 | INITVAL_09 | INITVAL_0A | INITVAL_0B | INITVAL_0C | INITVAL_0D | INITVAL_0E | INITVAL_0F |
      INITVAL_10 | INITVAL_11 | INITVAL_12 | INITVAL_13 | INITVAL_14 | INITVAL_15 | INITVAL_16 | INITVAL_17 |
      INITVAL_18 | INITVAL_19 | INITVAL_1A | INITVAL_1B | INITVAL_1C | INITVAL_1D | INITVAL_1E | INITVAL_1F |
      INITVAL_20 | INITVAL_21 | INITVAL_22 | INITVAL_23 | INITVAL_24 | INITVAL_25 | INITVAL_26 | INITVAL_27 |
      INITVAL_28 | INITVAL_29 | INITVAL_2A | INITVAL_2B | INITVAL_2C | INITVAL_2D | INITVAL_2E | INITVAL_2F |
      INITVAL_30 | INITVAL_31 | INITVAL_32 | INITVAL_33 | INITVAL_34 | INITVAL_35 | INITVAL_36 | INITVAL_37 |
      INITVAL_38 | INITVAL_39 | INITVAL_3A | INITVAL_3B | INITVAL_3C | INITVAL_3D | INITVAL_3E | INITVAL_3F) != 0)
      $error("DP16KD: a configuration icepi_equiv does not model");
  endgenerate

  reg taken;

  initial taken = 0;

  wire [17:0] in_a = {DIA17, DIA16, DIA15, DIA14, DIA13, DIA12, DIA11, DIA10, DIA9, DIA8,
    DIA7, DIA6, DIA5, DIA4, DIA3, DIA2, DIA1, DIA0};
  wire other = CEB | WEB | RSTB | RSTA | CSA2 | CSA1 | CSA0 | ADA13 | (CEA & WEA & ~(ADA1 & ADA0));
  wire [17:0] free = $anyseq;
  wire [15:0] out_a;

  always @(posedge CLKA) taken <= taken | other;

  sram_core i_SRAM_1P_behavioral_bm_bist (
    .A_ADDR({ADA12, ADA11, ADA10, ADA9, ADA8, ADA7, ADA6, ADA5, ADA4}),
    .A_DIN(in_a[15:0]),
    .A_BM(16'hffff),
    .A_MEN(CEA),
    .A_WEN(WEA),
    .A_REN(CEA),
    .A_CLK(CLKA),
    .A_DLY(1'b1),
    .A_DOUT(out_a),
    .A_BIST_EN(1'b0),
    .A_BIST_ADDR(9'b0),
    .A_BIST_DIN(16'b0),
    .A_BIST_BM(16'b0),
    .A_BIST_MEN(1'b0),
    .A_BIST_WEN(1'b0),
    .A_BIST_REN(1'b0),
    .A_BIST_CLK(1'b0)
  );

  assign {DOA17, DOA16, DOA15, DOA14, DOA13, DOA12, DOA11, DOA10, DOA9, DOA8, DOA7, DOA6, DOA5,
    DOA4, DOA3, DOA2, DOA1, DOA0} = taken | other ? free : {free[17:16], out_a};
  assign {DOB17, DOB16, DOB15, DOB14, DOB13, DOB12, DOB11, DOB10, DOB9, DOB8, DOB7, DOB6, DOB5,
    DOB4, DOB3, DOB2, DOB1, DOB0} = free;
endmodule
