// The load checker's walk, for any program, configuration, setup and certificate: an
// accepted walk checked every pc, a field at a time, against the rows it then holds at the
// pc's successor and target, the full row at pc 0, each entry decoding as the layout below
// gives; a missed lookup's empty row and a skipped lookup's full row are test_kernel.ml's.
// Program and data memory hold still through an accepted walk (gate.sv); a data word is
// free until its address has held two cycles.

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
  wire [2:0] purpose;
  wire [1:0] source;
  wire [8:0] pc;
  wire next_fails, target_fails, falls_to_next, is_jump;
  wire [8:0] jump_target;
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
  wire [15:0] word;
  wire [8:0] walk_addr;
  wire checked_captured, checked_awaiting;
  wire failed_phase, failed_offset, failed_period, failed_x, failed_y, failed_arm,
    failed_captured, failed_awaiting, failed_edge_a, failed_edge_b;
  wire [9:0] failed_target = {failed_phase, failed_offset, failed_period, failed_x,
    failed_y, failed_arm, failed_captured, failed_awaiting, failed_edge_a, failed_edge_b};
  wire [23:0] row_phase_lo, row_phase_hi, row_offset_lo, row_offset_hi;
  wire [23:0] row_arm_lo, row_arm_hi;
  wire [15:0] row_period_lo, row_period_hi, row_x_lo, row_x_hi, row_y_lo, row_y_hi;
  wire row_captured, row_awaiting;
  wire [23:0] fell_phase_lo, fell_phase_hi, fell_arm_lo, fell_arm_hi;
  wire [15:0] fell_period_lo, fell_period_hi, fell_x_lo, fell_x_hi, fell_y_lo, fell_y_hi;
  wire fell_captured, fell_awaiting;
  // rows in one layout: the phase, the slope and offset, the arm, the period, x and y,
  // the captured and awaiting bits; the walk holds no slope and checks the offset as full
  localparam [47:0] WHOLE_PHASE = 48'h8000007fffff, WHOLE_ARM = 48'h000000ffffff;
  localparam [31:0] WHOLE_NARROW = 32'h0000ffff;
  localparam [71:0] FULL_SLOPE_OFFSET = 72'h000000_800000_7fffff;
  localparam [265:0] FULL_ROW =
    {WHOLE_PHASE, FULL_SLOPE_OFFSET, WHOLE_ARM, {3{WHOLE_NARROW}}, 2'b00};
  localparam [265:0] EMPTY_ROW =
    {48'h000001000000, FULL_SLOPE_OFFSET, 48'h0, 96'h0, 2'b00};
  wire [265:0] row = {row_phase_lo, row_phase_hi, 24'h0, row_offset_lo, row_offset_hi,
    row_arm_lo, row_arm_hi, row_period_lo, row_period_hi, row_x_lo, row_x_hi, row_y_lo,
    row_y_hi, row_captured, row_awaiting};
  wire [265:0] fell = {fell_phase_lo, fell_phase_hi, FULL_SLOPE_OFFSET, fell_arm_lo,
    fell_arm_hi, fell_period_lo, fell_period_hi, fell_x_lo, fell_x_hi, fell_y_lo,
    fell_y_hi, fell_captured, fell_awaiting};

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
    .sm(sm), .purpose(purpose), .source(source), .pc(pc), .next_fails(next_fails),
    .target_fails(target_fails), .is_jump(is_jump), .jump_target(jump_target), .k(k),
    .field(field), .sel(sel), .count(count), .wide_count(wide_count), .entry(entry),
    .acc(acc), .walk_base(walk_base), .reading(reading), .read_wait(read_wait), .lo(lo),
    .hi(hi), .ptr(ptr), .mid(mid), .key(key), .entry_tag(entry_tag), .stored(stored),
    .read_done(read_done), .word(word), .walk_addr(walk_addr),
    .falls_to_next(falls_to_next),
    .checked_captured(checked_captured), .checked_awaiting(checked_awaiting),
    .failed_phase(failed_phase), .failed_offset(failed_offset),
    .failed_period(failed_period), .failed_x(failed_x), .failed_y(failed_y),
    .failed_arm(failed_arm), .failed_captured(failed_captured),
    .failed_awaiting(failed_awaiting), .failed_edge_a(failed_edge_a),
    .failed_edge_b(failed_edge_b),
    .row_phase_lo(row_phase_lo), .row_phase_hi(row_phase_hi),
    .row_offset_lo(row_offset_lo), .row_offset_hi(row_offset_hi),
    .row_arm_lo(row_arm_lo), .row_arm_hi(row_arm_hi), .row_period_lo(row_period_lo),
    .row_period_hi(row_period_hi), .row_x_lo(row_x_lo), .row_x_hi(row_x_hi),
    .row_y_lo(row_y_lo), .row_y_hi(row_y_hi), .row_captured(row_captured),
    .row_awaiting(row_awaiting),
    .fell_phase_lo(fell_phase_lo), .fell_phase_hi(fell_phase_hi),
    .fell_arm_lo(fell_arm_lo), .fell_arm_hi(fell_arm_hi),
    .fell_period_lo(fell_period_lo), .fell_period_hi(fell_period_hi),
    .fell_x_lo(fell_x_lo), .fell_x_hi(fell_x_hi), .fell_y_lo(fell_y_lo),
    .fell_y_hi(fell_y_hi), .fell_captured(fell_captured), .fell_awaiting(fell_awaiting));

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
      narrow_of = index == 0 ? WHOLE_NARROW : {data[at], data[at + 9'd1]};
    end
  endfunction
  // [r] with its fields from [f] on whole, the marks [r]'s
  function [265:0] upto(input [265:0] r, input [2:0] f);
    upto = {f > 0 ? r[265:218] : WHOLE_PHASE, r[217:146], f > 1 ? r[145:98] : WHOLE_ARM,
      f > 2 ? r[97:66] : WHOLE_NARROW, f > 3 ? r[65:34] : WHOLE_NARROW,
      f > 4 ? r[33:2] : WHOLE_NARROW, r[1:0]};
  endfunction
  // a row field by field as the spec gives it, those from field on still whole
  function [265:0] spec_row(input [47:0] e, input [2:0] f);
    spec_row = upto({wide_of(e[36:30], WHOLE_PHASE), FULL_SLOPE_OFFSET,
      wide_of(e[29:23], WHOLE_ARM), narrow_of(e[22:16]), narrow_of(e[15:9]),
      narrow_of(e[8:2]), e[38], e[37]}, f);
  endfunction
  // a row's field as the checker's acc holds it, and the row with that field set from it
  function [47:0] field_of(input [265:0] r, input [2:0] f);
    field_of = f == 0 ? r[265:218] : f == 1 ? r[145:98] : f == 2 ? {16'h0, r[97:66]}
      : f == 3 ? {16'h0, r[65:34]} : {16'h0, r[33:2]};
  endfunction
  function [265:0] with_field(input [265:0] r, input [2:0] f, input [47:0] v);
    with_field = {f == 0 ? v : r[265:218], r[217:146], f == 1 ? v : r[145:98],
      f == 2 ? v[31:0] : r[97:66], f == 3 ? v[31:0] : r[65:34],
      f == 4 ? v[31:0] : r[33:2], r[1:0]};
  endfunction

  // the interval the field being read names, and where it starts
  // read from the checker's entry, which the claims hold to spec_entry, so that no read of
  // the data memory takes its address from another
  wire [6:0] cur_index = field == 0 ? entry[36:30] : field == 1 ? entry[29:23]
    : field == 2 ? entry[22:16] : field == 3 ? entry[15:9] : entry[8:2];
  wire cur_wide = field < 2;
  wire [8:0] cur_at = cur_wide ? wide_at + 9'd3 * (cur_index - 7'd1)
    : narrow_at + 9'd2 * (cur_index - 7'd1);

  localparam IDLE = 0, HEADER = 1, WORD = 2, HEAD = 3, TARGET = 4, SEARCH = 5, ENTRY = 6,
    FIELD = 7, CHECK = 8, FOLLOWING = 9, CHECK_NEXT = 10, FINISH = 11;
  localparam FOR_TARGET = 0, FOR_FOLLOWING = 1, STORING = 2, FALLING = 3, RELOADING = 4;
  localparam DICTIONARY = 0, EMPTY = 1, FALLEN = 2;
  // reading the next pc's row in place of this pc's, once this pc has passed
  wire reloads = purpose == RELOADING && (sm == ENTRY || sm == FIELD);
  wire looping = sm == FIELD || sm == CHECK;
  // past g's check: reloading the row for g + 1, or finishing
  wire after_check = sm == FINISH || reloads;
  wire begins = sm == IDLE && check;
  wire passes = sm == CHECK_NEXT && !next_fails && !target_fails;

  // What the walk checked of a way, field by field: a check takes the field in acc, and
  // the fields not yet checked are whole. Every check on a way is of one row, from the
  // dictionaries by an entry, the empty row, or the fall through image.
  reg [47:0] checked_phase, checked_arm;
  reg [31:0] checked_period, checked_x, checked_y;
  always @(posedge clk)
    if (sm == CHECK)
      case (field)
        0: checked_phase <= acc;
        1: checked_arm <= acc;
        2: checked_period <= acc[31:0];
        3: checked_x <= acc[31:0];
        default: checked_y <= acc[31:0];
      endcase
    else if (sm == TARGET || sm == FOLLOWING || sm == SEARCH || sm == ENTRY) begin
      checked_phase <= WHOLE_PHASE;
      checked_arm <= WHOLE_ARM;
      checked_period <= WHOLE_NARROW;
      checked_x <= WHOLE_NARROW;
      checked_y <= WHOLE_NARROW;
    end
  wire [265:0] checked = {checked_phase, FULL_SLOPE_OFFSET, checked_arm, checked_period,
    checked_x, checked_y, checked_captured, checked_awaiting};
  // the row checked once the field in acc is
  wire [265:0] checked_now = sm == CHECK ? with_field(checked, field, acc) : checked;
  // the row the way's checks are of, and so far
  wire [265:0] way_row = source == EMPTY ? EMPTY_ROW : source == FALLEN ? fell
    : spec_row(entry, 5);
  // the way's field being checked
  wire [47:0] way_field = field_of(way_row, field);
  // the fields below [f]
  function [4:0] below(input [2:0] f);
    below = (5'b1 << f) - 5'b1;
  endfunction
  // the fields each way checked at this pc
  reg [4:0] seen_target, seen_next;
  always @(posedge clk)
    if (sm == WORD) begin
      seen_target <= 0;
      seen_next <= 0;
    end else if (sm == CHECK) begin
      if (purpose == FOR_TARGET) seen_target[field] <= 1;
      else seen_next[field] <= 1;
    end

  // whether this walk passed g, whether g fell through, and the next row it checked, from
  // the entry it held
  reg passed = 0, fell_g = 0;
  reg [265:0] next_of_g;
  reg [47:0] next_entry_of_g;
  always @(posedge clk)
    if (clear || begins) begin
      passed <= 0;
      fell_g <= 0;
    end else if (passes && pc == g) begin
      passed <= 1;
      fell_g <= falls_to_next;
      next_of_g <= checked;
      next_entry_of_g <= entry;
    end

  // entry gi as the layout has it, and its pc; and the entry at ptr's pc
  wire [47:0] entry_gi = three(entries_at + 9'd3 * gi);
  wire [8:0] tag_gi = entry_gi[47:39];
  wire [8:0] tag_ptr = data[entries_at + 9'd3 * ptr][15:7];

  // g's lookup found entry gi for t (hit), and the row it checked (looked_up, from entry
  // looked_entry); the walk consumed entry gi (consumed), holding the row it read from
  // entry consumed_entry; and the row the walk held at t (at_t)
  wire finds = sm == SEARCH && purpose == {2'b0, look} && pc == g && lo < hi && read_done
    && entry_tag == key && mid == gi && key == t;
  wire consumes = stored && ptr == gi && sm == FIELD && field == 5 && purpose == RELOADING;
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
      if (hit && !read_it && sm == CHECK && field == 4) begin
        read_it <= 1;
        looked_up <= checked_now;
        looked_entry <= entry;
      end
      if (consumes) begin
        consumed <= 1;
        consumed_row <= row;
        consumed_entry <= entry;
      end
      if (sm == CHECK_NEXT && pc == t) begin
        held_t <= 1;
        at_t <= row;
      end
    end

  // A pc's checks are on one row and word, those it decides on; a way's on one purpose
  // and source. The data address is the walk's from the cycle before.
  reg [3:0] sm_before;
  reg [2:0] purpose_before;
  reg [1:0] source_before;
  reg [265:0] row_before;
  reg [15:0] word_before;
  reg [8:0] walk_addr_before;
  reg reloads_before;
  reg warm = 0;
  always @(posedge clk) begin
    warm <= !clear;
    sm_before <= sm;
    purpose_before <= purpose;
    source_before <= source;
    row_before <= row;
    word_before <= word;
    walk_addr_before <= walk_addr;
    reloads_before <= reloads;
  end
  wire walking = busy && sm != HEADER && sm != WORD && sm != FINISH && !reloads;
  wire walked_before = sm_before != IDLE && sm_before != HEADER && sm_before != WORD
    && sm_before != FINISH && !reloads_before;

  always @* if (!clear) begin
    if (warm && walking && walked_before) assert (row == row_before && word == word_before);
    if (warm && (looping || sm == CHECK_NEXT) && (sm_before == FIELD || sm_before == CHECK))
      assert (purpose == purpose_before && source == source_before);
    if (warm) assert (data_read_value == walk_addr_before);
    // every row the walk holds has the full offset, as phase_table.sby's rows do
    if (busy) assert ({row_offset_lo, row_offset_hi} == FULL_SLOPE_OFFSET[47:0]);
    // the walk holds the full row at pc 0, whose lookups it skips
    if (busy && sm != FINISH && pc == 0 && !reloads) assert (row == FULL_ROW);
    // a check takes each field of the way's row once, and a pc decides with them all: the
    // target's but where it is no jump or jumps to pc 0, the next row's but where it does
    // not fall through and goes to pc 0
    if (sm == CHECK)
      assert (field <= 4
              && !(purpose == FOR_TARGET ? seen_target[field] : seen_next[field]));
    if (sm == CHECK_NEXT) begin
      assert (is_jump && jump_target != 0 ? seen_target == 5'b11111
        : seen_target == 0 && failed_target == 0);
      assert (!falls_to_next && key == 0 ? seen_next == 0 : seen_next == 5'b11111);
    end
    // the row a lookup finds is the row the walk holds at its target
    if (finished && accepted && hit) assert (read_it && held_t && at_t == looked_up);
    if (finished && accepted) assert (passed);
    // each entry decodes to the row the layout gives; a missed lookup checks the empty row,
    // and a pc falling through with nothing stored the fall through image
    if (sm == CHECK && field == 4 && source == DICTIONARY)
      assert (entry == spec_entry && checked_now == spec_row(entry, 5));
    if (sm == CHECK && field == 4 && source == EMPTY) assert (checked_now == EMPTY_ROW);
    if (sm == CHECK_NEXT && purpose == FALLING) assert (checked == fell);
    if (sm == FIELD && field == 5) assert (entry == spec_entry && row == spec_row(entry, 5));
`ifndef NO_INVARIANT
    // the data word, the search's bounds and reads, and the head's
    assert (read_at == data[data_at]);
    if (busy && sm != HEADER) assert (ptr <= count);
    if (sm == HEADER)
      assert (ptr == 0 && pc == 0 && !consumed && !hit && !read_it && !held_t);
    if (sm == SEARCH) assert (lo <= hi && hi <= count && k == 0 && reading == (lo < hi));
    if (sm == SEARCH && lo < hi) assert (walk_addr == entries_at + 9'd3 * mid);
    // the word count is 0 but while words are read
    if (busy && !(sm == HEADER || sm == WORD || sm == ENTRY || sm == FIELD)) assert (k == 0);
    if (sm == HEAD && ptr < count)
      assert (reading && walk_addr == entries_at + 9'd3 * ptr);
    if ((sm == SEARCH || sm == HEAD) && reading && read_wait != 0) assert (data_read_value == walk_addr);
    if ((sm == SEARCH || sm == HEAD) && reading && read_wait >= 2'd2) assert (data_at == walk_addr);
    if ((sm == SEARCH || sm == HEAD) && reading && read_wait == 2'd3) assert (data_before == walk_addr);
    // past the head: stored says the entry at ptr is the next pc's, which is past this one
    if (busy && !(sm == HEADER || sm == WORD || sm == HEAD || sm == FINISH)) begin
      assert (stored == (ptr < count && {1'b0, tag_ptr} == {1'b0, pc} + 10'd1));
      if (ptr < count) assert (tag_ptr > pc);
    end
    // a successor is looked up only where the pc does not fall through; one that falls
    // through to a stored entry decodes it, and one with nothing stored checks the image
    if (purpose == FOR_FOLLOWING && (sm == SEARCH || sm == ENTRY || looping))
      assert (!falls_to_next);
    if (sm == SEARCH) assert (purpose == FOR_TARGET || purpose == FOR_FOLLOWING);
    if (sm == ENTRY) assert (purpose != FALLING);
    if ((sm == ENTRY || looping) && purpose == STORING) assert (falls_to_next && stored);
    if (looping && purpose == FALLING) assert (falls_to_next && !stored && source == FALLEN);
    if (looping && source == FALLEN) assert (purpose == FALLING);
    if (looping && source == EMPTY)
      assert (purpose == FOR_TARGET || purpose == FOR_FOLLOWING);
    if (sm == CHECK_NEXT)
      assert (falls_to_next ? purpose == (stored ? STORING : FALLING)
        : purpose == FOR_FOLLOWING);
    // a stored entry's decode, and the row it leaves
    if ((sm == ENTRY || looping) && (purpose == STORING || purpose == RELOADING))
      assert (sel == ptr && stored);
    if (looping && purpose == RELOADING) assert (source == DICTIONARY && sm == FIELD);
    // the state machines are in their states
    assert (sm <= FINISH && purpose <= RELOADING && source <= FALLEN);
    // the fields each way has checked so far: the target's only where it jumps past pc 0,
    // a field at a time, all of them before the successor's
    if (sm == HEAD || sm == TARGET)
      assert (seen_target == 0 && seen_next == 0 && failed_target == 0);
    if (purpose == FOR_TARGET && (sm == SEARCH || sm == ENTRY || looping)) begin
      assert (is_jump && jump_target != 0 && key == jump_target && seen_next == 0);
      assert (seen_target == (looping ? below(field) : 5'b0));
    end
    if (sm == FOLLOWING || sm == CHECK_NEXT
        || purpose != FOR_TARGET && purpose != RELOADING
           && (sm == SEARCH || sm == ENTRY || looping))
      assert (is_jump && jump_target != 0 ? seen_target == 5'b11111
        : seen_target == 0 && failed_target == 0);
    if (purpose != FOR_TARGET && purpose != RELOADING
        && (sm == SEARCH || sm == ENTRY || looping))
      assert (seen_next == (looping ? below(field) : 5'b0) && (!looping || field <= 4));
    if (sm == FOLLOWING) assert (seen_next == 0);
    if (purpose == FOR_FOLLOWING && (sm == SEARCH || sm == ENTRY || looping))
      assert (key != 0);
    if (sm == CHECK_NEXT && purpose == STORING)
      assert (entry == data_entry(ptr) && source == DICTIONARY
              && checked == spec_row(entry, 5));
    // entry gi is consumed at the pc before its own, and the walk holds its row there
    if (busy && sm != HEADER) assert (consumed == (ptr > gi));
    if (consumed)
      assert (consumed_entry == entry_gi && consumed_row == spec_row(consumed_entry, 5));
    if (consumed && busy) assert ({1'b0, pc} >= {1'b0, tag_gi});
    if (consumed && busy && sm != FINISH && pc == tag_gi && !reloads)
      assert (row == consumed_row);
    if (busy) assert (held_t == (pc > t || pc == t && after_check));
    if (sm == IDLE && finished && accepted) assert (held_t);
    if (held_t && consumed && tag_gi == t) assert (at_t == consumed_row);
    // what g's lookup found
    if (hit && busy) assert (pc >= g);
    if (hit) assert (tag_gi == t && gi < count);
    if (hit && !read_it)
      assert (pc == g && purpose == {2'b0, look} && (sm == ENTRY || looping)
              && sel == gi);
    if (hit && !read_it && looping) assert (entry == entry_gi && source == DICTIONARY);
    if (read_it)
      assert (looked_entry == entry_gi && looked_up == spec_row(looked_entry, 5));
    if (hit && busy && pc > g) assert (read_it);
`endif
    if (sm == CHECK_NEXT && pc == g + 9'd1 && g != 9'd511 && fell_g)
      assert (row == next_of_g);
`ifndef NO_INVARIANT
    if (sm == FINISH) assert (pc == 9'd511);
    if (busy) assert (walk_base == base);
    // an entry's words as they arrive, then its row field by field, each word read once
    // its address has held; the other sources read nothing
    if (sm == ENTRY)
      assert (reading && k <= 2'd2 && walk_addr == entries_at + 9'd3 * sel + k);
    if (looping && source != DICTIONARY) assert (k == 0 && !reading);
    if (sm == CHECK) assert (k == 0 && !reading);
    if (sm == FIELD && source == DICTIONARY) assert (k <= (cur_wide ? 2'd2 : 2'd1));
    if (sm == FIELD && source == DICTIONARY && (field == 5 || cur_index == 0))
      assert (k == 0);
    if (sm == FIELD && source == DICTIONARY && field < 5 && cur_index != 0)
      assert (reading && walk_addr == cur_at + k);
    if ((sm == ENTRY || sm == FIELD) && reading && read_wait != 0) assert (data_read_value == walk_addr);
    if ((sm == ENTRY || sm == FIELD) && reading && read_wait >= 2'd2) assert (data_at == walk_addr);
    if ((sm == ENTRY || sm == FIELD) && reading && read_wait == 2'd3) assert (data_before == walk_addr);
    if (sm == FIELD && source == DICTIONARY && k == 2'd1) assert (acc[15:0] == data[cur_at]);
    if (sm == FIELD && source == DICTIONARY && k == 2'd2)
      assert (acc[31:0] == {data[cur_at], data[cur_at + 9'd1]});
    if (sm == ENTRY && k == 2'd1) assert (entry[15:0] == spec_entry[47:32]);
    if (sm == ENTRY && k == 2'd2) assert (entry[31:0] == spec_entry[47:16]);
    if (looping && source == DICTIONARY) assert (entry == spec_entry);
    if (looping) assert (field <= (reloads ? 3'd5 : 3'd4));
    // the checks so far are of the way's row, and so is the reloaded row so far
    if (looping && !reloads) assert (checked == upto(way_row, field));
    // a narrow field's check reads acc's low half; the high words left over are ignored
    if (sm == CHECK)
      assert (field < 2 ? acc == way_field : acc[31:0] == way_field[31:0]);
    if (sm == FIELD && reloads) assert (row == spec_row(entry, field));
    // only a target's or a successor's lookup searches
    if (sm == SEARCH) assert (purpose <= 1);
    if (busy && pc > g) assert (passed);
    if (busy && (pc < g || pc == g && !after_check)) assert (!passed);
    if (after_check && pc == g) assert (passed);
    if (sm == IDLE && finished && accepted) assert (passed);
    if (passed && fell_g && pc == g && reloads)
      assert (stored && next_entry_of_g == data_entry(ptr)
              && next_of_g == spec_row(next_entry_of_g, 5));
    if (passed && fell_g && pc == g && reloads && sm == FIELD)
      assert (entry == next_entry_of_g);
    if (passed && fell_g && busy && sm != FINISH && pc == g + 9'd1 && !reloads)
      assert (row == next_of_g);
    if (fell_g) assert (passed && g != 9'd511);
    // g's word stays in the walk until g + 1's comes
    if (passed && busy && sm != FINISH && pc == g) assert (fell_g == falls_to_next);
`endif
  end

  always @* if (!clear) begin
`ifdef SHORT_WALK
    cover (finished && accepted && g == 9'd1);
`endif
    cover (passes && pc == g && falls_to_next);
    cover (sm == CHECK_NEXT && pc == g + 9'd1 && fell_g);
  end
endmodule
