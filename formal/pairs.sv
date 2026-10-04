// The parts of a two-copy miter that pair one copy's macro or host fifo with the other's.

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

// One host fifo, fields as flops.tcl gathers them. It holds used words: the head, then
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
