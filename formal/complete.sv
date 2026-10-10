// The load checker's verdict is Load_check.walk's, for any program, configuration, setup
// and certificate: the walk, a pc at a time over load_check_step (the kernel's conjuncts on
// whole rows), steps as the checker leaves each pc; when the checker finishes, it has its
// verdict, reject pc and reason; and while it walks, a rank falls every cycle, so it ends.
// Program and data memory hold still; a data word is free until its address has held two
// cycles (data_memory.mli). No abort: gate.sv covers a walk cut short.

module complete (input clk);
  (* anyconst *) wire [1:0] side_set_count;
  (* anyconst *) wire [4:0] capture_pin;
  (* anyconst *) wire capture_rising;
  (* anyconst *) wire [8:0] wrap_bottom, wrap_top;
  (* anyconst *) wire [15:0] period_fraction;
  (* anyconst *) wire [8:0] base;
  (* anyconst *) wire loaded_valid, single_edge;
  (* anyconst *) wire [15:0] loaded_value;
  (* anyseq *) wire check;

  reg clear = 1;
  always @(posedge clk) clear <= 0;
`ifdef SHORT_WALK
  localparam [8:0] LAST = 9'd1;
`else
  localparam [8:0] LAST = 9'd511;
`endif

  wire program_read_valid, data_read_valid, busy, finished, accepted;
  wire [8:0] program_read_value, data_read_value;
  wire [9:0] reject_pc;
  wire [4:0] reason;
  wire [3:0] sm;
  wire [2:0] purpose;
  wire [1:0] source;
  wire [8:0] pc, following, jump_target;
  wire next_fails, target_fails, falls_to_next, is_jump;
  wire [4:0] next_reason, target_reason;
  wire [1:0] k;
  wire [2:0] field;
  wire [7:0] sel, count, wide_count;
  wire [47:0] entry, acc;
  wire [8:0] walk_base;
  wire walk_loaded_valid, walk_single_edge;
  wire [15:0] walk_loaded_value;
  wire reading;
  wire [1:0] read_wait;
  wire [7:0] lo, hi, ptr, mid;
  wire [8:0] key, entry_tag;
  wire stored, read_done;
  wire [15:0] word;
  wire [8:0] walk_addr;
  wire checked_captured, checked_awaiting;
  // the conjuncts each way failed, in Kernel.Holds order
  wire [9:0] failed_next, failed_target;
  wire [23:0] row_phase_lo, row_phase_hi, row_offset_lo, row_offset_hi;
  wire [23:0] row_arm_lo, row_arm_hi;
  wire [15:0] row_period_lo, row_period_hi, row_x_lo, row_x_hi, row_y_lo, row_y_hi;
  wire row_captured, row_awaiting;
  wire [23:0] fell_phase_lo, fell_phase_hi, fell_offset_lo, fell_offset_hi;
  wire [23:0] fell_arm_lo, fell_arm_hi;
  wire [15:0] fell_period_lo, fell_period_hi, fell_x_lo, fell_x_hi, fell_y_lo, fell_y_hi;
  wire fell_captured, fell_awaiting;

  // Rows as Kernel.Row packs them, its first field at the top: the phase, the slope, the
  // offset, the period, x, y, the arm, the captured and awaiting bits, then the pins. The
  // checker keeps no slope and no pins, as every row it holds has them the full row's.
  localparam [439:0] FULL = 440'h8000007fffff0000008000007fffff0000ffff0000ffff0000ffff000000ffffff20001000000400020000004000200000080004000000;
  localparam [439:0] EMPTY = 440'h10000000000008000007fffff00000000000000000000000000000000000020001000000400020000004000200000080004000000;
  localparam [47:0] WHOLE_PHASE = 48'h8000007fffff, WHOLE_ARM = 48'h000000ffffff;
  localparam [31:0] WHOLE_NARROW = 32'h0000ffff;
  function [439:0] pack(input [47:0] phase, input [47:0] arm, input [31:0] period,
      input [31:0] x, input [31:0] y, input c, input a);
    pack = {phase, FULL[391:320], period, x, y, arm, c, a, FULL[173:0]};
  endfunction
  // what the checker holds of a row
  function [241:0] kept(input [439:0] r);
    kept = {r[439:392], r[367:174]};
  endfunction
  wire [241:0] row = {row_phase_lo, row_phase_hi, row_offset_lo, row_offset_hi,
    row_period_lo, row_period_hi, row_x_lo, row_x_hi, row_y_lo, row_y_hi, row_arm_lo,
    row_arm_hi, row_captured, row_awaiting};
  wire [241:0] fell = {fell_phase_lo, fell_phase_hi, fell_offset_lo, fell_offset_hi,
    fell_period_lo, fell_period_hi, fell_x_lo, fell_x_hi, fell_y_lo, fell_y_hi, fell_arm_lo,
    fell_arm_hi, fell_captured, fell_awaiting};
  // a row's field f as the checker reads it into acc: the phase, arm, period, x and y
  function [47:0] field_of(input [439:0] r, input [2:0] f);
    field_of = f == 0 ? r[439:392] : f == 1 ? r[223:176] : f == 2 ? {16'h0, r[319:288]}
      : f == 3 ? {16'h0, r[287:256]} : {16'h0, r[255:224]};
  endfunction

  // The program, and the certificate in the data memory, as the checker reads them: a
  // program word a cycle after its address; a data word anything until its address has
  // held two cycles, then the memory's. No read of the data memory takes its address from
  // another: each comes from a register (smt2 sees a loop through the memory otherwise).
  reg [15:0] prog [0:511];
  reg [15:0] data [0:511];
  (* anyseq *) wire [15:0] any_data;
  reg [8:0] program_at, data_at, data_before;
  reg [15:0] read_at;
  always @(posedge clk) begin
    program_at <= program_read_value;
    data_at <= data_read_value;
    data_before <= data_at;
    read_at <= data[data_read_value];
  end
  wire [15:0] data_word = data_at == data_before ? read_at : any_data;
  wire [15:0] program_word = prog[program_at];

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
    .sm(sm), .purpose(purpose), .source(source), .pc(pc), .following(following),
    .jump_target(jump_target), .next_fails(next_fails), .target_fails(target_fails),
    .next_reason(next_reason), .target_reason(target_reason),
    .falls_to_next(falls_to_next), .is_jump(is_jump), .k(k), .field(field), .sel(sel),
    .count(count), .wide_count(wide_count), .entry(entry), .acc(acc),
    .walk_base(walk_base), .walk_loaded_valid(walk_loaded_valid),
    .walk_loaded_value(walk_loaded_value), .walk_single_edge(walk_single_edge),
    .reading(reading), .read_wait(read_wait), .lo(lo), .hi(hi), .ptr(ptr), .mid(mid),
    .key(key), .entry_tag(entry_tag), .stored(stored), .read_done(read_done),
    .word(word), .walk_addr(walk_addr),
    .checked_captured(checked_captured), .checked_awaiting(checked_awaiting),
    .failed_next_phase(failed_next[9]), .failed_next_offset(failed_next[8]),
    .failed_next_period(failed_next[7]), .failed_next_x(failed_next[6]),
    .failed_next_y(failed_next[5]), .failed_next_arm(failed_next[4]),
    .failed_next_captured(failed_next[3]), .failed_next_awaiting(failed_next[2]),
    .failed_next_edge_a(failed_next[1]), .failed_next_edge_b(failed_next[0]),
    .failed_target_phase(failed_target[9]), .failed_target_offset(failed_target[8]),
    .failed_target_period(failed_target[7]), .failed_target_x(failed_target[6]),
    .failed_target_y(failed_target[5]), .failed_target_arm(failed_target[4]),
    .failed_target_captured(failed_target[3]), .failed_target_awaiting(failed_target[2]),
    .failed_target_edge_a(failed_target[1]), .failed_target_edge_b(failed_target[0]),
    .row_phase_lo(row_phase_lo), .row_phase_hi(row_phase_hi),
    .row_offset_lo(row_offset_lo), .row_offset_hi(row_offset_hi),
    .row_arm_lo(row_arm_lo), .row_arm_hi(row_arm_hi), .row_period_lo(row_period_lo),
    .row_period_hi(row_period_hi), .row_x_lo(row_x_lo), .row_x_hi(row_x_hi),
    .row_y_lo(row_y_lo), .row_y_hi(row_y_hi), .row_captured(row_captured),
    .row_awaiting(row_awaiting),
    .fell_phase_lo(fell_phase_lo), .fell_phase_hi(fell_phase_hi),
    .fell_offset_lo(fell_offset_lo), .fell_offset_hi(fell_offset_hi),
    .fell_arm_lo(fell_arm_lo), .fell_arm_hi(fell_arm_hi),
    .fell_period_lo(fell_period_lo), .fell_period_hi(fell_period_hi),
    .fell_x_lo(fell_x_lo), .fell_x_hi(fell_x_hi), .fell_y_lo(fell_y_lo),
    .fell_y_hi(fell_y_hi), .fell_captured(fell_captured), .fell_awaiting(fell_awaiting));

  // The certificate's layout, as load_check.mli gives it and Load_check.walk reads it: from
  // the base, the counts, three words an entry, the wide dictionary, three words an
  // interval, then the narrow one, two words an interval. An entry packs its pc, the
  // captured and awaiting bits and indices for the phase, arm, period, x and y, index 0 the
  // whole range.
  wire [15:0] count_word = data[base], wide_count_word = data[base + 9'd1];
  reg [7:0] r_count, r_wide_count;
  wire [8:0] entries_at = base + 9'd2;
  wire [8:0] wide_at = entries_at + 9'd3 * r_count;
  wire [8:0] narrow_at = wide_at + 9'd3 * r_wide_count;
  function [47:0] three(input [8:0] at);
    three = {data[at], data[at + 9'd1], data[at + 9'd2]};
  endfunction
  function [47:0] entry_of(input [7:0] i);
    entry_of = three(entries_at + 9'd3 * i);
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
  // an entry's row, its fields from f on still whole: Load_check.walk's decode at f = 5
  function [439:0] decode(input [47:0] e, input [2:0] f);
    decode = pack(f > 0 ? wide_of(e[36:30], WHOLE_PHASE) : WHOLE_PHASE,
      f > 1 ? wide_of(e[29:23], WHOLE_ARM) : WHOLE_ARM,
      f > 2 ? narrow_of(e[22:16]) : WHOLE_NARROW, f > 3 ? narrow_of(e[15:9]) : WHOLE_NARROW,
      f > 4 ? narrow_of(e[8:2]) : WHOLE_NARROW, e[38], e[37]);
  endfunction
  // Load_check.walk: at r_pc it holds r_row and has consumed r_ptr entries
  reg [8:0] r_pc;
  reg [439:0] r_row;
  reg [7:0] r_ptr;
  // the walk's verdict, once it has one: accepted, the pc it refuses at and why
  reg r_has_verdict, r_accepted;
  reg [9:0] r_reject_pc;
  reg [4:0] r_why;
  // the entry at r_ptr
  reg [47:0] r_entry;
  wire [47:0] r_entry_after = entry_of(r_ptr + 8'd1);
  wire r_has = r_ptr < r_count;
  wire [8:0] r_tag = r_entry[47:39];
  wire r_out_of_order = r_has && r_tag <= r_pc;
  wire r_stored = r_has && {1'b0, r_tag} == {1'b0, r_pc} + 10'd1;
  wire [15:0] r_word = prog[r_pc];
  wire [439:0] r_stored_row = decode(r_entry, 3'd5);
  wire [8:0] r_next_pc, r_target_pc;
  // The walk's lookups at r_pc, of its successor (n) and target (t): its binary search
  // over the entries, a probe as the checker makes one, the walk being the same whenever
  // it probes. The full row at pc 0, the entry's row on a hit, the empty row once the
  // search ends with none; a lookup not made is any row, which the walk must not need.
  reg [7:0] r_t_lo, r_t_hi, r_t_sel, r_n_lo, r_n_hi, r_n_sel;
  reg r_t_hit, r_n_hit;
  reg [47:0] r_t_entry, r_n_entry;
  wire [8:0] r_t_sum = {1'b0, r_t_lo} + {1'b0, r_t_hi};
  wire [8:0] r_n_sum = {1'b0, r_n_lo} + {1'b0, r_n_hi};
  wire [7:0] r_t_mid = r_t_sum[8:1], r_n_mid = r_n_sum[8:1];
  wire [47:0] r_t_probe = entry_of(r_t_mid), r_n_probe = entry_of(r_n_mid);
  (* anyseq *) wire [439:0] any_next, any_target;
  wire [439:0] r_t_row = r_target_pc == 0 ? FULL : r_t_hit ? decode(r_t_entry, 3'd5)
    : r_t_lo >= r_t_hi ? EMPTY : any_target;
  wire [439:0] r_n_row = r_next_pc == 0 ? FULL : r_n_hit ? decode(r_n_entry, 3'd5)
    : r_n_lo >= r_n_hi ? EMPTY : any_next;
  wire [439:0] r_after;
  wire r_fails;
  wire [4:0] r_reason;
  wire [2:0] r_ways;
  wire [9:0] r_next, r_target;
  load_check_step walk (
    .side_set_count(side_set_count), .fraction(period_fraction != 0),
    .loaded$valid(loaded_valid), .loaded$value(loaded_value),
    .capture$pin(capture_pin), .capture$rising(capture_rising),
    .capture$single_edge(single_edge), .wrap_top(wrap_top), .wrap_bottom(wrap_bottom),
    .pc(r_pc), .word(r_word), .row(r_row), .stored(r_stored),
    .stored_row(r_stored_row), .next(r_n_row), .target(r_t_row),
    .next_pc(r_next_pc), .target_pc(r_target_pc), .after(r_after), .fails(r_fails),
    .reason(r_reason),
    .conjuncts$in_time(r_ways[2]), .conjuncts$wide_a(r_ways[1]),
    .conjuncts$wide_b(r_ways[0]),
    .conjuncts$next$phase(r_next[9]), .conjuncts$next$offset(r_next[8]),
    .conjuncts$next$period(r_next[7]), .conjuncts$next$x(r_next[6]),
    .conjuncts$next$y(r_next[5]), .conjuncts$next$arm(r_next[4]),
    .conjuncts$next$captured(r_next[3]), .conjuncts$next$awaiting(r_next[2]),
    .conjuncts$next$edge_a(r_next[1]), .conjuncts$next$edge_b(r_next[0]),
    .conjuncts$target$phase(r_target[9]), .conjuncts$target$offset(r_target[8]),
    .conjuncts$target$period(r_target[7]), .conjuncts$target$x(r_target[6]),
    .conjuncts$target$y(r_target[5]), .conjuncts$target$arm(r_target[4]),
    .conjuncts$target$captured(r_target[3]), .conjuncts$target$awaiting(r_target[2]),
    .conjuncts$target$edge_a(r_target[1]), .conjuncts$target$edge_b(r_target[0]));


  localparam IDLE = 0, HEADER = 1, WORD = 2, HEAD = 3, TARGET = 4, SEARCH = 5, ENTRY = 6,
    FIELD = 7, CHECK = 8, FOLLOWING = 9, CHECK_NEXT = 10, FINISH = 11;
  localparam FOR_TARGET = 0, FOR_FOLLOWING = 1, STORING = 2, FALLING = 3, RELOADING = 4;
  localparam DICTIONARY = 0, EMPTY_SOURCE = 1, FALLEN = 2;
  wire begins = sm == IDLE && check;
  wire reloads = purpose == RELOADING && (sm == ENTRY || sm == FIELD);
  wire looping = sm == FIELD || sm == CHECK;
  wire passes = sm == CHECK_NEXT && !next_fails && !target_fails;
  // the checker leaves a pc it passed, with the next pc's row
  wire leaves = passes && !stored || sm == FIELD && field == 5 && purpose == RELOADING;
  // The walk decides as the checker does: an entry out of order at the head, then the
  // conjuncts once the lookups are made; past the last pc, accepted with every entry
  // consumed, else refused at pc 512. Reasons: the first failing conjunct's index in
  // Kernel.Conjuncts.to_list, an entry out of order 30, one left over 31.
  wire heads = sm == HEAD && (ptr >= count || read_done);
  wire decides = heads && r_out_of_order || sm == CHECK_NEXT && (r_out_of_order || r_fails);

  wire probes = sm == SEARCH && lo < hi && read_done;
  always @(posedge clk)
    if (begins) begin
      r_count <= count_word[7:0];
      r_wide_count <= wide_count_word[7:0];
      r_pc <= 0;
      r_row <= FULL;
      r_ptr <= 0;
      r_entry <= three(entries_at);
      r_has_verdict <= 0;
    end else if (!r_has_verdict && decides) begin
      r_has_verdict <= 1;
      r_accepted <= 0;
      r_reject_pc <= {1'b0, r_pc};
      r_why <= r_out_of_order ? 5'd30 : r_reason;
    end else if (!r_has_verdict && leaves) begin
      if (r_pc == LAST) begin
        r_has_verdict <= 1;
        r_accepted <= {1'b0, r_ptr} + r_stored == {1'b0, r_count};
        r_reject_pc <= 10'd512;
        r_why <= 5'd31;
      end else begin
        r_pc <= r_pc + 9'd1;
        r_row <= r_after;
        r_ptr <= r_ptr + r_stored;
        if (r_stored) r_entry <= r_entry_after;
      end
    end
  always @(posedge clk)
    if (begins || leaves && !r_has_verdict && !decides) begin
      r_t_lo <= 0;
      r_n_lo <= 0;
      r_t_hi <= begins ? count_word[7:0] : r_count;
      r_n_hi <= begins ? count_word[7:0] : r_count;
      r_t_hit <= 0;
      r_n_hit <= 0;
    end else if (probes && purpose == FOR_TARGET && !r_t_hit && r_t_lo < r_t_hi) begin
      if (r_t_probe[47:39] == r_target_pc) begin
        r_t_hit <= 1;
        r_t_sel <= r_t_mid;
        r_t_entry <= r_t_probe;
      end else if (r_t_probe[47:39] < r_target_pc) r_t_lo <= r_t_mid + 8'd1;
      else r_t_hi <= r_t_mid;
    end else if (probes && purpose == FOR_FOLLOWING && !r_n_hit && r_n_lo < r_n_hi) begin
      if (r_n_probe[47:39] == r_next_pc) begin
        r_n_hit <= 1;
        r_n_sel <= r_n_mid;
        r_n_entry <= r_n_probe;
      end else if (r_n_probe[47:39] < r_next_pc) r_n_lo <= r_n_mid + 8'd1;
      else r_n_hi <= r_n_mid;
    end

  // The theorem: the checker passes a pc only where the walk does, and finishes with the
  // walk's verdict.
  always @* if (!clear) begin
    if (leaves) assert (!r_has_verdict && !decides);
    if (finished)
      assert (r_has_verdict && accepted == r_accepted
              && (accepted || reject_pc == r_reject_pc && reason == r_why));
  end

  // And it ends: a rank falls every cycle of a walk. From the top, the pcs left, the stage
  // at a pc, the part of a lookup, the probes, words or fields left in it, the words left
  // in a field, and the cycles left of a read.
  wire [3:0] stage = sm == HEADER ? 4'd15 : sm == WORD ? 4'd14 : sm == HEAD ? 4'd13
    : sm == TARGET ? 4'd12 : sm == FOLLOWING ? 4'd10 : sm == CHECK_NEXT ? 4'd8
    : sm == FINISH ? 4'd0 : purpose == FOR_TARGET ? 4'd11 : purpose == RELOADING ? 4'd7
    : 4'd9;
  wire [1:0] part = sm == SEARCH ? 2'd3 : sm == ENTRY ? 2'd2 : looping ? 2'd1 : 2'd0;
  wire [7:0] left = sm == SEARCH ? hi - lo : sm == ENTRY ? {6'b0, 2'd2 - k}
    : looping ? {4'b0, 3'd5 - field, sm == FIELD} : sm == HEADER || sm == WORD ? {7'b0, ~k[0]}
    : 8'd0;
  wire [1:0] words = sm == FIELD ? 2'd2 - k : 2'd0;
  wire [26:0] rank = {LAST - pc, stage, part, left, words, 2'd3 - read_wait};
  reg [26:0] rank_before;
  reg busy_before = 0;
  always @(posedge clk) begin
    rank_before <= rank;
    busy_before <= busy;
  end
  always @* if (!clear && busy && busy_before) assert (rank < rank_before);

  // ---- invariants ----
  reg [3:0] sm_before;
  reg [8:0] walk_addr_before;
  reg warm = 0;
  always @(posedge clk) begin
    warm <= !clear;
    sm_before <= sm;
    walk_addr_before <= walk_addr;
  end

  // the row a way's checks are of, as the walk has it
  wire [439:0] way = purpose == FOR_TARGET ? r_t_row
    : purpose == FOR_FOLLOWING ? r_n_row
    : purpose == STORING ? r_stored_row : r_after;
  wire [47:0] way_field = field_of(way, field);
  wire [9:0] way_holds = purpose == FOR_TARGET ? r_target : r_next;
  wire [9:0] failed_way = purpose == FOR_TARGET ? failed_target : failed_next;
  // the conjuncts each field checks, in Kernel.Holds order: phase, offset, period, x, y,
  // arm, captured, awaiting, edge_a, edge_b; y's takes the rest
  function [9:0] checks(input [2:0] f);
    checks = f == 0 ? 10'b1000000000 : f == 1 ? 10'b0000010000 : f == 2 ? 10'b0010000000
      : f == 3 ? 10'b0001000000 : f == 4 ? 10'b0100101111 : 10'b0;
  endfunction
  function [9:0] checked_below(input [2:0] f);
    integer n;
    begin
      checked_below = 0;
      for (n = 0; n < 5; n = n + 1) if (n < f) checked_below = checked_below | checks(n);
    end
  endfunction
  // whether a pc checks each way: the target where it jumps past pc 0, the next row
  // where it falls through or goes past pc 0
  wire checks_target = is_jump && jump_target != 0;
  wire checks_next = falls_to_next || following != 0;
  wire in_lookup = sm == SEARCH || sm == ENTRY || looping;
  wire [47:0] sel_entry = entry_of(sel);
  // the interval the field being read names, and where it starts
  wire [6:0] field_index = field == 0 ? entry[36:30] : field == 1 ? entry[29:23]
    : field == 2 ? entry[22:16] : field == 3 ? entry[15:9] : entry[8:2];
  wire [8:0] field_at = field < 2 ? wide_at + 9'd3 * (field_index - 7'd1)
    : narrow_at + 9'd2 * (field_index - 7'd1);


`ifndef NO_INVARIANT
  always @* if (!clear) begin
    // the data word, the setup taken, the counts
    assert (read_at == data[data_at]);
    if (warm) assert (data_read_value == walk_addr_before);
    if (busy) assert (walk_base == base && walk_loaded_valid == loaded_valid
                      && walk_loaded_value == loaded_value && walk_single_edge == single_edge);
    assert (sm <= FINISH && purpose <= RELOADING && source <= FALLEN);
    if (sm == HEADER) assert (ptr == 0 && pc == 0 && k <= 1 && r_pc == 0 && r_ptr == 0
                              && r_row == FULL && !r_has_verdict && r_count == count_word[7:0]
                              && r_wide_count == wide_count_word[7:0]);
    if (sm == HEADER && k == 1) assert (count == r_count);
    if (busy && sm != HEADER) assert (count == r_count && wide_count == r_wide_count);
    if ((sm == HEADER) && reading) assert (walk_addr == base + k);
    if (sm == HEADER) assert (reading);
    // in step with the walk
    if (busy && sm != HEADER && sm != FINISH)
      assert (pc == r_pc && ptr == r_ptr && !r_has_verdict);
    if (sm == FINISH) assert (r_has_verdict && pc == LAST && r_reject_pc == 10'd512
                              && r_why == 5'd31 && r_accepted == (ptr == count));
    if (busy && sm != HEADER) assert (ptr <= count);
    if (busy && sm != FINISH && !reloads) assert (row == kept(r_row));
    if (busy) assert (pc <= LAST);
    if (busy && sm != HEADER && sm != FINISH) assert (r_row[391:368] == FULL[391:368]);
    if (sm == WORD) assert (k <= 1);
    if (sm == WORD && k == 1) assert (program_at == pc);
    if (busy && !(sm == HEADER || sm == WORD || sm == FINISH)) assert (word == r_word);
    if (busy && !(sm == HEADER || sm == WORD || sm == ENTRY || sm == FIELD)) assert (k == 0);
    // the head: an entry out of order refuses before the conjuncts
    if (sm == HEAD && ptr < count) assert (reading && walk_addr == entries_at + 9'd3 * ptr);
    if (busy && !(sm == HEADER || sm == WORD || sm == HEAD || sm == FINISH))
      assert (!r_out_of_order && stored == r_stored);
    // reads: the address held, then the word
    if (reading && read_wait != 0) assert (data_read_value == walk_addr);
    if (reading && read_wait >= 2'd2) assert (data_at == walk_addr);
    if (reading && read_wait == 2'd3) assert (data_before == walk_addr);
    if (!reading) assert (read_wait == 0);
    // lookups: the key is the walk's successor, the search the walk's
    if (purpose == FOR_TARGET && in_lookup)
      assert (checks_target && key == jump_target && jump_target == r_target_pc);
    if (purpose == FOR_FOLLOWING && in_lookup)
      assert (!falls_to_next && key == following && following == r_next_pc && key != 0);
    if (sm == SEARCH) assert (purpose <= FOR_FOLLOWING && k == 0);
    if (sm == SEARCH) assert (lo <= hi && hi <= count && reading == (lo < hi));
    if (sm == SEARCH && purpose == FOR_TARGET) assert (lo == r_t_lo && hi == r_t_hi && !r_t_hit);
    if (sm == SEARCH && purpose == FOR_FOLLOWING)
      assert (lo == r_n_lo && hi == r_n_hi && !r_n_hit);
    // before a way's lookup, the walk's search for it is where it starts
    if (sm == HEADER || sm == WORD || sm == HEAD || sm == TARGET
        || purpose == FOR_TARGET && (sm == SEARCH || sm == ENTRY || looping) || sm == FOLLOWING)
      assert (r_n_lo == 0 && r_n_hi == r_count && !r_n_hit);
    if (sm == HEADER || sm == WORD || sm == HEAD || sm == TARGET
        || !checks_target && busy && sm != FINISH && !reloads)
      assert (r_t_lo == 0 && r_t_hi == r_count && !r_t_hit);
    if (busy && r_t_hit) assert (r_t_entry == entry_of(r_t_sel) && r_t_entry[47:39] == r_target_pc
                         && r_t_sel < r_count);
    if (busy && r_n_hit) assert (r_n_entry == entry_of(r_n_sel) && r_n_entry[47:39] == r_next_pc
                         && r_n_sel < r_count);
    if (busy) assert (r_t_lo <= r_t_hi && r_t_hi <= r_count
                                      && r_n_lo <= r_n_hi && r_n_hi <= r_count);
    // after the target's lookup, and the successor's, each ended
    if (checks_target && (sm == FOLLOWING || sm == CHECK_NEXT || reloads || purpose != FOR_TARGET
        && purpose != RELOADING && (sm == SEARCH || sm == ENTRY || looping)))
      assert (r_t_hit || r_t_lo >= r_t_hi);
    if ((sm == CHECK_NEXT || reloads) && !falls_to_next && following != 0)
      assert (r_n_hit || r_n_lo >= r_n_hi);
    if (busy) assert (r_entry == entry_of(r_ptr));
    if (sm == SEARCH && lo < hi) assert (walk_addr == entries_at + 9'd3 * mid);
    if ((sm == ENTRY || looping && source == DICTIONARY) && purpose == FOR_TARGET)
      assert (r_t_hit && sel == r_t_sel);
    if ((sm == ENTRY || looping && source == DICTIONARY) && purpose == FOR_FOLLOWING)
      assert (r_n_hit && sel == r_n_sel);
    if (looping && source == EMPTY_SOURCE)
      assert (purpose == FOR_TARGET && !r_t_hit && r_t_lo >= r_t_hi
              || purpose == FOR_FOLLOWING && !r_n_hit && r_n_lo >= r_n_hi);
    if ((sm == ENTRY || looping) && (purpose == STORING || purpose == RELOADING))
      assert (sel == ptr && stored && (purpose == RELOADING || falls_to_next));
    if (looping && purpose == FALLING) assert (falls_to_next && !stored && source == FALLEN);
    if (looping && source == FALLEN) assert (purpose == FALLING);
    if (looping && purpose == RELOADING) assert (source == DICTIONARY && sm == FIELD);
    if (sm == ENTRY) assert (purpose != FALLING);
    if (sm == ENTRY) assert (reading && k <= 2'd2 && walk_addr == entries_at + 9'd3 * sel + k);
    if (sm == ENTRY && k == 2'd1) assert (entry[15:0] == sel_entry[47:32]);
    if (sm == ENTRY && k == 2'd2) assert (entry[31:0] == sel_entry[47:16]);
    if (looping && source == DICTIONARY) assert (entry == sel_entry);
    if (looping) assert (field <= (reloads ? 3'd5 : 3'd4));
    // a field's words from the dictionary named, as the walk decodes them
    if (looping && source != DICTIONARY) assert (k == 0 && !reading);
    if (sm == CHECK) assert (!reading);
    if (sm == FIELD && source == DICTIONARY) begin
      if (field == 5 || field_index == 0) assert (k == 0 && !reading);
      else assert (reading && k <= (field < 2 ? 2'd2 : 2'd1)
                   && walk_addr == field_at + k);
      if (k == 2'd1) assert (acc[15:0] == data[field_at]);
      if (k == 2'd2) assert (acc[31:0] == {data[field_at], data[field_at + 9'd1]});
    end
    if (sm == CHECK) assert (field < 2 ? acc == way_field : acc[31:0] == way_field[31:0]);
    if (looping && !reloads)
      assert (checked_captured == way[175] && checked_awaiting == way[174]);
    if (looping && purpose == FALLING || sm == CHECK_NEXT && falls_to_next && !stored)
      assert (fell == kept(r_after));
    if (reloads && sm == FIELD) assert (row == kept(decode(entry, field)));
    if (reloads && sm == FIELD) assert (entry == r_entry);
    // the conjuncts each way failed: the walk's, field by field, once checked
    if (sm == HEAD || sm == TARGET)
      assert (failed_next == 0 && failed_target == 0);
    if (purpose == FOR_TARGET && (sm == SEARCH || sm == ENTRY))
      assert (failed_target == 0 && failed_next == 0);
    if (purpose == FOR_TARGET && looping) begin
      assert (failed_target == (~r_target & checked_below(field)) && failed_next == 0);
    end
    if (sm == FOLLOWING || sm == CHECK_NEXT || reloads || purpose != FOR_TARGET
        && purpose != RELOADING && (sm == SEARCH || sm == ENTRY || looping))
      assert (checks_target ? failed_target == ~r_target
              : failed_target == 0 && r_target == 10'h3ff);
    if (sm == FOLLOWING || purpose != FOR_TARGET && purpose != RELOADING
        && (sm == SEARCH || sm == ENTRY))
      assert (failed_next == 0);
    if (purpose != FOR_TARGET && purpose != RELOADING && looping)
      assert (failed_next == (~r_next & checked_below(field)));
    if (sm == CHECK_NEXT || reloads)
      assert (checks_next ? failed_next == ~r_next : failed_next == 0 && r_next == 10'h3ff);
    if (sm == CHECK_NEXT)
      assert (falls_to_next ? purpose == (stored ? STORING : FALLING)
              : purpose == FOR_FOLLOWING);
    if (sm == CHECK_NEXT)
      assert ((next_fails || target_fails) == r_fails
              && (!r_fails || (next_fails ? next_reason : target_reason) == r_reason));
    if (reloads) assert (!r_fails && !r_out_of_order && stored);
    if (heads) assert (r_out_of_order == (ptr < count && entry_tag <= pc));
  end

`endif

  always @* if (!clear) begin
`ifdef SHORT_WALK
    cover (finished && accepted);
`endif
    cover (finished && !accepted && reason < 5'd29);
  end
endmodule
