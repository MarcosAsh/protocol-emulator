// Power-up is deterministic. Two copies of the chip start from independent arbitrary
// states, every flop and fifo word, and see the same pins every cycle, rst_n low at the
// first edge and free after it. From the cycle after that edge on, their pins and the
// inputs of their five SRAM macros are equal, forever.
//
// Premise: the two copies' macros hold the same words after the first edge. A macro is its
// output register: a read takes a value, the same in both copies when both read the same
// way after the first edge, and a free one in each otherwise. The copies' writes are
// equal from then on, which is asserted, so the premise holds after it if it holds then.
//
// By induction on an invariant, also asserted: the copies agree on every flop outside the
// host fifos, on each macro's output from the second edge on, and on the words each fifo
// holds (fifo_pair). powerup.tcl brings the flops out. The teeth set NO_INVARIANT, so
// they fail on the claim alone.

module sram_pair (
  input clk,
  input first,
  input [5:0] ports_a,
  input [5:0] ports_b,
  output reg [15:0] dout_a,
  output reg [15:0] dout_b
);
  (* anyseq *) wire [15:0] shared, own_a, own_b;

  // ports_* are men, wen, ren and whether addr, din and bm are the same in both copies
  wire same = !first && ports_a == ports_b && &ports_a[2:0];
  always @(posedge clk) begin
    if (ports_a[5] && ports_a[3]) dout_a <= same ? shared : own_a;
    if (ports_b[5] && ports_b[3]) dout_b <= same ? shared : own_b;
  end
endmodule

// One host fifo, fields as powerup.tcl gathers them. It holds used words: the head, then
// used - 1 in words from the read address on, the first of those also in the read buffer,
// or in written when it was pushed on the edge that read it.
typedef struct packed {
  logic full, nearly_full, not_empty, used_gt_one, used_is_one;
  logic [2:0] write_address, read_address;
  logic [3:0] used_minus_1, used_plus_1, used;
} counters_t;

typedef struct packed {
  logic [7:0][15:0] words;
  logic [15:0] written, read_data, head;
  logic collision;
  counters_t counters;
} fifo_t;

// The two copies of a fifo agree on their counters, which agree with used, and on the
// words held; the rest, left from power-up, may differ.
module fifo_pair (input check, input fifo_t a, input fifo_t b);
  counters_t c;
  assign c = a.counters;
  // where the next word past the head goes
  wire [2:0] free = c.used == 0 ? c.read_address : c.read_address + c.used - 4'd1;
  wire [15:0] buffer_a = a.collision ? a.written : a.read_data;
  wire [15:0] buffer_b = b.collision ? b.written : b.read_data;

  always @* if (check) begin
    assert (a.counters == b.counters);
    assert (c.used <= 9);
    assert (c.used_plus_1 == c.used + 4'd1 && c.used_minus_1 == c.used - 4'd1);
    assert (c.used_is_one == (c.used == 1) && c.used_gt_one == (c.used > 1));
    assert (c.not_empty == (c.used != 0) && c.nearly_full == (c.used >= 8));
    assert (c.full == (c.used == 9));
    assert (c.write_address == free);
    if (c.used >= 1) assert (a.head == b.head);
    if (c.used >= 2) assert (buffer_a == buffer_b);
  end

  genvar n;
  generate
    for (n = 0; n < 8; n = n + 1) begin : word
      wire [2:0] place = n - c.read_address;
      always @* if (check && c.used >= 2 && place < c.used - 4'd1)
        assert (a.words[n] == b.words[n]);
    end
  endgenerate
endmodule

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
  wire [4:0] men_a, wen_a, ren_a, bist_a, men_b, wen_b, ren_b, bist_b;
  wire [8:0] addr_a[0:4], addr_b[0:4];
  wire [15:0] din_a[0:4], din_b[0:4], bm_a[0:4], bm_b[0:4], dout_a[0:4], dout_b[0:4];
  wire [`STATE_BITS - 1:0] state_a, state_b;
  fifo_t rx_0_a, tx_0_a, rx_1_a, tx_1_a, rx_2_a, tx_2_a, rx_3_a, tx_3_a;
  fifo_t rx_0_b, tx_0_b, rx_1_b, tx_1_b, rx_2_b, tx_2_b, rx_3_b, tx_3_b;

`define CHIP(side) \
  tt_um_marcosash_protocol_emulator side ( \
    .clk(clk), .rst_n(rst_n), .ena(ena), .ui_in(ui_in), .uio_in(uio_in), \
    .uo_out(uo_out_``side), .uio_out(uio_out_``side), .uio_oe(uio_oe_``side), \
    `PORTS(side, 0) `PORTS(side, 1) `PORTS(side, 2) `PORTS(side, 3) `PORTS(side, 4) \
    .state(state_``side), .rx_0(rx_0_``side), .tx_0(tx_0_``side), .rx_1(rx_1_``side), \
    .tx_1(tx_1_``side), .rx_2(rx_2_``side), .tx_2(tx_2_``side), .rx_3(rx_3_``side), \
    .tx_3(tx_3_``side) \
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
  `FIFO(rx_2)
  `FIFO(tx_2)
  `FIFO(rx_3)
  `FIFO(tx_3)
`endif

  genvar n;
  generate
    for (n = 0; n < 5; n = n + 1) begin : macro
      sram_pair pair (
        .clk(clk), .first(first),
        .ports_a({men_a[n], wen_a[n], ren_a[n], addr_a[n] == addr_b[n], din_a[n] == din_b[n],
                  bm_a[n] == bm_b[n]}),
        .ports_b({men_b[n], wen_b[n], ren_b[n], addr_a[n] == addr_b[n], din_a[n] == din_b[n],
                  bm_a[n] == bm_b[n]}),
        .dout_a(dout_a[n]), .dout_b(dout_b[n])
      );
      always @* if (!first)
        assert (addr_a[n] == addr_b[n] && din_a[n] == din_b[n] && bm_a[n] == bm_b[n]);
`ifndef NO_INVARIANT
      // each macro reads every cycle, so from the second edge on its output holds a word
      // the premise makes the same
      always @* if (warm) assert (dout_a[n] == dout_b[n]);
`endif
    end
  endgenerate

  always @* if (!first) begin
    assert (uo_out_a == uo_out_b);
    assert (uio_out_a == uio_out_b);
    assert (uio_oe_a == uio_oe_b);
    assert (men_a == men_b && wen_a == wen_b && ren_a == ren_b);
  end
  // the model above is the macro's with BIST off, as the RTL ties it
  always @* assert (bist_a == 0 && bist_b == 0);

`ifndef NO_INVARIANT
  // the invariant beside fifo_pair and the macros' outputs above
  always @* if (!first) assert (state_a == state_b);
`endif
endmodule
