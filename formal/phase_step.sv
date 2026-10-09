// Step lemma for the universal certificate. For any program, from one instruction's entry
// to the next, the core does what the kernel's step says: the phase [now - t], p, x, y, the
// pc and, with Manchester off and edge_step.sv's lemma assumed, a watched pair's edges. A
// deadline wait entered at phase <= 0 does not fault. Equalities are mod 2^T, T the
// timer's width: 24, or 7 in the narrow tasks, which reach the wrap in a bounded run. The
// engine is the chip's with every input free, so this holds for each engine of several;
// CHIP runs it on one inside the two-engine chip instead. Program memories are the flop
// stand-in for the SRAM macro.

`ifndef TIMER_BITS
`define TIMER_BITS 24
`endif

// the pair is followed by the step lemma and the spacing proof, not the one-run theorem
`ifndef TABLE
`define EDGES
`elsif SPACING
`define EDGES
`endif

module phase_step (input clk);
  localparam T = `TIMER_BITS;
  // a count of cycles past the timer's range, where it stops
  localparam [T:0] SATURATED = 1 << T;
  (* anyconst *) wire [1:0] side_set_count;
  (* anyconst *) wire [4:0] side_set_base, in_base, in_count, out_base, out_count, set_base;
  (* anyconst *) wire [2:0] set_count;
  (* anyconst *) wire [4:0] jmp_pin, capture_pin, push_threshold, pull_threshold;
  (* anyconst *) wire side_set_pindirs, capture_rising, in_shift_right, out_shift_right, autopush, autopull;
  (* anyconst *) wire [4:0] crc_width, stuff_threshold;
  (* anyconst *) wire [15:0] crc_poly, crc_init;
  (* anyconst *) wire crc_reflect, stuff_level;
  (* anyconst *) wire [8:0] wrap_bottom, wrap_top;
  (* anyconst *) wire [15:0] period_fraction;
  (* anyconst *) wire autopull_data, manchester;
  // the assumption the kernel may take: a run-time write to p carries loaded_period as it
  // stood at the entry of the instruction that writes it, free at each entry
  (* anyconst *) wire loads_period;
  (* anyseq *) wire [15:0] loaded_period;
  // and that the capture pin makes one edge from capture_arm to the wait for it
  (* anyconst *) wire single_edge;
  // a pair of pins whose edges the kernel spaces, each its pindirs bit if pair_dirs, and
  // the least cycles, four entries each, indexed by the two bits before an edge
  (* anyconst *) wire [4:0] pin_a, pin_b;
  (* anyconst *) wire pair_dirs, spaced;
  (* anyconst *) wire [63:0] hold_a, apart_a, hold_b, apart_b;
  // the data memory is shared between engines, so its word is free in every cycle
  (* anyseq *) wire [15:0] data_word;
  (* anyseq *) wire stop, flush;
  (* anyseq *) wire start, program_write_valid, tx_valid, rx_pop, clear_irq;
  (* anyseq *) wire [8:0] program_write_addr;
  (* anyseq *) wire [15:0] program_write_data, tx_value;
  (* anyseq *) wire [27:0] inputs;
`ifdef CHIP
  // the other engine's host, its config too, both hosts' data writes and the pads
  (* anyseq *) wire [1:0] o_side_set_count;
  (* anyseq *) wire [4:0] o_side_set_base, o_in_base, o_in_count, o_out_base, o_out_count;
  (* anyseq *) wire [4:0] o_set_base, o_jmp_pin, o_capture_pin, o_push_threshold;
  (* anyseq *) wire [4:0] o_pull_threshold, o_crc_width, o_stuff_threshold;
  (* anyseq *) wire [2:0] o_set_count;
  (* anyseq *) wire o_side_set_pindirs, o_capture_rising, o_in_shift_right, o_out_shift_right;
  (* anyseq *) wire o_autopush, o_autopull, o_crc_reflect, o_stuff_level, o_autopull_data;
  (* anyseq *) wire o_manchester;
  (* anyseq *) wire [15:0] o_crc_poly, o_crc_init, o_period_fraction;
  (* anyseq *) wire [8:0] o_wrap_bottom, o_wrap_top;
  (* anyseq *) wire o_stop, o_flush, o_start, o_program_write_valid, o_tx_valid, o_rx_pop;
  (* anyseq *) wire o_clear_irq;
  (* anyseq *) wire [8:0] o_program_write_addr;
  (* anyseq *) wire [15:0] o_program_write_data, o_tx_value;
  (* anyseq *) wire data_write_valid, o_data_write_valid;
  (* anyseq *) wire [8:0] data_write_addr, o_data_write_addr;
  (* anyseq *) wire [15:0] data_write_data, o_data_write_data;
  (* anyseq *) wire [19:0] pads;
`endif

  reg clear = 1;
  always @(posedge clk) clear <= 0;

  wire [27:0] pin_out, pin_dir;
  wire [8:0] pc;
  wire [15:0] x, y, p, osr, isr, rx_head, instruction, crc;
  wire [T-1:0] t, now, capture;
  wire [4:0] osr_count, isr_count, stall, stuff_run;
  wire halted, irq, underflow, overflow, missed_deadline, decode, capture_armed;
  wire [3:0] tx_level, rx_level;
  wire decode_ok;
  wire [7:0] opcode_onehot;
  wire [27:0] wait_select;
  wire [27:0] wait_pin = 28'd1 << instruction[4:0];
  wire jmp_go, advance;
  wire [27:0] sample;
  wire captured_now;
  wire [15:0] out_value, mov_value;

`ifdef CHIP
  // the pads, the other engine's drive and faults, and this core's start and stop, which
  // are its host's through the chip's fault gate
  wire [19:0] chip_out, chip_dir;
  wire [27:0] o_pin_out, o_pin_dir;
  wire o_underflow, o_overflow, o_missed_deadline, o_decode, faulted, o_faulted;
  wire flip_pending, flip_bit, core_start, core_stop;
  // engine n's host fields on the wires named w and the field
`define HOST(n, w) \
    .hosts$config$side_set_count_``n(w``side_set_count), \
    .hosts$config$side_set_base_``n(w``side_set_base), \
    .hosts$config$side_set_pindirs_``n(w``side_set_pindirs), \
    .hosts$config$in_base_``n(w``in_base), .hosts$config$in_count_``n(w``in_count), \
    .hosts$config$out_base_``n(w``out_base), .hosts$config$out_count_``n(w``out_count), \
    .hosts$config$set_base_``n(w``set_base), .hosts$config$set_count_``n(w``set_count), \
    .hosts$config$jmp_pin_``n(w``jmp_pin), .hosts$config$capture_pin_``n(w``capture_pin), \
    .hosts$config$capture_rising_``n(w``capture_rising), \
    .hosts$config$in_shift_right_``n(w``in_shift_right), \
    .hosts$config$out_shift_right_``n(w``out_shift_right), \
    .hosts$config$autopush_``n(w``autopush), \
    .hosts$config$push_threshold_``n(w``push_threshold), \
    .hosts$config$autopull_``n(w``autopull), \
    .hosts$config$pull_threshold_``n(w``pull_threshold), \
    .hosts$config$crc_width_``n(w``crc_width), .hosts$config$crc_poly_``n(w``crc_poly), \
    .hosts$config$crc_init_``n(w``crc_init), .hosts$config$crc_reflect_``n(w``crc_reflect), \
    .hosts$config$stuff_threshold_``n(w``stuff_threshold), \
    .hosts$config$stuff_level_``n(w``stuff_level), \
    .hosts$config$wrap_bottom_``n(w``wrap_bottom), .hosts$config$wrap_top_``n(w``wrap_top), \
    .hosts$config$period_fraction_``n(w``period_fraction), \
    .hosts$config$autopull_data_``n(w``autopull_data), \
    .hosts$config$manchester_``n(w``manchester), \
    .hosts$start_``n(w``start), .hosts$program_write$valid_``n(w``program_write_valid), \
    .hosts$program_write$addr_``n(w``program_write_addr), \
    .hosts$program_write$data_``n(w``program_write_data), \
    .hosts$data_write$valid_``n(w``data_write_valid), \
    .hosts$data_write$addr_``n(w``data_write_addr), \
    .hosts$data_write$data_``n(w``data_write_data), \
    .hosts$tx$valid_``n(w``tx_valid), .hosts$tx$value_``n(w``tx_value), \
    .hosts$rx_pop_``n(w``rx_pop), .hosts$clear_irq_``n(w``clear_irq), \
    .hosts$stop_``n(w``stop), .hosts$flush_``n(w``flush)
  // its pins, its faults and the flop holding any of them
`define DRIVE(n, w) \
    .engines$pin_out_``n(w``pin_out), .engines$pin_dir_``n(w``pin_dir), \
    .engines$fault$underflow_``n(w``underflow), .engines$fault$overflow_``n(w``overflow), \
    .engines$fault$missed_deadline_``n(w``missed_deadline), \
    .engines$fault$decode_``n(w``decode), .engines$faulted_``n(w``faulted)
  // and the rest of this engine, with the wires inside its core that the .sby brings out
