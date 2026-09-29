// The kernel's check of one step for a watched pair, as row_step.sv states it for the
// offset: for any rows of intervals, word and state, an accepted row holding the core and
// its pair maps them into the row it goes to, for any next state kernel_step allows, and
// kernel_step spaces the pair's next edges. pair_step.sby proves it for every input;
// phase_step.sv's SPACING table assumes it.

module pair_step (
  input [1:0] side_set_count,
  input fraction, loads_period,
  input [15:0] loaded_period,
  input [4:0] capture_pin,
  input capture_rising, single_edge,
  // the spacing, as phase_step.sv's anyconsts give it
  input spaced, pair_dirs, side_set_pindirs,
  input [4:0] pin_a, pin_b, side_set_base, set_base, out_base, out_count,
  input [2:0] set_count,
  input [63:0] hold_a, apart_a, hold_b, apart_b,
  input [15:0] word,
  // rows of intervals, as phase_step.sv's SPACING table stores them
  input [367:0] row, next, target,
  // the core and the pair at this entry, and at the next as far as kernel_step fixes it
  input [23:0] phase, arm,
  input [15:0] period, x, y,
  input arm_known, captured, awaiting,
  input [15:0] since_a, since_b,
  input level_a, level_b, fresh_a, fresh_b, data_a, data_b,
  input [23:0] phase_after,
  input [15:0] period_after, x_after, y_after,
  // the row holds the core and the pair and the kernel accepts it; and the lemma
  output inside, holds
);
  function [439:0] row_of(input [367:0] r);
    row_of = {r[367:320], 24'd0, 24'h800000, 24'h7fffff, r[319:0]};
  endfunction
`define STEP_PAIR(valid) \
    .spacing$valid(valid), .spacing$value$a(pin_a), .spacing$value$b(pin_b), \
    .spacing$value$dirs(pair_dirs), .spacing$value$side_set_base(side_set_base), \
    .spacing$value$side_set_pindirs(side_set_pindirs), .spacing$value$set_base(set_base), \
    .spacing$value$set_count(set_count), .spacing$value$out_base(out_base), \
    .spacing$value$out_count(out_count), \
    .spacing$value$hold_a_0(hold_a[15:0]), .spacing$value$hold_a_1(hold_a[31:16]), \
    .spacing$value$hold_a_2(hold_a[47:32]), .spacing$value$hold_a_3(hold_a[63:48]), \
    .spacing$value$apart_a_0(apart_a[15:0]), .spacing$value$apart_a_1(apart_a[31:16]), \
    .spacing$value$apart_a_2(apart_a[47:32]), .spacing$value$apart_a_3(apart_a[63:48]), \
    .spacing$value$hold_b_0(hold_b[15:0]), .spacing$value$hold_b_1(hold_b[31:16]), \
    .spacing$value$hold_b_2(hold_b[47:32]), .spacing$value$hold_b_3(hold_b[63:48]), \
    .spacing$value$apart_b_0(apart_b[15:0]), .spacing$value$apart_b_1(apart_b[31:16]), \
    .spacing$value$apart_b_2(apart_b[47:32]), .spacing$value$apart_b_3(apart_b[63:48])
`define STEP_CONFIG \
    .side_set_count(side_set_count), .fraction(fraction), \
    .loaded$valid(loads_period), .loaded$value(loaded_period), \
    .capture$pin(capture_pin), .capture$rising(capture_rising), \
    .capture$single_edge(single_edge)

  wire [23:0] next_phase, next_arm;
  wire [15:0] next_period, next_x, next_y, next_since_a, next_since_b;
  wire bounded, may_carry, period_known, x_known, y_known, taken, taken_known;
  wire next_arm_known, next_captured, next_awaiting, capture_bounded, halts;
  wire next_level_a, next_level_b, next_fresh_a, next_fresh_b, wide_a, wide_b;
  kernel_step step (`STEP_CONFIG, `STEP_PAIR(spaced), .word(word), .arm(arm),
    .arm_known(arm_known), .captured(captured), .awaiting(awaiting),
    .a$since(since_a), .a$level(level_a), .a$fresh(fresh_a), .b$since(since_b),
    .b$level(level_b), .b$fresh(fresh_b), .data_a(data_a), .data_b(data_b),
    .next_awaiting(next_awaiting), .next_arm(next_arm), .next_arm_known(next_arm_known),
    .next_captured(next_captured), .capture_bounded(capture_bounded),
    .phase(phase), .period(period), .x(x), .y(y), .next_phase(next_phase),
    .bounded(bounded), .may_carry(may_carry), .next_period(next_period),
    .period_known(period_known), .next_x(next_x), .x_known(x_known), .next_y(next_y),
    .y_known(y_known), .taken(taken), .taken_known(taken_known),
    .next_a$since(next_since_a), .next_a$level(next_level_a), .next_a$fresh(next_fresh_a),
    .next_b$since(next_since_b), .next_b$level(next_level_b), .next_b$fresh(next_fresh_b),
    .wide_a(wide_a), .wide_b(wide_b), .halts(halts));

  // with no slope and the full offset, any offset is inside the row's
`define STEP_NOW \
    .a$since(since_a), .a$level(level_a), .a$fresh(fresh_a), .b$since(since_b), \
    .b$level(level_b), .b$fresh(fresh_b), .pc(9'd0), .word(word), .row(row_of(row)), \
    .next(row_of(next)), .target(row_of(target)), .phase(phase), .offset(phase), \
    .period(period), .x(x), .y(y), .arm(arm), .arm_known(arm_known), \
    .captured(captured), .awaiting(awaiting), .next_pc(), .target_pc(), .starts_open()
  wire accepts, within, into_next, into_target;
  kernel_accepts check (`STEP_CONFIG, .wrap_top(9'd0), .wrap_bottom(9'd0),
    `STEP_PAIR(spaced), `STEP_NOW, .accepts(accepts), .within(within));
