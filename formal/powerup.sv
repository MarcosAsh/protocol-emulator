// Power-up is deterministic. Two copies of the chip start from independent arbitrary
// states, every flop and fifo word, and see the same pins every cycle, rst_n low at the
// first edge and free after it. From the cycle after that edge on, their pins and the
// inputs of their three SRAM macros are equal, forever.
//
// Premise: the two copies' macros hold the same words after the first edge. A macro is its
// output register: a read takes a value, the same in both copies when both read the same
// way after the first edge, and a free one in each otherwise. The copies' writes are
// equal from then on, which is asserted, so the premise holds after it if it holds then.
// With COLD a program macro's words are its own in each copy until its engine is first
// started: the cores reset halted, and Host.load fills all 512 words before a start. The
// data memory keeps the premise, as nothing fills it. The havoc tasks' RTL
// (powerup_havoc.awk) gives the host fifos' words and read buffers any value while the
// fifo is cleared.
//
// By induction on an invariant, also asserted: the copies agree on every flop outside the
// host fifos, on each macro's output from the second edge on, and on the words each fifo
// holds (fifo_pair). powerup.tcl brings the flops out. The teeth set NO_INVARIANT, so
// they fail on the claim alone.

`include "pairs.sv"

module powerup (input clk);
  (* anyseq *) wire rst_n, ena;
  (* anyseq *) wire [7:0] ui_in, uio_in;

  reg first = 1, warm = 0;
  always @(posedge clk) begin
    first <= 0;
    warm <= !first;
  end
`ifndef NO_RESET
  always @* if (first) assume (!rst_n);
`endif

  wire [7:0] uo_out_a, uio_out_a, uio_oe_a, uo_out_b, uio_out_b, uio_oe_b;
  wire [2:0] men_a, wen_a, ren_a, bist_a, men_b, wen_b, ren_b, bist_b;
  wire [8:0] addr_a[0:2], addr_b[0:2];
  wire [15:0] din_a[0:2], din_b[0:2], bm_a[0:2], bm_b[0:2], dout_a[0:2], dout_b[0:2];
  wire [`STATE_BITS - 1:0] state_a, state_b;
  wire [1:0] start_a, start_b, halted_a, halted_b, started_a, started_b, refill_a, refill_b;
  fifo_t rx_0_a, tx_0_a, rx_1_a, tx_1_a, rx_0_b, tx_0_b, rx_1_b, tx_1_b;

`define CHIP(side) \
  tt_um_marcosash_protocol_emulator side ( \
    .clk(clk), .rst_n(rst_n), .ena(ena), .ui_in(ui_in), .uio_in(uio_in), \
    .uo_out(uo_out_``side), .uio_out(uio_out_``side), .uio_oe(uio_oe_``side), \
    `PORTS(side, 0) `PORTS(side, 1) `PORTS(side, 2) \
    .state(state_``side), .start(start_``side), .halted(halted_``side), \
    .started(started_``side), .refill(refill_``side), \
    .rx_0(rx_0_``side), .tx_0(tx_0_``side), .rx_1(rx_1_``side), .tx_1(tx_1_``side) \
  );
`define PORTS(side, n) \
    .m``n``_men(men_``side[n]), .m``n``_wen(wen_``side[n]), .m``n``_ren(ren_``side[n]), \
    .m``n``_addr(addr_``side[n]), .m``n``_din(din_``side[n]), .m``n``_bm(bm_``side[n]), \
    .m``n``_bist_en(bist_``side[n]), .m``n``_dout(dout_``side[n]),
`define FIFO(name) fifo_pair name (.check(!first), .a(name``_a), .b(name``_b));

  `CHIP(a)
  `CHIP(b)
`ifndef NO_INVARIANT
  `FIFO(rx_0)
  `FIFO(tx_0)
  `FIFO(rx_1)
  `FIFO(tx_1)
`endif

  // which macros hold the host's words, the same in both copies: all of them, unless COLD,
  // and whether a macro's output holds a read of them
  reg [2:0] read_loaded = 0;
`ifdef COLD
  reg [1:0] ran = 0;
  wire [1:0] running = ran | (first ? 2'b00 : start_a);
  wire [2:0] loaded = {1'b1, running};
  always @(posedge clk) ran <= running;
`else
  wire [2:0] loaded = 3'b111;
`endif
  always @(posedge clk) read_loaded <= loaded;

  genvar n;
  generate
    for (n = 0; n < 3; n = n + 1) begin : macro
      sram_pair pair (
        .clk(clk), .first(first),
        .ports_a({men_a[n], wen_a[n], ren_a[n], loaded[n] && addr_a[n] == addr_b[n],
                  din_a[n] == din_b[n], bm_a[n] == bm_b[n]}),
        .ports_b({men_b[n], wen_b[n], ren_b[n], loaded[n] && addr_a[n] == addr_b[n],
                  din_a[n] == din_b[n], bm_a[n] == bm_b[n]}),
        .dout_a(dout_a[n]), .dout_b(dout_b[n])
      );
    end
  endgenerate

  always @* if (!first) begin
    assert (uo_out_a == uo_out_b);
    assert (uio_out_a == uio_out_b);
    assert (uio_oe_a == uio_oe_b);
    assert (men_a == men_b && wen_a == wen_b && ren_a == ren_b);
    assert (addr_a[0] == addr_b[0] && addr_a[1] == addr_b[1] && addr_a[2] == addr_b[2]);
    assert (din_a[0] == din_b[0] && din_a[1] == din_b[1] && din_a[2] == din_b[2]);
    assert (bm_a[0] == bm_b[0] && bm_a[1] == bm_b[1] && bm_a[2] == bm_b[2]);
  end
  // the model above is the macro's with BIST off, as the RTL ties it
  always @* assert (bist_a == 0 && bist_b == 0);

`ifndef NO_INVARIANT
  // the invariant beside fifo_pair; each macro reads every cycle, so from the second edge
  // on its output holds a word the premise makes the same
  always @* if (!first) assert (state_a == state_b);
  generate
    for (n = 0; n < 3; n = n + 1) begin : settled
      always @* if (warm && read_loaded[n]) assert (dout_a[n] == dout_b[n]);
    end
  endgenerate
  // the flags only ever rise
  always @* begin
    assert (!warm || !first);
    assert ((read_loaded | loaded) == loaded);
`ifdef COLD
    // an engine leaves halted, and fetches, only on a start
    if (!first) begin
      assert ((running | halted_a) == 2'b11);
      assert ((running | started_a | refill_a) == running);
    end
`endif
  end
`endif
endmodule
