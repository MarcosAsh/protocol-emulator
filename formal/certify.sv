// The load checker's walk, for any program, configuration, setup and certificate: an
// accepted walk checked every pc against the rows it then holds at the pc's successor and
// target, the full row at pc 0, each entry decoding as the layout below gives; a missed
// lookup's empty row is test_kernel.ml's. Program and data memory hold still through an
// accepted walk (gate.sv); a data word is free until its address has held two cycles.

module certify (input clk);
  (* anyconst *) wire [1:0] side_set_count;
  (* anyconst *) wire [4:0] capture_pin;
  (* anyconst *) wire capture_rising;
  (* anyconst *) wire [8:0] wrap_bottom, wrap_top;
  (* anyconst *) wire [15:0] period_fraction;
  (* anyconst *) wire [8:0] base;
  (* anyconst *) wire loaded_valid, single_edge;
  (* anyconst *) wire [15:0] loaded_value;
  (* anyseq *) wire check;
  // the pc the claims are about, and its word
  (* anyconst *) wire [8:0] g;
  (* anyconst *) wire [15:0] word_g;
  // a lookup at g, its purpose, the target it looks up and the entry it may find
  (* anyconst *) wire look;
  (* anyconst *) wire [8:0] t;
  (* anyconst *) wire [7:0] gi;
  (* anyseq *) wire [15:0] any_word;

  reg clear = 1;
  always @(posedge clk) clear <= 0;
