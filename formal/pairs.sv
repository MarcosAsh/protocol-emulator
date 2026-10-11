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

// A host fifo, fields as flops.tcl gathers them, first field last. It holds used words:
// the head, then used - 1 in words from the read address on, the first of those also in
// the read buffer, or in written when it was pushed on the edge that read it.
typedef struct packed {
  logic full, nearly_full, not_empty, used_gt_one, used_is_one;
  logic [3:0] write_address, read_address;
  logic [4:0] used_minus_1, used_plus_1, used;
} counters_t;

typedef struct packed {
  logic [15:0][15:0] words;
  logic [15:0] written, read_data, head;
  logic collision;
  counters_t counters;
} fifo_t;

// The two copies of a fifo laid out as fifo_t, of 2^ADDR words WORD wide, whose full
// takes nearly_full at NEARLY, agree on their counters, which agree with used, and on the
// words held; the rest, left from power-up, may differ.
module fifo_pair #(parameter WORD = 16, ADDR = 4, USED = 5, NEARLY = 15) (
  input check,
  input [(2 ** ADDR + 3) * WORD + 6 + 2 * ADDR + 3 * USED - 1:0] a, b
);
  localparam C = 5 + 2 * ADDR + 3 * USED;
  wire [C - 1:0] c = a[C - 1:0];
  wire [USED - 1:0] used = c[USED - 1:0];
  wire [USED - 1:0] used_plus_1 = c[2 * USED - 1:USED];
  wire [USED - 1:0] used_minus_1 = c[3 * USED - 1:2 * USED];
  wire [ADDR - 1:0] read_address = c[3 * USED + ADDR - 1:3 * USED];
  wire [ADDR - 1:0] write_address = c[3 * USED + 2 * ADDR - 1:3 * USED + ADDR];
  wire used_is_one = c[C - 5], used_gt_one = c[C - 4], not_empty = c[C - 3];
  wire nearly_full = c[C - 2], full = c[C - 1];
  function [WORD - 1:0] field(input [(2 ** ADDR + 3) * WORD + C:0] f, input integer n);
    field = f[C + 1 + n * WORD +: WORD];
  endfunction
  // head, read buffer, written, then the words from C + 1 + 3 WORD up
  wire collision_a = a[C], collision_b = b[C];
  wire [WORD - 1:0] buffer_a = collision_a ? field(a, 2) : field(a, 1);
  wire [WORD - 1:0] buffer_b = collision_b ? field(b, 2) : field(b, 1);
  // where the next word past the head goes
  wire [ADDR - 1:0] free = used == 0 ? read_address : read_address + used - 1'd1;

  always @* if (check) begin
    assert (c == b[C - 1:0]);
    assert (used <= NEARLY);
    assert (used_plus_1 == used + 1'd1 && used_minus_1 == used - 1'd1);
    assert (used_is_one == (used == 1) && used_gt_one == (used > 1));
    assert (not_empty == (used != 0) && nearly_full == (used >= NEARLY));
    assert (!full);
    assert (write_address == free);
    if (used >= 1) assert (field(a, 0) == field(b, 0));
    if (used >= 2) assert (buffer_a == buffer_b);
  end

  genvar n;
  generate
    for (n = 0; n < 2 ** ADDR; n = n + 1) begin : word
      wire [ADDR - 1:0] place = n - read_address;
      always @* if (check && used >= 2 && place < used - 1'd1)
        assert (field(a, 3 + n) == field(b, 3 + n));
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