`define CORE(n) \
    `DRIVE(n, ), .engines$pc_``n(pc), .engines$x_``n(x), .engines$y_``n(y), \
    .engines$p_``n(p), .engines$t_``n(t), .engines$osr_``n(osr), \
    .engines$osr_count_``n(osr_count), .engines$isr_``n(isr), \
    .engines$isr_count_``n(isr_count), .engines$now_``n(now), .engines$stall_``n(stall), \
    .engines$halted_``n(halted), .engines$irq_``n(irq), .engines$capture_``n(capture), \
    .engines$capture_armed_``n(capture_armed), .engines$tx_level_``n(tx_level), \
    .engines$rx_level_``n(rx_level), .engines$rx_head_``n(rx_head), \
    .engines$instruction_``n(instruction), .engines$crc_``n(crc), \
    .engines$stuff_run_``n(stuff_run), .engines$decode_ok_``n(decode_ok), \
    .engines$opcode_onehot_``n(opcode_onehot), .engines$wait_select_``n(wait_select), \
    .engines$flip_pending_``n(flip_pending), .engines$flip_bit_``n(flip_bit), \
    .eng_jmp_go_``n(jmp_go), .eng_advance_``n(advance), .eng_sample_``n(sample), \
    .eng_captured_``n(captured_now), .eng_start_``n(core_start), .eng_stop_``n(core_stop)
`ifdef ENGINE_1
  engines_top dut (
    .clock(clk), .clear(clear), .pads(pads), .pin_out(chip_out), .pin_dir(chip_dir),
    `HOST(1, ), `CORE(1), `HOST(0, o_), `DRIVE(0, o_));
`else
  engines_top dut (
    .clock(clk), .clear(clear), .pads(pads), .pin_out(chip_out), .pin_dir(chip_dir),
    `HOST(0, ), `CORE(0), `HOST(1, o_), `DRIVE(1, o_));
`endif
`else
  wire core_start = start, core_stop = stop;
  engine dut (
    .clock(clk), .clear(clear),
    .config$side_set_count(side_set_count), .config$side_set_base(side_set_base),
    .config$side_set_pindirs(side_set_pindirs), .config$in_base(in_base),
    .config$in_count(in_count), .config$out_base(out_base), .config$out_count(out_count),
    .config$set_base(set_base), .config$set_count(set_count), .config$jmp_pin(jmp_pin), .config$capture_pin(capture_pin),
    .config$capture_rising(capture_rising), .config$in_shift_right(in_shift_right),
    .config$out_shift_right(out_shift_right), .config$autopush(autopush),
    .config$push_threshold(push_threshold), .config$autopull(autopull),
    .config$pull_threshold(pull_threshold),
    .config$crc_width(crc_width), .config$crc_poly(crc_poly), .config$crc_init(crc_init),
    .config$crc_reflect(crc_reflect), .config$stuff_threshold(stuff_threshold),
    .config$stuff_level(stuff_level),
    .config$wrap_bottom(wrap_bottom), .config$wrap_top(wrap_top),
    .config$period_fraction(period_fraction),
    .config$autopull_data(autopull_data), .config$manchester(manchester),
    .stop(stop), .flush(flush),
    .start(start), .program_write$valid(program_write_valid),
    .program_write$addr(program_write_addr), .program_write$data(program_write_data),
    .data_word(data_word),
    .tx$valid(tx_valid), .tx$value(tx_value), .rx_pop(rx_pop), .clear_irq(clear_irq),
    .inputs(inputs),
    .pin_out(pin_out), .pin_dir(pin_dir), .pc(pc), .x(x), .y(y), .p(p), .t(t), .osr(osr),
    .osr_count(osr_count), .isr(isr), .isr_count(isr_count), .now(now), .stall(stall),
    .halted(halted), .irq(irq), .fault$underflow(underflow), .fault$overflow(overflow),
    .fault$missed_deadline(missed_deadline), .fault$decode(decode), .capture(capture),
    .capture_armed(capture_armed), .tx_level(tx_level), .rx_level(rx_level),
    .rx_head(rx_head), .instruction(instruction), .crc(crc), .stuff_run(stuff_run),
    .decode_ok(decode_ok), .opcode_onehot(opcode_onehot), .wait_select(wait_select),
    .eng_jmp_go(jmp_go), .eng_advance(advance), .eng_sample(sample),
    .eng_captured(captured_now), .eng_out_value(out_value), .eng_mov_value(mov_value));
`endif
  // an instruction completes when a jump issues, or anything else issues and goes on
  wire completes = jmp_go || advance;

  always @(*) begin
    assume(side_set_count <= 2);
    assume(!start || halted);
    assume(!program_write_valid || halted);
  end
`ifdef ONE_RUN
  // one of the runs above, so a failure in it is the lemma's: jmp 0 written at 0, then one
  // start and no stop; the wrap's tooth takes it to reach the timer's top in few choices
  reg [1:0] setup = 0;
  always @(posedge clk) if (setup != 3) setup <= setup + 2'd1;
  always @(*) begin
    assume(!stop && !flush && start == (setup == 2));
    assume(program_write_valid == (setup == 1));
    if (setup == 1) assume(program_write_addr == 0 && program_write_data == 0);
  end