`ifdef SHORT_WALK
  // the walk ended at pc 1, so only g up to 1 is walked
  always @* assume (g <= 9'd1);
`endif

  wire program_read_valid, data_read_valid, busy, finished, accepted;
  wire [8:0] program_read_value, data_read_value;
  wire [9:0] reject_pc;
  wire [4:0] reason;
  wire [3:0] sm;
  wire [1:0] purpose;
  wire [8:0] pc;
  wire next_fails, target_fails, falls_to_next;
  wire [1:0] k;
  wire [2:0] field;
  wire [7:0] sel, count, wide_count;
  wire [47:0] entry, acc;
  wire [8:0] walk_base;
  wire reading;
  wire [1:0] read_wait;
  wire [7:0] lo, hi, ptr, mid;
  wire [8:0] key, entry_tag;
  wire stored, read_done;
  wire [23:0] row_phase_lo, other_phase_lo;
  wire [23:0] row_phase_hi, other_phase_hi;
  wire [23:0] row_slope, other_slope;
  wire [23:0] row_offset_lo, other_offset_lo;
  wire [23:0] row_offset_hi, other_offset_hi;
  wire [23:0] row_arm_lo, other_arm_lo;
  wire [23:0] row_arm_hi, other_arm_hi;
  wire [15:0] row_period_lo, other_period_lo;
  wire [15:0] row_period_hi, other_period_hi;
  wire [15:0] row_x_lo, other_x_lo;
  wire [15:0] row_x_hi, other_x_hi;
  wire [15:0] row_y_lo, other_y_lo;
  wire [15:0] row_y_hi, other_y_hi;
  wire row_captured, other_captured;
  wire row_awaiting, other_awaiting;
  wire [265:0] row = {row_phase_lo, row_phase_hi, row_slope, row_offset_lo,
    row_offset_hi, row_arm_lo, row_arm_hi, row_period_lo, row_period_hi, row_x_lo,
    row_x_hi, row_y_lo, row_y_hi, row_captured, row_awaiting};
  wire [265:0] other = {other_phase_lo, other_phase_hi, other_slope, other_offset_lo,
    other_offset_hi, other_arm_lo, other_arm_hi, other_period_lo, other_period_hi,
    other_x_lo, other_x_hi, other_y_lo, other_y_hi, other_captured, other_awaiting};

  // A program word a cycle after its address. A data word is anything until its address
  // has held two cycles, the most either engine's turn takes (data_memory.mli); read_at is
  // registered, the same as data[data_at], so the memory's other reads below make no loop
  // through it.
  (* anyseq *) wire [15:0] any_data;
  reg [8:0] program_at, data_at, data_before;
  reg [15:0] data [0:511];
  reg [15:0] read_at;
  always @(posedge clk) begin
    program_at <= program_read_value;
    data_at <= data_read_value;
    data_before <= data_at;
    read_at <= data[data_read_value];
  end
  wire [15:0] data_word = data_at == data_before ? read_at : any_data;
  wire [15:0] program_word = program_at == g ? word_g : any_word;

  load_checker dut (
    .clock(clk), .clear(clear), .check(check), .abort(1'b0),
    .config$side_set_count(side_set_count), .config$capture_pin(capture_pin),
    .config$capture_rising(capture_rising), .config$wrap_bottom(wrap_bottom),
    .config$wrap_top(wrap_top), .config$period_fraction(period_fraction),
    .setup$base(base), .setup$loaded$valid(loaded_valid),
    .setup$loaded$value(loaded_value), .setup$single_edge(single_edge),
    .program_word(program_word), .data_word(data_word),
    .program_read$valid(program_read_valid), .program_read$value(program_read_value),
    .data_read$valid(data_read_valid), .data_read$value(data_read_value),
    .busy(busy), .finished(finished), .accepted(accepted), .reject_pc(reject_pc),
    .reason(reason),
    .sm(sm), .purpose(purpose), .pc(pc), .next_fails(next_fails),
    .target_fails(target_fails), .k(k), .field(field), .sel(sel), .count(count),
    .wide_count(wide_count), .entry(entry), .acc(acc), .walk_base(walk_base),
    .reading(reading), .read_wait(read_wait), .lo(lo), .hi(hi), .ptr(ptr), .mid(mid),
    .key(key), .entry_tag(entry_tag), .stored(stored), .read_done(read_done),
    .falls_to_next(falls_to_next),
    .row_phase_lo(row_phase_lo), .row_phase_hi(row_phase_hi), .row_slope(row_slope),
    .row_offset_lo(row_offset_lo), .row_offset_hi(row_offset_hi),
    .row_arm_lo(row_arm_lo), .row_arm_hi(row_arm_hi), .row_period_lo(row_period_lo),
    .row_period_hi(row_period_hi), .row_x_lo(row_x_lo), .row_x_hi(row_x_hi),
    .row_y_lo(row_y_lo), .row_y_hi(row_y_hi), .row_captured(row_captured),
    .row_awaiting(row_awaiting), .other_phase_lo(other_phase_lo),
    .other_phase_hi(other_phase_hi), .other_slope(other_slope),
    .other_offset_lo(other_offset_lo), .other_offset_hi(other_offset_hi),
    .other_arm_lo(other_arm_lo), .other_arm_hi(other_arm_hi),
    .other_period_lo(other_period_lo), .other_period_hi(other_period_hi),
    .other_x_lo(other_x_lo), .other_x_hi(other_x_hi), .other_y_lo(other_y_lo),
    .other_y_hi(other_y_hi), .other_captured(other_captured),
    .other_awaiting(other_awaiting));

  // The certificate's layout, as load_check.mli gives it: from the base, the counts, three
  // words an entry, the wide dictionary, three words an interval, then the narrow one, two
  // words an interval. An entry packs its pc, the captured and awaiting bits and seven
  // bit indices for the phase, arm, period, x and y, index 0 the whole range.
  wire [8:0] entries_at = base + 9'd2;
  wire [8:0] wide_at = entries_at + 9'd3 * count;
  wire [8:0] narrow_at = wide_at + 9'd3 * wide_count;
  function [47:0] three(input [8:0] at);
    three = {data[at], data[at + 9'd1], data[at + 9'd2]};
  endfunction
  wire [47:0] spec_entry = three(entries_at + 9'd3 * sel);
  function [47:0] data_entry(input [7:0] i);
    data_entry = three(entries_at + 9'd3 * i);
  endfunction
  function [47:0] wide_of(input [6:0] index, input [47:0] whole);
    wide_of = index == 0 ? whole : three(wide_at + 9'd3 * (index - 7'd1));
  endfunction
  function [31:0] narrow_of(input [6:0] index);
    reg [8:0] at;
    begin
      at = narrow_at + 9'd2 * (index - 7'd1);
      narrow_of = index == 0 ? 32'h0000ffff : {data[at], data[at + 9'd1]};
    end
  endfunction
  localparam [47:0] WHOLE_PHASE = 48'h8000007fffff, WHOLE_ARM = 48'h000000ffffff;
  localparam [71:0] FULL_SLOPE_OFFSET = 72'h000000_800000_7fffff;
  localparam [265:0] FULL_ROW =
    {WHOLE_PHASE, FULL_SLOPE_OFFSET, WHOLE_ARM, {3{32'h0000ffff}}, 2'b00};
  // a row field by field as the spec gives it, those from field on still whole
  function [265:0] spec_row(input [47:0] e, input [2:0] upto);
    reg [47:0] phase, arm;
    reg [31:0] period, x, y;
    begin
      phase = upto > 0 ? wide_of(e[36:30], WHOLE_PHASE) : WHOLE_PHASE;
      arm = upto > 1 ? wide_of(e[29:23], WHOLE_ARM) : WHOLE_ARM;
      period = upto > 2 ? narrow_of(e[22:16]) : 32'h0000ffff;
      x = upto > 3 ? narrow_of(e[15:9]) : 32'h0000ffff;
      y = upto > 4 ? narrow_of(e[8:2]) : 32'h0000ffff;
      spec_row = {phase, FULL_SLOPE_OFFSET, arm, period, x, y, e[38], e[37]};
    end
  endfunction

  // the interval the field being read names, and where it starts
  // read from the checker's entry, which the claims hold to spec_entry, so that no read of
  // the data memory takes its address from another
  wire [6:0] cur_index = field == 0 ? entry[36:30] : field == 1 ? entry[29:23]
    : field == 2 ? entry[22:16] : field == 3 ? entry[15:9] : entry[8:2];
  wire cur_wide = field < 2;
  wire [8:0] cur_at = cur_wide ? wide_at + 9'd3 * (cur_index - 7'd1)
    : narrow_at + 9'd2 * (cur_index - 7'd1);

  localparam IDLE = 0, HEADER = 1, WORD = 2, HEAD = 3, SEARCH = 5, ENTRY = 6, FIELD = 7,
    CHECK_NEXT = 10, ADVANCE = 11, RELOAD = 12, FINISH = 13;
  localparam STORING = 2, RELOADING = 3;
  // past g's check: advancing, reloading the row for g + 1, or finishing
  wire after_check = sm == ADVANCE || sm == RELOAD || sm == FINISH
    || purpose == RELOADING && (sm == ENTRY || sm == FIELD);
  wire begins = sm == IDLE && check;
  wire passes = sm == CHECK_NEXT && !next_fails && !target_fails;

  // whether this walk passed g, whether g fell through, and the next row it checked
  reg passed = 0, fell = 0;
  reg [265:0] next_of_g;
  always @(posedge clk)
    if (clear || begins) begin
      passed <= 0;
      fell <= 0;
    end else if (passes && pc == g) begin
      passed <= 1;
      fell <= falls_to_next;
      next_of_g <= other;
    end

  // entry gi as the layout has it, and its pc; and the entry at ptr's pc
  wire [47:0] entry_gi = three(entries_at + 9'd3 * gi);
  wire [8:0] tag_gi = entry_gi[47:39];
  wire [8:0] tag_ptr = data[entries_at + 9'd3 * ptr][15:7];

  // g's lookup found entry gi for t (hit), and the row it read (looked_up, from entry
  // looked_entry); the walk consumed entry gi (consumed), holding the row it read from
  // entry consumed_entry; and the row the walk held at t (at_t)
  wire finds = sm == SEARCH && purpose == {1'b0, look} && pc == g && lo < hi && read_done
    && entry_tag == key && mid == gi && key == t;
  wire consumes = stored && ptr == gi
    && (sm == ADVANCE && falls_to_next || sm == RELOAD);
  reg hit = 0, read_it = 0, consumed = 0, held_t = 0;
  reg [47:0] looked_entry, consumed_entry;
  reg [265:0] looked_up, consumed_row, at_t;
  always @(posedge clk)
    if (clear || begins) begin
      hit <= 0;
      read_it <= 0;
      consumed <= 0;
      held_t <= 0;
    end else begin
      if (finds) hit <= 1;
      if (hit && !read_it && sm == FIELD && field == 5) begin
        read_it <= 1;
        looked_up <= other;
        looked_entry <= entry;
      end
      if (consumes) begin
        consumed <= 1;
        consumed_row <= other;
        consumed_entry <= entry;
      end
      if (sm == CHECK_NEXT && pc == t) begin
        held_t <= 1;
        at_t <= row;
      end
    end

  always @* if (!clear) begin
    // every row the walk holds has no slope and the full offset, as phase_table.sby's
    // rows do
    if (busy) assert ({row_slope, row_offset_lo, row_offset_hi} == FULL_SLOPE_OFFSET);
    // the walk holds the full row at pc 0, which a lookup of 0 reads without a search
    if (busy && sm != FINISH && pc == 0) assert (row == FULL_ROW);
    // the row a lookup finds is the row the walk holds at its target
    if (finished && accepted && hit) assert (read_it && held_t && at_t == looked_up);
    if (finished && accepted) assert (passed);
    // each entry decodes to the row the layout gives
    if (sm == FIELD && field == 5)
      assert (entry == spec_entry && other == spec_row(entry, 5));
`ifndef NO_INVARIANT
    // the data word, the search's bounds and reads, and the head's
    assert (read_at == data[data_at]);
    if (busy && sm != HEADER) assert (ptr <= count);
    if (sm == HEADER)
      assert (ptr == 0 && pc == 0 && !consumed && !hit && !read_it && !held_t);
    if (sm == SEARCH) assert (lo <= hi && hi <= count && k == 0 && reading == (lo < hi));
    if (sm == SEARCH && lo < hi) assert (data_read_value == entries_at + 9'd3 * mid);
    if (sm == HEAD) assert (k == 0);
    if (sm == HEAD && ptr < count)
      assert (reading && data_read_value == entries_at + 9'd3 * ptr);
    if ((sm == SEARCH || sm == HEAD) && reading && read_wait != 0)
      assert (data_at == data_read_value);
    if ((sm == SEARCH || sm == HEAD) && reading && read_wait == 2'd2)
      assert (data_before == data_read_value);
    // past the head: stored says the entry at ptr is the next pc's, which is past this one
    if (busy && !(sm == HEADER || sm == WORD || sm == HEAD || sm == FINISH)) begin
      assert (stored == (ptr < count && {1'b0, tag_ptr} == {1'b0, pc} + 10'd1));
      if (ptr < count) assert (tag_ptr > pc);
    end
    // a successor is looked up only where the pc does not fall through, and one that falls
    // through to a stored entry decodes it
    if (purpose == 1 && (sm == SEARCH || sm == ENTRY || sm == FIELD))
      assert (!falls_to_next);
    if ((sm == ENTRY || sm == FIELD) && purpose == STORING)
      assert (falls_to_next && stored);
    if (sm == CHECK_NEXT && falls_to_next && stored) assert (purpose == STORING);
    // a stored entry's decode, and the row it leaves
    if ((sm == ENTRY || sm == FIELD) && (purpose == STORING || purpose == RELOADING))
      assert (sel == ptr && stored);
    if (sm == RELOAD || (sm == CHECK_NEXT || sm == ADVANCE) && falls_to_next && stored)
      assert (entry == data_entry(ptr) && other == spec_row(entry, 5));
    // entry gi is consumed at the pc before its own, and the walk holds its row there
    if (busy && sm != HEADER) assert (consumed == (ptr > gi));
    if (consumed)
      assert (consumed_entry == entry_gi && consumed_row == spec_row(consumed_entry, 5));
    if (consumed && busy) assert ({1'b0, pc} >= {1'b0, tag_gi});
    if (consumed && busy && sm != FINISH && pc == tag_gi) assert (row == consumed_row);
    if (busy) assert (held_t == (pc > t || pc == t && after_check));
    if (sm == IDLE && finished && accepted) assert (held_t);
    if (held_t && consumed && tag_gi == t) assert (at_t == consumed_row);
    // what g's lookup found
    if (hit && busy) assert (pc >= g);
    if (hit) assert (tag_gi == t && gi < count);
    if (hit && !read_it)
      assert (pc == g && purpose == {1'b0, look} && (sm == ENTRY || sm == FIELD)
              && sel == gi);
    if (hit && !read_it && sm == FIELD) assert (entry == entry_gi);
    if (read_it)
      assert (looked_entry == entry_gi && looked_up == spec_row(looked_entry, 5));
    if (hit && busy && pc > g) assert (read_it);
`endif
    if (sm == CHECK_NEXT && pc == g + 9'd1 && g != 9'd511 && fell)
      assert (row == next_of_g);
`ifndef NO_INVARIANT
    if (sm == FINISH) assert (pc == 9'd511);
    if (busy) assert (walk_base == base);
    // an entry's words as they arrive, then its row field by field, each word read once
    // its address has held
    if (sm == ENTRY)
      assert (reading && k <= 2'd2 && data_read_value == entries_at + 9'd3 * sel + k);
    if (sm == FIELD) assert (k <= (cur_wide ? 2'd2 : 2'd1));
    if (sm == FIELD && (field == 5 || cur_index == 0)) assert (k == 0);
    if (sm == FIELD && field < 5 && cur_index != 0)
      assert (reading && data_read_value == cur_at + k);
    if ((sm == ENTRY || sm == FIELD) && reading && read_wait != 0)
      assert (data_at == data_read_value);
    if ((sm == ENTRY || sm == FIELD) && reading && read_wait == 2'd2)
      assert (data_before == data_read_value);
    if (sm == FIELD && k == 2'd1) assert (acc[15:0] == data[cur_at]);
    if (sm == FIELD && k == 2'd2) assert (acc[31:0] == {data[cur_at], data[cur_at + 9'd1]});
    if (sm == ENTRY && k == 2'd1) assert (entry[15:0] == spec_entry[47:32]);
    if (sm == ENTRY && k == 2'd2) assert (entry[31:0] == spec_entry[47:16]);
    if (sm == FIELD) assert (entry == spec_entry && field <= 5);
    if (sm == FIELD) assert (other == spec_row(entry, field));
    // only a target's or a successor's lookup searches
    if (sm == SEARCH) assert (purpose <= 1);
    if (busy && pc > g) assert (passed);
    if (busy && (pc < g || pc == g && !after_check)) assert (!passed);
    if (after_check && pc == g) assert (passed);
    if (sm == IDLE && finished && accepted) assert (passed);
    if (passed && fell && sm == ADVANCE && pc == g) assert (other == next_of_g);
    if (passed && fell && busy && sm != FINISH && pc == g + 9'd1) assert (row == next_of_g);
    if (fell) assert (passed && g != 9'd511);
    // g's word stays in the walk until g + 1's comes, and a row that fell through is not
    // reloaded
    if (passed && busy && sm != FINISH && pc == g) assert (fell == falls_to_next);
    if (fell && pc == g)
      assert (sm != RELOAD && !(purpose == RELOADING && (sm == ENTRY || sm == FIELD)));
`endif
  end

  always @* if (!clear) begin
`ifdef SHORT_WALK
    cover (finished && accepted && g == 9'd1);
`endif
    cover (passes && pc == g && falls_to_next);
    cover (sm == CHECK_NEXT && pc == g + 9'd1 && fell);
  end
endmodule
