// The kernel's check of one step, as test_kernel.ml's SAT proof states it: for any rows,
// word and state, an accepted row holding the core maps it into the row it goes to, for
// any next state kernel_step allows. The offsets are free under axioms that hold of the
// true phase - slope * x modulo 2^24, each guarded by the x it needs. row_step.sby proves
// it for every input; phase_step.sv's AFFINE table assumes it.

// no pair: the kernel spaces edges only for tables of intervals
`define UNPAIRED \
    .spacing$valid(1'b0), .spacing$value$a(5'd0), .spacing$value$b(5'd0), \
    .spacing$value$dirs(1'b0), .spacing$value$side_set_base(5'd0), \
    .spacing$value$side_set_pindirs(1'b0), .spacing$value$set_base(5'd0), \
    .spacing$value$set_count(3'd0), .spacing$value$out_base(5'd0), \
    .spacing$value$out_count(5'd0), .spacing$value$hold_a_0(16'd0), \
    .spacing$value$hold_a_1(16'd0), .spacing$value$hold_a_2(16'd0), \
    .spacing$value$hold_a_3(16'd0), .spacing$value$apart_a_0(16'd0), \
    .spacing$value$apart_a_1(16'd0), .spacing$value$apart_a_2(16'd0), \
    .spacing$value$apart_a_3(16'd0), .spacing$value$hold_b_0(16'd0), \
    .spacing$value$hold_b_1(16'd0), .spacing$value$hold_b_2(16'd0), \
    .spacing$value$hold_b_3(16'd0), .spacing$value$apart_b_0(16'd0), \
    .spacing$value$apart_b_1(16'd0), .spacing$value$apart_b_2(16'd0), \
    .spacing$value$apart_b_3(16'd0), .a$since(16'd0), .a$level(1'b0), .a$fresh(1'b0), \
    .b$since(16'd0), .b$level(1'b0), .b$fresh(1'b0)

module row_step (
  input [1:0] side_set_count,
  input fraction, loads_period,
  input [15:0] loaded_period,
  input [4:0] capture_pin,
  input capture_rising, single_edge,
  input [15:0] word,
  input [265:0] row, next, target,
  // the core at this entry, and at the next as far as kernel_step fixes it
  input [23:0] phase, offset, arm,
  input [15:0] period, x, y,
  input arm_known, captured, awaiting,
  input [23:0] phase_after, next_offset, target_offset,
  input [15:0] period_after, x_after, y_after,
  output axioms, holds
);
  wire [23:0] next_phase, next_arm;
  wire [15:0] next_period, next_x, next_y;
  wire bounded, may_carry, period_known, x_known, y_known, taken, taken_known;
  wire next_arm_known, next_captured, next_awaiting, capture_bounded, halts;
  kernel_step step (
    .side_set_count(side_set_count), .fraction(fraction), `UNPAIRED, .data_a(1'b0),
    .data_b(1'b0),
    .loaded$valid(loads_period), .loaded$value(loaded_period), .word(word),
    .capture$pin(capture_pin), .capture$rising(capture_rising),
    .capture$single_edge(single_edge), .arm(arm), .arm_known(arm_known),
    .captured(captured), .awaiting(awaiting), .next_awaiting(next_awaiting),
    .next_arm(next_arm), .next_arm_known(next_arm_known),
    .next_captured(next_captured), .capture_bounded(capture_bounded),
    .phase(phase), .period(period), .x(x), .y(y), .next_phase(next_phase),
    .bounded(bounded), .may_carry(may_carry), .next_period(next_period),
    .period_known(period_known), .next_x(next_x), .x_known(x_known), .next_y(next_y),
    .y_known(y_known), .taken(taken), .taken_known(taken_known), .halts(halts));

`ifdef NO_OFFSET_CHECK
  // accepts reads the rows it steps to with the full offset, so it checks no offset
  function [265:0] checked(input [265:0] r);
    checked = {r[265:194], 48'h8000007fffff, r[145:0]};
  endfunction
`else
  function [265:0] checked(input [265:0] r);
    checked = r;
  endfunction
`endif
  wire accepts, within, into_next, into_target;
  kernel_accepts check (
    .side_set_count(side_set_count), .fraction(fraction),
    .loaded$valid(loads_period), .loaded$value(loaded_period),
    .capture$pin(capture_pin), .capture$rising(capture_rising),
    .capture$single_edge(single_edge), .wrap_top(9'd0), .wrap_bottom(9'd0), `UNPAIRED,
    .pc(9'd0), .word(word), .row({row, 174'd0}), .next({checked(next), 174'd0}),
    .target({checked(target), 174'd0}),
    .phase(phase), .offset(offset), .period(period), .x(x), .y(y), .arm(arm),
    .arm_known(arm_known), .captured(captured), .awaiting(awaiting),
    .next_pc(), .target_pc(), .accepts(accepts), .within(within), .starts_open());
  // the core after the step inside each successor, the kernel's own within
  kernel_accepts at_next (
    .side_set_count(side_set_count), .fraction(fraction),
    .loaded$valid(loads_period), .loaded$value(loaded_period),
    .capture$pin(capture_pin), .capture$rising(capture_rising),
    .capture$single_edge(single_edge), .wrap_top(9'd0), .wrap_bottom(9'd0), `UNPAIRED,
    .pc(9'd0), .word(word), .row({next, 174'd0}), .next({next, 174'd0}),
    .target({next, 174'd0}),
    .phase(phase_after), .offset(next_offset), .period(period_after), .x(x_after),
    .y(y_after), .arm(next_arm), .arm_known(next_arm_known), .captured(next_captured),
    .awaiting(next_awaiting), .next_pc(), .target_pc(), .accepts(), .within(into_next),
    .starts_open());
  kernel_accepts at_target (
    .side_set_count(side_set_count), .fraction(fraction),
    .loaded$valid(loads_period), .loaded$value(loaded_period),
    .capture$pin(capture_pin), .capture$rising(capture_rising),
    .capture$single_edge(single_edge), .wrap_top(9'd0), .wrap_bottom(9'd0), `UNPAIRED,
    .pc(9'd0), .word(word), .row({target, 174'd0}), .next({target, 174'd0}),
    .target({target, 174'd0}),
    .phase(phase_after), .offset(target_offset), .period(period_after), .x(x_after),
    .y(y_after), .arm(next_arm), .arm_known(next_arm_known), .captured(next_captured),
    .awaiting(next_awaiting), .next_pc(), .target_pc(), .accepts(), .within(into_target),
    .starts_open());

  wire [2:0] opcode = word[15:13];
  wire is_jmp = opcode == 0;
  wire deadline = opcode == 1 && word[6:5] == 2;
  wire set_x = opcode == 5 && word[7:5] == 1;
  wire x_dec = is_jmp && word[12:9] == 1;
  wire [4:0] set_value = word[4:0];
  wire [4:0] ds = word[12:8];
  wire [4:0] delay = side_set_count == 0 ? ds : side_set_count == 1 ? ds[3:0] : ds[2:0];
  wire [23:0] cycles = delay + 24'd1;

  // the next state is one kernel_step allows; after [mov t, capture] the phase is only a
  // range, from a cycle past the instruction up to the step
  wire lands =
    (!bounded || phase_after == next_phase
      || may_carry && phase_after == next_phase - 24'd1)
    && (!capture_bounded || cycles + 24'd1 <= phase_after && phase_after <= next_phase)
    && (!period_known || period_after == next_period)
`ifdef X_UNFOLLOWED
    // x after the step anything
    && (!y_known || y_after == next_y);
`else
    && (!x_known || x_after == next_x) && (!y_known || y_after == next_y);
`endif

  // After [set x, v] the offset is the phase less the slope times v; with the slope the
  // same, it moves as the phase does where x stays, and a slope further where x is one
  // less. The product is the kernel's, so the two are one multiplier.
  wire [23:0] slope = row[217:194];
  wire [23:0] moved = offset + (phase_after - phase);
  wire steady = bounded && !deadline;
  function axioms_of(input [23:0] s, input [23:0] s_offset);
    reg signed [29:0] product;
    begin
      product = $signed(s) * $signed({1'b0, set_value});
      axioms_of =
        (!(set_x && x_after == {11'd0, set_value})
          || s_offset == phase_after - product[23:0])
        && (!(steady && x_known && x_after == x && s == slope) || s_offset == moved)
        && (!(x_dec && x != 0 && x_after == x - 16'd1 && s == slope)
          || s_offset == moved + slope);
    end
  endfunction
  assign axioms =
    axioms_of(next[217:194], next_offset) && axioms_of(target[217:194], target_offset);

  wire hypothesis = within && (!x_dec || x != 0 || offset == phase) && side_set_count <= 2
    && !halts && lands;
  wire arrives = !is_jmp ? into_next
    : taken_known ? (taken ? into_target : into_next)
    : into_target && into_next;
`ifdef NO_AXIOMS
  assign holds = !(hypothesis && accepts) || arrives;
`else
  assign holds = !(hypothesis && axioms && accepts) || arrives;
`endif
endmodule

`ifdef ROW_STEP
// the lemma for every input, one opcode at a time, and the ALU's one destination at a time;
// row_step.sby's tasks between them take every word
module row_step_proof;
  (* anyconst *) wire [1:0] side_set_count;
  (* anyconst *) wire fraction, loads_period, capture_rising, single_edge;
  (* anyconst *) wire [15:0] loaded_period, word;
  (* anyconst *) wire [4:0] capture_pin;
  (* anyconst *) wire [265:0] row, next, target;
  (* anyconst *) wire [23:0] phase, offset, arm, phase_after, next_offset, target_offset;
  (* anyconst *) wire [15:0] period, x, y, period_after, x_after, y_after;
  (* anyconst *) wire arm_known, captured, awaiting;
  wire axioms, holds;
  row_step lemma (
    .side_set_count(side_set_count), .fraction(fraction), .loads_period(loads_period),
    .loaded_period(loaded_period), .capture_pin(capture_pin),
    .capture_rising(capture_rising), .single_edge(single_edge), .word(word), .row(row),
    .next(next), .target(target), .phase(phase), .offset(offset), .arm(arm),
    .period(period), .x(x), .y(y), .arm_known(arm_known), .captured(captured),
    .awaiting(awaiting), .phase_after(phase_after), .next_offset(next_offset),
    .target_offset(target_offset), .period_after(period_after), .x_after(x_after),
    .y_after(y_after), .axioms(axioms), .holds(holds));
`ifdef OPCODE
  always @(*) assume(word[15:13] == `OPCODE);
`endif
`ifdef ALU_DEST
  always @(*) assume(word[7:6] == `ALU_DEST);
`endif
  always @(*) assert(holds);
endmodule
`endif
