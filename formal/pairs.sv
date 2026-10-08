// The parts of a two-copy miter that pair one copy's macro, host fifo or load checker
// with the other's.

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

// The load checker's state, then the words and rows it keeps without a clear, fields as
// powerup.tcl gathers them.
typedef struct packed {
  logic [241:0] row;
  logic [9:0] failed_target, failed_next;
  logic [47:0] entry, acc;
  logic [15:0] word;
  logic [2:0] field;
  logic [1:0] k, source;
  logic [3:0] sm;
} load_checker_t;

// The two copies of the load checker agree on its state, and on each word and row from
// the walk's write of it on: the row from the check's start, the program word and failed
// conjuncts from the word's read, an entry or an interval a word at a time, k so far.
module load_checker_pair (input check, input load_checker_t a, input load_checker_t b);
  localparam IDLE = 0, HEADER = 1, WORD = 2, ENTRY = 6, FIELD = 7, CHECK = 8;
  localparam DICTIONARY = 0;
  wire [3:0] sm = a.sm;
  wire [47:0] read_in = a.k == 0 ? 48'h0 : a.k == 1 ? 48'hffff : 48'hffff_ffff;
  // a phase or an arm is three words, the rest two
  wire [47:0] interval = a.field < 2 ? {48{1'b1}} : 48'hffff_ffff;

  always @* if (check) begin
    assert (a.sm == b.sm && a.source == b.source && a.k == b.k && a.field == b.field);
    if (sm != IDLE) assert (a.row == b.row);
    if (sm != IDLE && sm != HEADER && sm != WORD) begin
      assert (a.word == b.word);
      assert (a.failed_next == b.failed_next && a.failed_target == b.failed_target);
    end
    if (sm == ENTRY) assert (((a.entry ^ b.entry) & read_in) == 0);
    if ((sm == FIELD || sm == CHECK) && a.source == DICTIONARY)
      assert (a.entry == b.entry);
    if (sm == FIELD) assert (((a.acc ^ b.acc) & read_in) == 0);
    if (sm == CHECK) assert (((a.acc ^ b.acc) & interval) == 0);
  end
endmodule