`endif

  wire [2:0] opcode = instruction[15:13];
  wire [4:0] ds = instruction[12:8];
  function [4:0] delay_of(input [4:0] d);
    delay_of = side_set_count == 0 ? d : side_set_count == 1 ? d[3:0] : d[2:0];
  endfunction
  wire [4:0] delay = delay_of(ds);
  always @(posedge clk)
    if (!clear) begin
      assert(opcode_onehot == 8'b1 << opcode);
      // the core's registered decode flag agrees with the kernel's decoder
      assert(decode_ok == !(halts && !(opcode == 7 && instruction[7:0] == 8'd1)));
      assert(wait_select == wait_pin);
    end

  // an entry is the first issue after a start or after a completion
  reg started = 0;
  always @(posedge clk) started <= core_start;
  wire issue = !clear && !halted && stall == 0 && !started;
  reg fresh = 0;
  always @(posedge clk)
    if (clear || core_start || completes) fresh <= 1;
    else if (issue) fresh <= 0;
  wire entry = issue && fresh;
  wire signed [T-1:0] phase = now - t;

  // the analyser's instruction classes
  function is_deadline_wait(input [15:0] w);
    is_deadline_wait = w[15:13] == 1 && w[6:5] == 2;
  endfunction
  function [8:0] following_of(input [8:0] a);
    following_of = a == wrap_top ? wrap_bottom : a + 9'd1;
  endfunction
  function [T-1:0] step_of(input [15:0] w);
    step_of = w[15:13] == 0 ? 2'd2 : delay_of(w[12:8]) + 1'd1;
  endfunction

  wire is_jmp = opcode == 0;
  wire deadline_wait = is_deadline_wait(instruction);
  wire [2:0] operand = instruction[2:0];
  wire [T-1:0] step = step_of(instruction);


  // what t holds after the instruction; a wait moves it at the release
  wire [7:0] body = instruction[7:0];
  wire [T-1:0] t_after =
      opcode == 4 && body == 8'b11100110 ? now
    : opcode == 4 && body == 8'b11100111 ? capture
    : opcode == 6 && body[7:3] == 5'b11000 ? t + operand
    : opcode == 6 && body == 8'b11001010 ? t + p
    : opcode == 6 && body == 8'b11001000 ? t + x
    : opcode == 6 && body == 8'b11001001 ? t + y
    : opcode == 6 && body[7:3] == 5'b11010 ? t - operand
    : deadline_wait && body[7] ? t + p
    : t;

  // The kernel's ghost count of cycles since capture_arm, as it stands at an entry.
  wire [T-1:0] next_arm;
  wire arm_known_next, captured_next, capture_bounded;
`ifdef ARM_ONE_SHORT
  // the step counting the arm's own cycles one short
  wire [T-1:0] g = pending ? next_arm - e_arms : {T{1'b0}};
`else
  wire [T-1:0] g = pending ? next_arm : {T{1'b0}};
`endif
  wire g_known = pending && arm_known_next;
  wire g_captured = pending && captured_next;
  wire awaiting_next;
  wire g_awaiting = pending && awaiting_next;
  reg [T-1:0] e_g, e_release;
  reg [T:0] e_capture_age;
  // cycles since the entry, saturating past the timer's range and past a pin's 16-bit
  // count; and saturating at the timer's range
  localparam W = T > 17 ? T : 17;
  reg [W:0] elapsed_wide = 1 << W;
  always @(posedge clk)
    if (entry) elapsed_wide <= 1;
    else if (!elapsed_wide[W]) elapsed_wide <= elapsed_wide + 1;
  wire [T:0] elapsed = elapsed_wide >= SATURATED ? SATURATED : elapsed_wide[T:0];
  reg e_g_known, e_g_captured, e_g_awaiting;

  // The kernel's ghost of the pair at an entry: each pin's cycles since its last edge in
  // this run, all ones before the first; its bit, the pin's at the run's first entry; and
  // whether the run has yet to write it.
  wire [27:0] watched = pair_dirs ? pin_dir : pin_out;
  wire bit_a = watched[pin_a], bit_b = watched[pin_b];
  wire [15:0] next_since_a, next_since_b;
  wire next_level_a, next_level_b, next_fresh_a, next_fresh_b, wide_a, wide_b;
  wire [15:0] since_a = pending ? next_since_a : 16'hffff;
  wire [15:0] since_b = pending ? next_since_b : 16'hffff;
  wire level_a = pending ? next_level_a : bit_a, level_b = pending ? next_level_b : bit_b;
  wire fresh_a = !pending || next_fresh_a, fresh_b = !pending || next_fresh_b;
  reg [15:0] e_since_a, e_since_b;
  reg e_level_a, e_level_b, e_fresh_a, e_fresh_b, e_data_a, e_data_b;

  // Record of the last entry. Before completion the core holds the same word, pc and t;
  // after, [now + stall] is the next entry's cycle and t what the instruction left.
  reg pending = 0;
  reg done = 0;
  reg [15:0] e_word, e_p, e_x, e_y, e_loaded;
  reg [8:0] e_pc;
  reg [T-1:0] e_t, e_now, e_phase, e_next_now, e_t_after;
  wire [T-1:0] e_step = step_of(e_word);
  reg e_safe;
  wire e_is_jmp = e_word[15:13] == 0;
  wire e_deadline_wait = is_deadline_wait(e_word);
  wire [8:0] e_following = following_of(e_pc);
  wire e_in_time = e_phase[T-1] || e_phase == 0;
  // an entry is recorded even as a stop clears the record, for the pair's claim
  always @(posedge clk) begin
    if (entry) begin
      e_word <= instruction;
      e_p <= p;
      e_loaded <= loaded_period;
      e_x <= x;
      e_y <= y;
      e_pc <= pc;
      e_t <= t;
      e_now <= now;
      e_phase <= phase;
      e_next_now <= now + step;
      e_t_after <= t_after;
      e_g <= g;
      e_g_known <= g_known;
      e_g_captured <= g_captured;
      e_g_awaiting <= g_awaiting;
`ifdef EDGES
      e_since_a <= since_a;
      e_since_b <= since_b;
      e_level_a <= level_a;
      e_level_b <= level_b;
      e_fresh_a <= fresh_a;
      e_fresh_b <= fresh_b;
      e_data_a <= w_data_value[pin_a];
      e_data_b <= w_data_value[pin_b];
      e_quiet_a <= quiet_a_now;
      e_quiet_b <= quiet_b_now;
      e_moved_a <= moved_a || counts_a;
      e_moved_b <= moved_b || counts_b;
`endif
      e_release <= now;
      e_capture_age <= capture_age;
`ifdef ONE_LATE_CYCLE_IS_SAFE
      e_safe <= !missed_deadline && (!deadline_wait || phase[T-1] || phase <= 1);
`else
      e_safe <= !missed_deadline && (!deadline_wait || phase[T-1] || phase == 0);
`endif
    end
    if (clear || core_start || core_stop) pending <= 0;
    else if (entry) begin
      pending <= decode_ok && !halts;
      done <= completes;
    end
    else if (pending && !done && completes) begin
      done <= 1;
      e_release <= now;
      e_next_now <= now + step;
      e_t_after <= t_after;
    end
  end

`ifdef LATER_EDGE_CAPTURED
  // every wait for the edge counts as the one that captures it, not only the first since
  // the arm, so a later edge stands for the one the register took
  wire e_awaiting = e_g_awaiting || single_edge && e_capturing;
`else
  wire e_awaiting = e_g_awaiting;
`endif

  // the kernel's step, the definition the checker uses
  wire [T-1:0] next_phase;
  wire [15:0] next_period, next_x, next_y;
  wire e_halts;
  wire x_known, y_known, taken, taken_known;
  wire bounded, carries, period_known;
`define PAIR(valid) \
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
  kernel_step e_step_of (
    .side_set_count(side_set_count), .fraction(period_fraction != 0),
`ifdef EDGES
    `PAIR(spaced), .a$since(e_since_a), .a$level(e_level_a), .a$fresh(e_fresh_a),
    .b$since(e_since_b), .b$level(e_level_b), .b$fresh(e_fresh_b), .data_a(e_data_a),
    .data_b(e_data_b),
`else
    `PAIR(1'b0), .a$since(16'd0), .a$level(1'b0), .a$fresh(1'b0), .b$since(16'd0),
    .b$level(1'b0), .b$fresh(1'b0), .data_a(1'b0), .data_b(1'b0),
`endif
    .next_a$since(next_since_a), .next_a$level(next_level_a),
    .next_a$fresh(next_fresh_a), .next_b$since(next_since_b),
    .next_b$level(next_level_b), .next_b$fresh(next_fresh_b), .wide_a(wide_a),
    .wide_b(wide_b),
    .loaded$valid(loads_period), .loaded$value(e_loaded), .word(e_word),
    .capture$pin(capture_pin), .capture$rising(capture_rising),
    .capture$single_edge(single_edge), .arm(e_g), .arm_known(e_g_known),
    .captured(e_g_captured), .awaiting(e_awaiting), .next_awaiting(awaiting_next),
    .next_arm(next_arm), .next_arm_known(arm_known_next),
    .next_captured(captured_next), .capture_bounded(capture_bounded),
    .phase(e_phase), .period(e_p), .x(e_x), .y(e_y), .next_phase(next_phase),
    .bounded(bounded), .may_carry(carries), .next_period(next_period),
    .period_known(period_known), .next_x(next_x), .x_known(x_known), .next_y(next_y),
    .y_known(y_known), .taken(taken), .taken_known(taken_known), .halts(e_halts));
  // whether the word at an entry has a next one
  wire halts, keeps_period;
  kernel_step halts_of (
    .side_set_count(side_set_count), .fraction(1'b0), `PAIR(1'b0),
    .a$since(16'd0), .a$level(1'b0), .a$fresh(1'b0), .b$since(16'd0), .b$level(1'b0),
    .b$fresh(1'b0), .data_a(1'b0), .data_b(1'b0), .next_a$since(), .next_a$level(),
    .next_a$fresh(), .next_b$since(), .next_b$level(), .next_b$fresh(), .wide_a(),
    .wide_b(), .loaded$valid(1'b0),
    .loaded$value(16'd0), .capture$pin(5'd0), .capture$rising(1'b0),
    .capture$single_edge(1'b0), .arm({T{1'b0}}), .arm_known(1'b0), .captured(1'b0),
    .awaiting(1'b0), .next_awaiting(),
    .next_arm(), .next_arm_known(), .next_captured(), .capture_bounded(),
    .word(instruction), .phase({T{1'b0}}), .period(16'd0), .x(16'd0),
    .y(16'd0), .next_phase(), .bounded(), .may_carry(), .next_period(),
    .period_known(keeps_period), .next_x(), .x_known(), .next_y(), .y_known(), .taken(),
    .taken_known(), .halts(halts));

  reg wrote_p = 0;
  always @(posedge clk) wrote_p <= !clear && completes && !keeps_period;
  always @(*) if (loads_period && wrote_p) assume(p == e_loaded);
  // the last load, for a cover of two that differ in one run
  reg [15:0] last_load;
  reg loaded_before = 0;
  always @(posedge clk)
    if (loads_period && wrote_p) begin
      last_load <= p;
      loaded_before <= 1;
    end

  // each teeth task gets one part of the step wrong
  wire [T-1:0] e_expected =
`ifdef JUMP_IN_ONE
    e_is_jmp ? next_phase - 1'd1 :
`endif
`ifdef LATE_WAIT_WAITS
    e_deadline_wait && !e_in_time ? next_phase - e_phase :
`endif
    next_phase;
`ifdef NO_CARRY
  wire e_may_carry = 0;
`else
  wire e_may_carry = carries;
`endif
  wire e_unbounded = !bounded;
  // the least phase after [mov t, capture]: an edge a cycle old and the instruction's cycles
`ifdef CAPTURE_A_CYCLE_OLDER
  wire [T-1:0] capture_lo = e_step + 2'd2;
`else
  wire [T-1:0] capture_lo = e_step + 1'd1;
`endif
  // and the most, the step's; the tooth takes a cycle off it
`ifdef CAPTURE_A_CYCLE_YOUNGER
  wire [T-1:0] capture_hi = next_phase - 1'd1;
`else
  wire [T-1:0] capture_hi = next_phase;
`endif
  wire t_ok = t == e_t_after || (e_may_carry && t == e_t_after + 1'd1);

  // The teeth that drop half the single-edge assumption keep only the claims at entries. The
  // invariants between entries are there for induction and lean on the assumption too, so
  // they would fail first whether or not the claims need it.
`ifdef SECOND_EDGE
`define ENTRIES_ONLY
`elsif LEVEL_AT_ARM
`define ENTRIES_ONLY
`endif

`ifndef ENTRIES_ONLY
  always @(posedge clk)
    if (!clear && pending && !entry) begin
      assert(!halted);
      assert(e_phase == e_now - e_t);
      if (!done) assert(p == e_p && x == e_x && y == e_y);
      else if (period_known) assert(p == next_period);
      if (e_safe) assert(!missed_deadline);
      if (!done) begin
        assert(!fresh && !e_is_jmp);
        assert(instruction == e_word && pc == e_pc && stall == 0 && t == e_t);
        if (e_deadline_wait && e_in_time && !completes) assert(phase[T-1]);
        assert(e_word[15:13] == 1 && decode_ok);
        if (e_deadline_wait) assert(e_in_time);
      end else begin
        assert(fresh && stall != 0);
        assert(now + stall == e_next_now);
        if (e_is_jmp && taken_known) assert(pc == (taken ? e_word[8:0] : e_following));
        else if (e_is_jmp) assert(pc == e_word[8:0] || pc == e_following);
        else assert(pc == e_following);
        if (x_known) assert(x == next_x);
        if (y_known) assert(y == next_y);
        if (!e_unbounded || capture_bounded) assert(t_ok);
        if (capture_bounded) assert(e_t_after == capture);
        if (!e_unbounded) assert(e_next_now - e_t_after == e_expected);
      end
    end
`endif

  // The single-edge assumption, on the level the core sees: the capture pin is at the other
  // level when capture_arm issues, and once at the captured level it stays there until a
  // wait for it releases. The teeth level_at_arm and second_edge drop one half each.
  wire arms = entry && opcode == 7 && instruction[7:0] == 8'd7;
  wire capturing = opcode == 1 && !instruction[6] && instruction[4:0] == capture_pin
    && instruction[4:0] < 28 && instruction[7] == capture_rising;
  // the core reads pin 27 for a capture pin past the pin space, as its mux does
  wire [4:0] seen_pin = capture_pin > 27 ? 5'd27 : capture_pin;
  wire level = sample[seen_pin] == capture_rising;
  reg holding = 0, seen = 0;
  reg [T-1:0] arm_now;
  // cycles since the arm, saturating, since a wait can outlast the timer's wrap
  reg [T:0] arm_age = SATURATED;
  wire young = !arm_age[T];
  // and since the core last captured, which the capture register holds
  reg [T:0] capture_age = SATURATED;
  wire capture_young = !capture_age[T];
  always @(posedge clk)
    if (clear || core_start || started) capture_age <= SATURATED;
    else if (captured_now) capture_age <= 1;
    else if (capture_young) capture_age <= capture_age + 1;
  always @(posedge clk)
    if (!clear && capture_young) assert(capture_age[T-1:0] == now - capture);
  wire capture_after_arm = capture_young ? !young || capture_age < arm_age : !young;
  always @(posedge clk)
    if (clear || core_start || started) arm_age <= SATURATED;
    else if (arms) arm_age <= 1;
    else if (young) arm_age <= arm_age + 1;
  always @(posedge clk) if (!clear && young) assert(arm_age[T-1:0] == now - arm_now);
  always @(posedge clk)
    if (clear || core_start) begin
      holding <= 0;
      seen <= 0;
    end else if (arms) begin
      holding <= 1;
      seen <= 0;
      arm_now <= now;
    end else if (completes && capturing && single_edge) holding <= 0;
    else if (holding && level) seen <= 1;
  always @(*)
    if (single_edge) begin
`ifndef LEVEL_AT_ARM
      if (arms) assume(!level);
`endif
`ifndef SECOND_EDGE
      if (holding && seen) assume(level);
`endif
    end

  // what the ghost count stands for: while awaiting the edge, the cycles since the arm;
  // once captured, a bound on the capture's age
  always @(posedge clk)
    if (!clear && entry) begin
      if (pending) assert(g_awaiting == holding);
      if (g_known) assert(!g[T-1]);
      if (g_known && g_awaiting) assert(young && arm_age[T-1:0] == g && g != 0);
      if (g_known && g_captured) begin
        assert(!g_awaiting && !capture_armed);
        assert(capture_young && capture_age >= 1 && capture_age < {1'b0, g});
      end
    end

  // the same between entries, for induction
  wire e_arms = e_word[15:13] == 7 && e_word[7:0] == 8'd7;
  wire e_capturing = e_word[15:13] == 1 && !e_word[6] && e_word[4:0] == capture_pin
    && e_word[4:0] < 28 && e_word[7] == capture_rising;
`ifndef ENTRIES_ONLY
  // while holding, the edge has either not come and the capture is armed, or come once
  always @(posedge clk)
    if (!clear && single_edge && holding)
      assert(seen ? !capture_armed && capture_after_arm : capture_armed);

  // running with no record is only the stretch from a start to its first entry
  always @(posedge clk) if (!clear && !halted && !pending) assert(!holding);
  always @(posedge clk)
    if (!clear && pending && !entry) begin
      assert(!e_halts);
      if (done) assert(e_next_now == e_release + e_step && stall < e_step);
      if (done && !elapsed[T])
        assert(elapsed[T-1:0] == e_release - e_now + e_step - stall);
      if (done && e_deadline_wait)
        assert(e_release - e_now == (e_in_time ? -e_phase : {T{1'b0}}) && !elapsed[T]);
      if (e_word[15:13] != 1) assert(done && e_release == e_now && elapsed <= e_step);
      if (!elapsed[T]) assert(elapsed[T-1:0] == now - e_now);
      if (e_deadline_wait && !done) assert(!elapsed[T] && elapsed[T-1:0] <= -e_phase);
      assert(holding == (e_arms || (e_g_awaiting && !(single_edge && e_capturing && done))));
      if (e_g_known) assert(!e_g[T-1]);
      if (e_arms) assert(arm_now == e_now && young && arm_age == elapsed);
      else if (e_g_known && e_g_awaiting) begin
        assert(e_now - arm_now == e_g && e_g != 0);
        if (!elapsed[T] && {1'b0, e_g} + elapsed < SATURATED)
          assert(young && arm_age == {1'b0, e_g} + elapsed);
      end
      if (e_g_known && e_g_captured && !e_arms) begin
        assert(!e_g_awaiting && !capture_armed);
        assert(!e_capture_age[T] && e_capture_age >= 1 && e_capture_age < {1'b0, e_g});
        if (!elapsed[T] && e_capture_age + elapsed < SATURATED)
          assert(capture_young && capture_age == e_capture_age + elapsed);
        if (e_word[15:13] != 1) assert(capture_young);
      end
      if (single_edge && e_g_known && e_g_awaiting && !e_arms)
        if (e_capturing && done)
          assert(!capture_armed && capture_young && e_release - capture < e_g);
        else if (e_capturing && !e_word[5]) assert(!seen);
    end

  // a deadline wait entered in time releases on its deadline
  always @(posedge clk)
    if (!clear && pending && !done && completes && e_deadline_wait && e_in_time)
      assert(now == e_t);
`endif

  // Pins.write's placing, as in edge_step.sv: the low bits of v from base up, wrapping at
  // 28, on the pins that take them: 5 and up drive, 12 to 19 turn around
  localparam [27:0] OUTPUTS = 28'hfffffe0;
  localparam [27:0] BIDIRS = 28'h00ff000;
  function [27:0] place(input [15:0] v, input [4:0] base);
    reg [55:0] twice;
    begin
      twice = {12'd0, v, 12'd0, v} << (base >= 28 ? base - 5'd28 : base);
      place = twice[55:28];
    end
  endfunction
  function [15:0] mask(input [4:0] n);
    mask = n >= 16 ? 16'hffff : (16'd1 << n) - 16'd1;
  endfunction

`ifdef EDGES
  // The spacing of the pair's edges, with Manchester off. Each pin's cycles since it last
  // moved, saturating, and whether it has made a counted edge in this run: one after the
  // run's first write of it.
  always @(*) assume(pin_a < 28 && pin_b < 28 && pin_a != pin_b);
  reg c3_last_clear = 1, c3_last_entry = 0, last_a = 0, last_b = 0;
  always @(posedge clk) begin
    c3_last_clear <= clear;
    c3_last_entry <= entry;
    last_a <= bit_a;
    last_b <= bit_b;
  end
  wire moves_a = !c3_last_clear && bit_a != last_a;
  wire moves_b = !c3_last_clear && bit_b != last_b;
  reg [16:0] quiet_a = 0, quiet_b = 0;
  wire [16:0] quiet_a_now = moves_a ? 17'd0 : quiet_a;
  wire [16:0] quiet_b_now = moves_b ? 17'd0 : quiet_b;
  // written: an entry of this run has written the pin; counted: its edge came after that
  reg wrote_a = 0, wrote_b = 0, l_wrote_a = 0, l_wrote_b = 0, moved_a = 0, moved_b = 0;
  wire counts_a = moves_a && l_wrote_a, counts_b = moves_b && l_wrote_b;
  always @(posedge clk) begin
    quiet_a <= quiet_a_now[16] ? quiet_a_now : quiet_a_now + 17'd1;
    quiet_b <= quiet_b_now[16] ? quiet_b_now : quiet_b_now + 17'd1;
    l_wrote_a <= wrote_a;
    l_wrote_b <= wrote_b;
    if (clear || core_start) begin
      wrote_a <= 0;
      wrote_b <= 0;
      moved_a <= 0;
      moved_b <= 0;
    end else begin
      if (entry && w_writes[pin_a]) wrote_a <= 1;
      if (entry && w_writes[pin_b]) wrote_b <= 1;
      if (counts_a) moved_a <= 1;
      if (counts_b) moved_b <= 1;
    end
  end

  // What an entry's word writes to the watched bits, as edge_step.sv's Pins.write, and the
  // edge lemma for them, assumed: proved there for any host, clear and program.
  wire [2:0] w_dest = instruction[7:5];
  wire w_runs = decode_ok && opcode != 0;
  wire [27:0] w_takes = pair_dirs ? BIDIRS : OUTPUTS;
  wire w_sides = w_runs && side_set_count != 0 && side_set_pindirs == pair_dirs;
  wire w_sets = w_runs && opcode == 5 && w_dest == (pair_dirs ? 3'd3 : 3'd0);
  wire w_outs = w_runs && opcode == 3 && w_dest == (pair_dirs ? 3'd4 : 3'd0);
  wire w_movs = w_runs && opcode == 4 && w_dest == (pair_dirs ? 3'd3 : 3'd0);
  wire [27:0] w_side = w_sides ? place(mask({3'd0, side_set_count}), side_set_base) & w_takes
    : 28'd0;
  wire [27:0] w_set = w_sets ? place(mask({2'd0, set_count}), set_base) & w_takes : 28'd0;
  wire [27:0] w_data = w_outs ? place(mask(instruction[4:0]), out_base) & w_takes
    : w_movs ? place(mask(out_count), out_base) & w_takes : 28'd0;
  wire [27:0] w_writes = w_side | w_set | w_data;
  wire [15:0] w_side_value =
    side_set_count == 1 ? {15'd0, instruction[12]} : {14'd0, instruction[12:11]};
  wire [27:0] w_data_value = w_outs ? place(out_value, out_base) : place(mov_value, out_base);
  wire [27:0] w_want = w_data & w_data_value
    | ~w_data & w_set & place({11'd0, instruction[4:0]}, set_base)
    | ~w_data & ~w_set & place(w_side_value, side_set_base);
  reg l_writes_a = 0, l_writes_b = 0, l_want_a = 0, l_want_b = 0;
  always @(posedge clk) begin
    l_writes_a <= entry && w_writes[pin_a];
    l_writes_b <= entry && w_writes[pin_b];
    l_want_a <= w_want[pin_a];
    l_want_b <= w_want[pin_b];
  end
  always @(*)
    if (!manchester && !clear && !c3_last_clear) begin
      assume(bit_a == (l_writes_a ? l_want_a : last_a));
      assume(bit_b == (l_writes_b ? l_want_b : last_b));
    end

  // the ghost at an entry: its bit is the pin's, and a pin with a counted edge in this run
  // has held its bit at least the ghost's cycles less one, as its next edge shows a cycle
  // after the entry
  always @(posedge clk)
    if (!clear && entry && pending && !manchester) begin
      assert(level_a == bit_a && level_b == bit_b);
      assert(fresh_a == !wrote_a && fresh_b == !wrote_b);
`ifdef EDGE_ONE_SHORT
      if (moved_a || counts_a) assert(quiet_a_now >= {1'b0, since_a});
`else
      if (moved_a || counts_a) assert(quiet_a_now + 17'd1 >= {1'b0, since_a});
`endif
      if (moved_b || counts_b) assert(quiet_b_now + 17'd1 >= {1'b0, since_b});
    end

  // A counted edge the cycle after an entry keeps the spacing, picked by the bits before
  // it: from the pin's last counted edge, and from the other's last edge, if counted, or
  // none where it moves too. The step's claim; the theorem in TABLE.
  function [15:0] pick(input [63:0] cycles, input [1:0] i);
    pick = cycles >> {i, 4'd0};
  endfunction
  wire [15:0] hold_a_now = pick(hold_a, {last_a, last_b});
  wire [15:0] apart_a_now = pick(apart_a, {last_a, last_b});
  wire [15:0] hold_b_now = pick(hold_b, {last_b, last_a});
  wire [15:0] apart_b_now = pick(apart_b, {last_b, last_a});
  wire spaced_a = !counts_a || (!moved_a || quiet_a >= {1'b0, hold_a_now})
    && (moves_b ? apart_a_now == 0 : !moved_b || quiet_b_now >= {1'b0, apart_a_now});
  wire spaced_b = !counts_b || (!moved_b || quiet_b >= {1'b0, hold_b_now})
    && (moves_a ? apart_b_now == 0 : !moved_a || quiet_a_now >= {1'b0, apart_b_now});
  reg c3_recorded = 0;
  always @(posedge clk) c3_recorded <= entry;
  always @(posedge clk)
    if (!clear && c3_recorded && spaced && !manchester) begin
      if (wide_a) assert(spaced_a);
      if (wide_b) assert(spaced_b);
    end

  // between entries, for induction
  reg [16:0] e_quiet_a, e_quiet_b;
  reg e_moved_a, e_moved_b, since_entry_a = 0, since_entry_b = 0;
  always @(posedge clk)
    if (entry) begin
      since_entry_a <= 0;
      since_entry_b <= 0;
    end else begin
      if (moves_a) since_entry_a <= 1;
      if (moves_b) since_entry_b <= 1;
    end
  function [16:0] quiet_after(input [16:0] quiet, input [W:0] cycles);
    quiet_after = cycles[W] || quiet + cycles >= 17'h10000 ? 17'h10000 : quiet + cycles;
  endfunction
  always @(posedge clk)
    if (!clear && pending && !entry && !manchester) begin
      if (moves_a || moves_b) assert(c3_last_entry && elapsed == 1);
      // the one edge since the entry, if any, left the entry's bit
      assert(bit_a == (since_entry_a || moves_a ? !e_level_a : e_level_a));
      assert(bit_b == (since_entry_b || moves_b ? !e_level_b : e_level_b));
      assert(level_a == bit_a && level_b == bit_b);
      assert(fresh_a == !wrote_a && fresh_b == !wrote_b);
      assert(moved_a == (e_moved_a || since_entry_a && !e_fresh_a));
      assert(moved_b == (e_moved_b || since_entry_b && !e_fresh_b));
      // the release came after the entry, and the step's cycles after the release
      if (done && !elapsed[T])
        assert(e_release - e_now <= elapsed[T-1:0] && elapsed[T-1:0] >= e_step - stall);
      if (e_moved_a) assert(e_quiet_a + 17'd1 >= {1'b0, e_since_a});
      if (e_moved_b) assert(e_quiet_b + 17'd1 >= {1'b0, e_since_b});
      if (!since_entry_a && !moves_a)
        assert(quiet_a_now == quiet_after(e_quiet_a, elapsed_wide));
      else assert(quiet_a_now == quiet_after(17'd0, elapsed_wide - 1'd1));
      if (!since_entry_b && !moves_b)
        assert(quiet_b_now == quiet_after(e_quiet_b, elapsed_wide));
      else assert(quiet_b_now == quiet_after(17'd0, elapsed_wide - 1'd1));
    end
  always @(posedge clk)
    if (!clear) begin
      // a run's first entry has seen no write and no edge of either pin
      if (!halted && !pending) assert(!wrote_a && !wrote_b && !moved_a && !moved_b);
      // an edge counts only after a write
      assert((wrote_a || !moved_a) && (wrote_b || !moved_b));
      if (pending && !manchester) assert((!e_fresh_a || !e_moved_a) && (!e_fresh_b || !e_moved_b));
      assert(quiet_a <= 17'h10000 && quiet_b <= 17'h10000);
      if (pending) assert(e_quiet_a <= 17'h10000 && e_quiet_b <= 17'h10000);
    end

  always @(posedge clk) begin
    cover(c3_recorded && spaced && wide_a && counts_a && moved_a && hold_a_now > 3
      && quiet_a == {1'b0, hold_a_now});
    cover(c3_recorded && spaced && wide_b && counts_b && moves_a && apart_b_now == 0);
  end
`endif

  // the lemma
  always @(posedge clk)
    if (!clear && pending && entry) begin
      if (!e_unbounded) assert(phase == e_expected || (e_may_carry && phase == e_expected - 1'd1));
      // the age of the captured edge and a cycle or more: unsigned
      if (capture_bounded) assert(now - t >= capture_lo && now - t <= capture_hi);
`ifdef TAKEN_BACKWARDS
      if (e_is_jmp && taken_known) assert(pc == (taken ? e_following : e_word[8:0]));
`else
      if (e_is_jmp && taken_known) assert(pc == (taken ? e_word[8:0] : e_following));
`endif
      else if (e_is_jmp) assert(pc == e_word[8:0] || pc == e_following);
      else assert(pc == e_following);
      if (x_known) assert(x == next_x);
      if (y_known) assert(y == next_y);
      if (period_known) assert(p == next_period);
      if (e_safe) assert(!missed_deadline);
    end

  always @(posedge clk) begin
    cover(pending && entry && e_may_carry && phase == e_expected - 1'd1);
    cover(pending && entry && !e_unbounded && e_deadline_wait && e_in_time);
    cover(loads_period && pending && entry && wrote_p && p == e_loaded && e_loaded > 3);
    cover(loads_period && wrote_p && loaded_before && p != last_load);
  end
`ifdef TABLE
  // The theorem in one run. For any table of intervals loaded while halted, as the program
  // is, assume the kernel's accepts at every pc entered, with the next and target rows it
  // picks, and a start at a row that bounds nothing; then the core lies in the row of every
  // entry and no deadline is missed. Rows have no slope and the full offset, as every
  // library table does. With AFFINE they are whole rows, and the run rests on row_step.
  // SPACING adds the pair's bounds to the rows, for phase_spacing.sby.
`ifdef AFFINE
  localparam ROW_BITS = 266;
`elsif SPACING
  localparam ROW_BITS = 368;
`else
  localparam ROW_BITS = 194;
`endif
  reg [ROW_BITS-1:0] rows [0:511];
  (* anyseq *) wire rows_write;
  (* anyseq *) wire [8:0] rows_addr;
  (* anyseq *) wire [ROW_BITS-1:0] rows_data;
`ifdef ROWS_WHILE_RUNNING
  always @(posedge clk) if (rows_write) rows[rows_addr] <= rows_data;
`else
  always @(posedge clk) if (halted && rows_write) rows[rows_addr] <= rows_data;
`endif
  // a row as kernel_accepts reads it: the phase, the slope, the offset, then the rest, the
  // pair's bounds last
  function [439:0] row_of(input [ROW_BITS-1:0] r);
`ifdef AFFINE
    row_of = {r, 174'd0};
`elsif SPACING
    row_of = {r[367:320], 24'd0, 24'h800000, 24'h7fffff, r[319:0]};
`else
    row_of = {r[193:146], 24'd0, 24'h800000, 24'h7fffff, r[145:0], 174'd0};
`endif
  endfunction

  wire [8:0] next_pc, target_pc, e_next_pc, e_target_pc;
`ifdef NEXT_NO_WRAP
  // the row after this one read without the wrap
  wire [439:0] row = row_of(rows[pc]), next_row = row_of(rows[pc + 9'd1]);
  wire [439:0] e_row = row_of(rows[e_pc]), e_next_row = row_of(rows[e_pc + 9'd1]);
`else
  wire [439:0] row = row_of(rows[pc]), next_row = row_of(rows[next_pc]);
  wire [439:0] e_row = row_of(rows[e_pc]), e_next_row = row_of(rows[e_next_pc]);
`endif
`ifdef TARGET_IS_NEXT
  // a jump's target read as the row after it
  wire [439:0] target_row = next_row, e_target_row = e_next_row;
`else
  wire [439:0] target_row = row_of(rows[target_pc]), e_target_row = row_of(rows[e_target_pc]);
`endif

`define CONFIG(load) \
    .side_set_count(side_set_count), .fraction(period_fraction != 0), \
    .loaded$valid(loads_period), .loaded$value(load), \
    .capture$pin(capture_pin), .capture$rising(capture_rising), \
    .capture$single_edge(single_edge), .wrap_top(wrap_top), .wrap_bottom(wrap_bottom)
`define NO_PAIR \
    `PAIR(1'b0), .a$since(16'd0), .a$level(1'b0), .a$fresh(1'b0), .b$since(16'd0), \
    .b$level(1'b0), .b$fresh(1'b0)
`ifdef AFFINE
  // The offset is the phase less the row's slope times x, modulo 2^24. SMT does not follow
  // a product of two variables, so the product and each successor's offset are free, held
  // to what the true ones satisfy: no product where x is zero, the core's offset where it
  // is at that successor's pc, and row_step's axioms. row_step's lemma holds for any
  // inputs, so assuming it drops no run.
  (* anyseq *) wire [23:0] product, next_offset, target_offset;
  reg [23:0] e_product;
  always @(posedge clk) if (entry) e_product <= product;
  wire [23:0] offset = phase - product, e_offset = e_phase - e_product;
  wire axioms, steps_into;
  row_step lemma (
    .side_set_count(side_set_count), .fraction(period_fraction != 0),
    .loads_period(loads_period), .loaded_period(e_loaded), .capture_pin(capture_pin),
    .capture_rising(capture_rising), .single_edge(single_edge), .word(e_word),
    .row(e_row[439:174]), .next(e_next_row[439:174]), .target(e_target_row[439:174]),
    .phase(e_phase), .offset(e_offset), .arm(e_g), .period(e_p), .x(e_x), .y(e_y),
    .arm_known(e_g_known), .captured(e_g_captured), .awaiting(e_g_awaiting),
    .phase_after(phase), .next_offset(next_offset), .target_offset(target_offset),
    .period_after(p), .x_after(x), .y_after(y), .axioms(axioms), .holds(steps_into));
  always @(*) begin
    assume(steps_into);
    if (entry && x == 0) assume(product == 0);
    if (entry && pending) begin
      assume(axioms);
      if (pc == e_next_pc) assume(next_offset == offset);
      if (pc == e_target_pc) assume(target_offset == offset);
    end
  end
  wire [23:0] slope = row[391:368], e_slope = e_row[391:368];
  wire [47:0] full = 48'h8000007fffff;
`ifdef OFFSET_UNCHECKED
  // accepts reads the rows it steps to with the full offset, so it checks no offset
`define NO_ACCEPTS
  function [439:0] unchecked(input [439:0] r);
    unchecked = {r[439:368], full, r[319:0]};
  endfunction
  wire unchecked_accepts;
  kernel_accepts check_unchecked (`CONFIG(loaded_period), `NO_PAIR,
    .pc(pc), .word(instruction), .row(row), .next(unchecked(next_row)),
    .target(unchecked(target_row)), .phase(phase), .offset(offset), .period(p), .x(x),
    .y(y), .arm(g), .arm_known(g_known), .captured(g_captured), .awaiting(g_awaiting),
    .next_pc(), .target_pc(), .accepts(unchecked_accepts), .within(), .starts_open());
  always @(*) if (entry) assume(unchecked_accepts);
`endif
`else
  // with no slope the offset is the phase
  wire [23:0] offset = phase, e_offset = e_phase;
`endif

  // at an entry, and at the last one, which the core keeps to between them
`define NOW \
    .pc(pc), .word(instruction), .row(row), .next(next_row), .target(target_row), \
    .phase(phase), .offset(offset), .period(p), .x(x), .y(y), .arm(g), \
    .arm_known(g_known), .captured(g_captured), .awaiting(g_awaiting)
`define LAST \
    .pc(e_pc), .word(e_word), .row(e_row), .next(e_next_row), .target(e_target_row), \
    .phase(e_phase), .offset(e_offset), .period(e_p), .x(e_x), .y(e_y), .arm(e_g), \
    .arm_known(e_g_known), .captured(e_g_captured), .awaiting(e_g_awaiting)
  wire accepts, within, starts_open;
`ifdef SPACING
  // With the pair's bounds, whose spacing the tooth drops. The last entry's check is
  // pair_step's; its lemma, from the last entry to now, holds for any inputs, so assuming
  // it drops no run.
`ifdef NO_SPACING
  wire spacing = 0;
`else
  wire spacing = spaced;
`endif
  kernel_accepts check_now (`CONFIG(loaded_period), `PAIR(spacing), .a$since(since_a),
    .a$level(level_a), .a$fresh(fresh_a), .b$since(since_b), .b$level(level_b),
    .b$fresh(fresh_b), `NOW,
    .next_pc(next_pc), .target_pc(target_pc), .accepts(accepts), .within(within),
    .starts_open(starts_open));
  assign e_next_pc = e_following, e_target_pc = e_word[8:0];
  wire e_inside, steps_into;
  pair_step lemma (
    .side_set_count(side_set_count), .fraction(period_fraction != 0),
    .loads_period(loads_period), .loaded_period(e_loaded), .capture_pin(capture_pin),
    .capture_rising(capture_rising), .single_edge(single_edge), .spaced(spaced),
    .pair_dirs(pair_dirs), .side_set_pindirs(side_set_pindirs), .pin_a(pin_a),
    .pin_b(pin_b), .side_set_base(side_set_base), .set_base(set_base),
    .out_base(out_base), .out_count(out_count), .set_count(set_count), .hold_a(hold_a),
    .apart_a(apart_a), .hold_b(hold_b), .apart_b(apart_b), .word(e_word),
    .row(rows[e_pc]), .next(rows[e_next_pc]), .target(rows[e_target_pc]),
    .phase(e_phase), .arm(e_g), .period(e_p), .x(e_x), .y(e_y), .arm_known(e_g_known),
    .captured(e_g_captured), .awaiting(e_g_awaiting), .since_a(e_since_a),
    .since_b(e_since_b), .level_a(e_level_a), .level_b(e_level_b), .fresh_a(e_fresh_a),
    .fresh_b(e_fresh_b), .data_a(e_data_a), .data_b(e_data_b), .phase_after(phase),
    .period_after(p), .x_after(x), .y_after(y), .inside(e_inside), .holds(steps_into));
  always @(*) assume(steps_into);
`else
  wire e_accepts, e_within;
  kernel_accepts check_now (`CONFIG(loaded_period), `NO_PAIR, `NOW, .next_pc(next_pc),
    .target_pc(target_pc), .accepts(accepts), .within(within), .starts_open(starts_open));
  kernel_accepts check_last (`CONFIG(e_loaded), `NO_PAIR, `LAST, .next_pc(e_next_pc),
    .target_pc(e_target_pc), .accepts(e_accepts), .within(e_within), .starts_open());
`endif

  always @(*) begin
`ifndef NO_ACCEPTS
    if (entry) assume(accepts);
`endif
`ifndef NO_OPEN
    if (entry && !pending) assume(starts_open);
`endif
  end
  always @(posedge clk)
    if (!clear) begin
`ifndef SPACING
      if (entry) assert(within);
      if (pending && !entry) assert(e_within && e_accepts);
`endif
      // running with no record is the stretch from a start to its first entry, at pc 0
      if (!halted && !pending) assert(pc == 9'd0 && fresh && stall == 0);
      // the teeth keep this one alone
      deadline: assert(!missed_deadline);
    end
`ifdef SPACING
  // the core and the pair in the rows, and every counted edge of the pair spaced
  always @(posedge clk)
    if (!clear) begin
      if (entry) edges_now: assert(within);
      if (pending && !entry) edges_last: assert(e_inside);
      if (c3_last_entry && spaced && !manchester) begin
        spacing_a: assert(spaced_a);
        spacing_b: assert(spaced_b);
      end
    end
`endif

  always @(posedge clk) begin
    cover(pending && entry && e_deadline_wait && e_phase == 0);
`ifdef AFFINE
    // a taken jmp x-- into a row of its slope with the full phase and a bounded offset,
    // and one falling through at x = 0 from such a row to a deadline wait whose bounded
    // phase that offset gives; both words decode and do not halt
    cover(pending && entry && !halts && e_is_jmp && e_word[12:9] == 1 && e_x != 0
      && pc == e_word[8:0] && row[439:392] == full && slope != 0 && slope == e_slope
      && row[367:320] != full);
    cover(pending && entry && !halts && deadline_wait && e_is_jmp && e_word[12:9] == 1
      && e_x == 0 && e_row[439:392] == full && e_slope != 0 && e_row[367:320] != full
      && row[439:392] != full);
`endif
  end
`ifdef CHIP
  // What the chip drives for each engine, nothing once its fault flop is set, and what the
  // pads show: the two ORed, an output pin taking an engine's level, a bidirectional one
  // only where its direction bit is set.
  wire [27:0] drive_out = faulted ? 28'd0 : pin_out;
  wire [27:0] drive_dir = faulted ? 28'd0 : pin_dir;
  wire [27:0] o_drive_out = o_faulted ? 28'd0 : o_pin_out;
  wire [27:0] o_drive_dir = o_faulted ? 28'd0 : o_pin_dir;
  localparam [27:0] OUTPUT_ONLY = 28'h0000fff;
  wire [27:0] pads_dir = drive_dir | o_drive_dir;
  wire [27:0] pads_out = drive_out & (drive_dir | OUTPUT_ONLY)
    | o_drive_out & (o_drive_dir | OUTPUT_ONLY);

  // The corollary. Each edge of this engine's drive comes the cycle after an entry inside
  // its row, but the release, on the edge its fault shows, after which it drives nothing.
  reg last_clear = 1, last_entry = 0, last_within = 0, last_faulted = 0;
  reg [27:0] last_drive_out = 0, last_drive_dir = 0;
  always @(posedge clk) begin
    last_clear <= clear;
    last_entry <= entry;
    last_within <= within;
    last_faulted <= faulted;
    last_drive_out <= drive_out;
    last_drive_dir <= drive_dir;
  end
  wire releases = faulted && !last_faulted;
  wire moved = drive_out != last_drive_out || drive_dir != last_drive_dir;
`ifdef EDGE_AT_ENTRY
  // the tooth takes the edge for the entry's own cycle
  wire edge_entry = entry && within;
`else
  wire edge_entry = last_entry && last_within;
`endif
  always @(posedge clk)
    if (!clear) begin
      on_pads: assert(chip_out == pads_out[19:0] && chip_dir == pads_dir[19:0]);
      // the flop is the OR of the four the host reads
      one_flop: assert(faulted == (underflow || overflow || missed_deadline || decode)
        && o_faulted == (o_underflow || o_overflow || o_missed_deadline || o_decode));
      if (!last_clear) begin
        stays_released: assert(!last_faulted || faulted);
        if (moved) certified: assert(releases || edge_entry);
      end
    end

  // edge_step.sv's invariants, which the claim needs for induction: a Manchester second
  // half is owed from its out's entry to the next entry, and a held wait's side-set is on
  // the pins already
  function [27:0] write
    (input [27:0] old, input [4:0] base, input [4:0] n, input [15:0] v, input [27:0] takes);
    reg [27:0] hit;
    begin
      hit = place(mask(n), base) & takes;
      write = old & ~hit | place(v, base) & hit;
    end
  endfunction
  wire edge_runs = decode_ok && opcode != 0;
  wire side_pins = edge_runs && side_set_count != 0 && !side_set_pindirs;
  wire side_dirs = edge_runs && side_set_count != 0 && side_set_pindirs;
  wire manchester_bit = edge_runs && opcode == 3 && instruction[7:5] == 0 && manchester
    && instruction[4:0] == 1;
  reg flip_owed = 0;
  always @(posedge clk)
    if (clear || started) flip_owed <= 0;
    else if (entry) flip_owed <= manchester_bit;
  reg [5:0] since_out = 0, out_step = 0;
  always @(posedge clk)
    if (entry && manchester_bit) begin
      since_out <= 1;
      out_step <= delay + 6'd1;
    end else if (since_out != 63) since_out <= since_out + 6'd1;
  wire [27:0] flip_pair = place(16'd3, out_base) & OUTPUTS;
  wire [27:0] flipped = flip_owed ? pin_out ^ flip_pair : pin_out;
  wire [15:0] side_value =
    side_set_count == 1 ? {15'd0, instruction[12]} : {14'd0, instruction[12:11]};
  wire [27:0] first_half_held = place({14'd0, flip_bit, !flip_bit}, out_base) & OUTPUTS;
  always @(posedge clk)
    if (!clear) begin
      assert(flip_pending == flip_owed);
      if (flip_owed) assert((pin_out & flip_pair) == first_half_held);
      if (flip_owed && !halted) assert(since_out <= out_step && stall == out_step - since_out);
      if (!fresh && !halted) begin
        assert(opcode == 1 && decode_ok && stall == 0 && !started);
        if (side_pins)
          assert(write(flipped, side_set_base, side_set_count, side_value, OUTPUTS) == pin_out);
        if (side_dirs)
          assert(write(pin_dir, side_set_base, side_set_count, side_value, BIDIRS) == pin_dir);
      end
    end

  always @(posedge clk)
    if (!clear && !last_clear) begin
      // a bidirectional pin moves the cycle after an entry inside its row
      cover(moved && !releases && edge_entry && (drive_dir ^ last_drive_dir) != 0);
      // a fault lets go of a bidirectional pad this engine alone drove, the other engine
      // still driving one of its own
      cover(releases && (last_drive_dir[19:12] & ~o_drive_dir[19:12]) != 0
        && o_drive_dir[19:12] != 0);
    end
`endif
`endif
endmodule
