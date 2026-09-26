// Step lemma for the universal certificate. For any program, from one instruction's entry
// to the next, the core does what the kernel's step says: the phase [now - t], p, x, y and
// the pc. A deadline wait entered at phase <= 0 does not fault. Equalities are mod 2^24.

module phase_step (input clk);
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
  // the assumption the kernel may take: every run-time write to p carries loaded_period
  (* anyconst *) wire loads_period;
  (* anyconst *) wire [15:0] loaded_period;
  (* anyseq *) wire data_write_valid;
  (* anyseq *) wire [8:0] data_write_addr;
  (* anyseq *) wire [15:0] data_write_data;
  (* anyseq *) wire stop, flush;
  (* anyseq *) wire start, program_write_valid, tx_valid, rx_pop, clear_irq;
  (* anyseq *) wire [8:0] program_write_addr;
  (* anyseq *) wire [15:0] program_write_data, tx_value;
  (* anyseq *) wire [27:0] inputs;

  reg clear = 1;
  always @(posedge clk) clear <= 0;

  wire [27:0] pin_out, pin_dir;
  wire [8:0] pc;
  wire [15:0] x, y, p, osr, isr, rx_head, instruction, crc;
  wire [23:0] t, now, capture;
  wire [4:0] osr_count, isr_count, stall, stuff_run;
  wire halted, irq, underflow, overflow, missed_deadline, decode, capture_armed;
  wire resumed, stepping;
  wire [3:0] tx_level, rx_level;
  wire decode_ok;
  wire [7:0] opcode_onehot;
  wire [27:0] wait_select;
  wire [27:0] wait_pin = 28'd1 << instruction[4:0];
  wire completes;

  engine_top dut (
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
    .config$break_enable(1'b0), .config$break_pc(9'd0),
    .config$autopull_data(autopull_data), .config$manchester(manchester),
    .stop(stop), .flush(flush), .resume(1'b0), .single_step(1'b0),
    .start(start), .program_write$valid(program_write_valid),
    .program_write$addr(program_write_addr), .program_write$data(program_write_data),
    .data_write$valid(data_write_valid), .data_write$addr(data_write_addr),
    .data_write$data(data_write_data),
    .tx$valid(tx_valid), .tx$value(tx_value), .rx_pop(rx_pop), .clear_irq(clear_irq),
    .inputs(inputs),
    .pin_out(pin_out), .pin_dir(pin_dir), .pc(pc), .x(x), .y(y), .p(p), .t(t), .osr(osr),
    .osr_count(osr_count), .isr(isr), .isr_count(isr_count), .now(now), .stall(stall),
    .halted(halted), .resumed(resumed), .stepping(stepping), .irq(irq), .fault$underflow(underflow), .fault$overflow(overflow),
    .fault$missed_deadline(missed_deadline), .fault$decode(decode), .capture(capture),
    .capture_armed(capture_armed), .tx_level(tx_level), .rx_level(rx_level),
    .rx_head(rx_head), .instruction(instruction), .crc(crc), .stuff_run(stuff_run),
    .decode_ok(decode_ok), .opcode_onehot(opcode_onehot), .wait_select(wait_select),
    .eng_completes(completes));

  always @(*) begin
    assume(side_set_count <= 2);
    assume(!start || halted);
    assume(!program_write_valid || halted);
  end

  wire [2:0] opcode = instruction[15:13];
  wire [4:0] ds = instruction[12:8];
  function [4:0] delay_of(input [4:0] d);
    delay_of = side_set_count == 0 ? d : side_set_count == 1 ? d[3:0] : d[2:0];
  endfunction
  wire [4:0] delay = delay_of(ds);
  always @(posedge clk)
    if (!clear) begin
      assert(opcode_onehot == 8'b1 << opcode);
      assert(wait_select == wait_pin);
      assert(!stepping && !resumed);
    end

  // an entry is the first issue after a start or after a completion
  reg started = 0;
  always @(posedge clk) started <= start;
  wire issue = !clear && !halted && stall == 0 && !started;
  reg fresh = 0;
  always @(posedge clk)
    if (clear || start || completes) fresh <= 1;
    else if (issue) fresh <= 0;
  wire entry = issue && fresh;
  wire signed [23:0] phase = now - t;

  // the analyser's instruction classes
  function is_deadline_wait(input [15:0] w);
    is_deadline_wait = w[15:13] == 1 && w[6:5] == 2;
  endfunction
  function [8:0] following_of(input [8:0] a);
    following_of = a == wrap_top ? wrap_bottom : a + 9'd1;
  endfunction
  function [23:0] step_of(input [15:0] w);
    step_of = w[15:13] == 0 ? 24'd2 : delay_of(w[12:8]) + 24'd1;
  endfunction

  wire is_jmp = opcode == 0;
  wire deadline_wait = is_deadline_wait(instruction);
  wire [2:0] operand = instruction[2:0];
  wire [23:0] step = step_of(instruction);


  // what t holds after the instruction; a wait moves it at the release
  wire [7:0] body = instruction[7:0];
  wire [23:0] t_after =
      opcode == 4 && body == 8'b11100110 ? now
    : opcode == 6 && body[7:3] == 5'b11000 ? t + operand
    : opcode == 6 && body == 8'b11001010 ? t + {8'd0, p}
    : opcode == 6 && body == 8'b11001000 ? t + {8'd0, x}
    : opcode == 6 && body == 8'b11001001 ? t + {8'd0, y}
    : opcode == 6 && body[7:3] == 5'b11010 ? t - operand
    : deadline_wait && body[7] ? t + {8'd0, p}
    : t;

  // Record of the last entry. Before completion the core holds the same word, pc and t;
  // after, [now + stall] is the next entry's cycle and t what the instruction left.
  reg pending = 0;
  reg done = 0;
  reg [15:0] e_word, e_p, e_x, e_y;
  reg [8:0] e_pc;
  reg [23:0] e_t, e_now, e_phase, e_next_now, e_t_after;
  wire [23:0] e_step = step_of(e_word);
  reg e_safe;
  wire e_is_jmp = e_word[15:13] == 0;
  wire e_deadline_wait = is_deadline_wait(e_word);
  wire [8:0] e_following = following_of(e_pc);
  wire e_in_time = e_phase[23] || e_phase == 0;
  always @(posedge clk)
    if (clear || start || stop) pending <= 0;
    else if (entry) begin
      pending <= decode_ok && !halts;
      done <= completes;
      e_word <= instruction;
      e_p <= p;
      e_x <= x;
      e_y <= y;
      e_pc <= pc;
      e_t <= t;
      e_now <= now;
      e_phase <= phase;
      e_next_now <= now + step;
      e_t_after <= t_after;
`ifdef ONE_LATE_CYCLE_IS_SAFE
      e_safe <= !missed_deadline && (!deadline_wait || phase[23] || phase <= 1);
`else
      e_safe <= !missed_deadline && (!deadline_wait || phase[23] || phase == 0);
`endif
    end
    else if (pending && !done && completes) begin
      done <= 1;
      e_next_now <= now + step;
      e_t_after <= t_after;
    end

  // the kernel's step, the definition the checker uses
  wire [23:0] next_phase;
  wire [15:0] next_period, next_x, next_y;
  wire x_known, y_known, taken, taken_known;
  wire bounded, carries, period_known;
  kernel_step e_step_of (
    .side_set_count(side_set_count), .fraction(period_fraction != 0),
    .loaded$valid(loads_period), .loaded$value(loaded_period), .word(e_word),
    .phase(e_phase), .period(e_p), .x(e_x), .y(e_y), .next_phase(next_phase),
    .bounded(bounded), .may_carry(carries), .next_period(next_period),
    .period_known(period_known), .next_x(next_x), .x_known(x_known), .next_y(next_y),
    .y_known(y_known), .taken(taken), .taken_known(taken_known), .halts());
  // whether the word at an entry has a next one
  wire halts, keeps_period;
  kernel_step halts_of (
    .side_set_count(side_set_count), .fraction(1'b0), .loaded$valid(1'b0),
    .loaded$value(16'd0), .word(instruction), .phase(24'd0), .period(16'd0), .x(16'd0),
    .y(16'd0), .next_phase(), .bounded(), .may_carry(), .next_period(),
    .period_known(keeps_period), .next_x(), .x_known(), .next_y(), .y_known(), .taken(),
    .taken_known(), .halts(halts));

  reg wrote_p = 0;
  always @(posedge clk) wrote_p <= !clear && completes && !keeps_period;
  always @(*) if (loads_period && wrote_p) assume(p == loaded_period);

  // each teeth task gets one part of the step wrong
  wire [23:0] e_expected =
`ifdef JUMP_IN_ONE
    e_is_jmp ? next_phase - 24'd1 :
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
  wire t_ok = t == e_t_after || (e_may_carry && t == e_t_after + 24'd1);

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
        if (e_deadline_wait && e_in_time && !completes) assert(phase[23]);
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
        if (!e_unbounded) begin
          assert(t_ok);
          assert(e_next_now - e_t_after == e_expected);
        end
      end
    end

  // a deadline wait entered in time releases on its deadline
  always @(posedge clk)
    if (!clear && pending && !done && completes && e_deadline_wait && e_in_time)
      assert(now == e_t);

  // the lemma
  always @(posedge clk)
    if (!clear && pending && entry) begin
      if (!e_unbounded) assert(phase == e_expected || (e_may_carry && phase == e_expected - 24'd1));
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
    cover(pending && entry && e_may_carry && phase == e_expected - 24'd1);
    cover(pending && entry && !e_unbounded && e_deadline_wait && e_in_time);
    cover(loads_period && pending && entry && wrote_p && p == loaded_period && loaded_period > 3);
  end
endmodule