`ifdef UNSPACED
  // the lemma's accepts checks no spacing
  wire unspaced_accepts;
  kernel_accepts check_unspaced (`STEP_CONFIG, .wrap_top(9'd0), .wrap_bottom(9'd0),
    `STEP_PAIR(1'b0), `STEP_NOW, .accepts(unspaced_accepts), .within());
  wire hypothesis = within && unspaced_accepts && side_set_count <= 2;
`else
  wire hypothesis = within && accepts && side_set_count <= 2;
`endif
  // the core and the pair after the step inside each successor, the kernel's own within
`define STEP_AFTER \
    .a$since(next_since_a), .a$level(next_level_a), .a$fresh(next_fresh_a), \
    .b$since(next_since_b), .b$level(next_level_b), .b$fresh(next_fresh_b), \
    .pc(9'd0), .word(word), .phase(phase_after), .offset(phase_after), \
    .period(period_after), .x(x_after), .y(y_after), .arm(next_arm), \
    .arm_known(next_arm_known), .captured(next_captured), .awaiting(next_awaiting), \
    .next_pc(), .target_pc(), .accepts(), .starts_open()
  kernel_accepts at_next (`STEP_CONFIG, .wrap_top(9'd0), .wrap_bottom(9'd0),
    `STEP_PAIR(spaced), `STEP_AFTER, .row(row_of(next)), .next(row_of(next)),
    .target(row_of(next)), .within(into_next));
  kernel_accepts at_target (`STEP_CONFIG, .wrap_top(9'd0), .wrap_bottom(9'd0),
    `STEP_PAIR(spaced), `STEP_AFTER, .row(row_of(target)), .next(row_of(target)),
    .target(row_of(target)), .within(into_target));

  wire [4:0] ds = word[12:8];
  wire [4:0] delay = side_set_count == 0 ? ds : side_set_count == 1 ? ds[3:0] : ds[2:0];
  wire [23:0] cycles = delay + 24'd1;
  // the next state is one kernel_step allows, as row_step.sv has it
  wire lands =
    (!bounded || phase_after == next_phase
      || may_carry && phase_after == next_phase - 24'd1)
    && (!capture_bounded || cycles + 24'd1 <= phase_after && phase_after <= next_phase)
    && (!period_known || period_after == next_period)
    && (!x_known || x_after == next_x) && (!y_known || y_after == next_y);

  assign inside = within && accepts && side_set_count <= 2;
  wire arrives = word[15:13] != 0 ? into_next
    : taken_known ? (taken ? into_target : into_next)
    : into_target && into_next;
  // a halt has no next entry, but its side-set still moves the pins
  assign holds = !spaced || !hypothesis || (halts || !lands || arrives) && wide_a && wide_b;
endmodule

`ifdef PAIR_STEP
// the lemma for every input, one opcode at a time, a wait one source at a time and the ALU
// one destination at a time, t's one operation at a time, the slowest one side-set width
// at a time; pair_step.sby's tasks between them take every word
module pair_step_proof;
  (* anyconst *) wire [1:0] side_set_count;
  (* anyconst *) wire fraction, loads_period, capture_rising, single_edge;
  (* anyconst *) wire spaced, pair_dirs, side_set_pindirs;
  (* anyconst *) wire [4:0] capture_pin, pin_a, pin_b, side_set_base, set_base, out_base;
  (* anyconst *) wire [4:0] out_count;
  (* anyconst *) wire [2:0] set_count;
  (* anyconst *) wire [63:0] hold_a, apart_a, hold_b, apart_b;
  (* anyconst *) wire [15:0] loaded_period, word;
  (* anyconst *) wire [367:0] row, next, target;
  (* anyconst *) wire [23:0] phase, arm, phase_after;
  (* anyconst *) wire [15:0] period, x, y, period_after, x_after, y_after;
  (* anyconst *) wire arm_known, captured, awaiting;
  (* anyconst *) wire [15:0] since_a, since_b;
  (* anyconst *) wire level_a, level_b, fresh_a, fresh_b, data_a, data_b;
  wire holds;
  pair_step lemma (
    .side_set_count(side_set_count), .fraction(fraction), .loads_period(loads_period),
    .loaded_period(loaded_period), .capture_pin(capture_pin),
    .capture_rising(capture_rising), .single_edge(single_edge), .spaced(spaced),
    .pair_dirs(pair_dirs), .side_set_pindirs(side_set_pindirs), .pin_a(pin_a),
    .pin_b(pin_b), .side_set_base(side_set_base), .set_base(set_base),
    .out_base(out_base), .out_count(out_count), .set_count(set_count), .hold_a(hold_a),
    .apart_a(apart_a), .hold_b(hold_b), .apart_b(apart_b), .word(word), .row(row),
    .next(next), .target(target), .phase(phase), .arm(arm), .period(period), .x(x),
    .y(y), .arm_known(arm_known), .captured(captured), .awaiting(awaiting),
    .since_a(since_a), .since_b(since_b), .level_a(level_a), .level_b(level_b),
    .fresh_a(fresh_a), .fresh_b(fresh_b), .data_a(data_a), .data_b(data_b),
    .phase_after(phase_after), .period_after(period_after), .x_after(x_after),
    .y_after(y_after), .inside(), .holds(holds));
`ifdef OPCODE
  always @(*) assume(word[15:13] == `OPCODE);
`endif
`ifdef ALU_DEST
  always @(*) assume(word[7:6] == `ALU_DEST);
`endif
`ifdef ALU_OP
  always @(*) assume(word[5:4] == `ALU_OP);
`endif
`ifdef WAIT_SOURCE
  always @(*) assume(word[6:5] == `WAIT_SOURCE);
`endif
`ifdef SIDE_SET
  always @(*) assume(side_set_count == `SIDE_SET);
`endif
  always @(*) assert(holds);
endmodule
`endif
