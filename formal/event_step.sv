// Event lemma: for any program and constant config, a pin wait at an issue releases in
// exactly the cycle whose sample shows its level, or for an edge that level after the
// other, and a held wait issues again the next cycle, so no event goes unseen and none is
// invented. A jmp on the pin goes where that cycle's sample says, as a poll and a guard
// need. An input pin, and a bidirectional one not driven, samples that cycle's input.

module event_step (input clk);
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
  (* anyseq *) wire [15:0] data_word;
  (* anyseq *) wire stop, flush;
  (* anyseq *) wire start, program_write_valid, tx_valid, rx_pop, clear_irq;
  (* anyseq *) wire [8:0] program_write_addr;
  (* anyseq *) wire [15:0] program_write_data, tx_value;
  (* anyseq *) wire [27:0] inputs;

  // the top clears the engine at power-on and whenever its reset comes again
  (* anyseq *) wire reset;
  reg clear = 1;
  always @(posedge clk) clear <= reset;

  wire [27:0] pin_out, pin_dir;
  wire [8:0] pc;
  wire [15:0] x, y, p, osr, isr, rx_head, instruction, crc;
  wire [23:0] t, now, capture;
  wire [4:0] osr_count, isr_count, stall, stuff_run;
  wire halted, irq, underflow, overflow, missed_deadline, decode, capture_armed;
  wire flip_pending, flip_bit;
  wire [3:0] tx_level, rx_level;
  wire decode_ok;
  wire [7:0] opcode_onehot;
  wire [27:0] wait_select;
  wire jmp_go, advance;
  wire [15:0] out_value, mov_value;
  wire [27:0] sample;

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
    .flip_pending(flip_pending), .flip_bit(flip_bit),
    .eng_jmp_go(jmp_go), .eng_advance(advance), .eng_out_value(out_value),
    .eng_mov_value(mov_value), .eng_sample(sample));

  // an issue, as in edge_step.sv
  reg started = 0;
  always @(posedge clk) started <= start;
  wire issue = !clear && !halted && stall == 0 && !started;

  reg [27:0] previous = 0;
  always @(posedge clk) previous <= clear ? 28'd0 : sample;

  wire [2:0] opcode = instruction[15:13];
  wire [1:0] source = instruction[6:5];
  wire polarity = instruction[7];
  wire [4:0] index = instruction[4:0];
  wire pin_wait = decode_ok && opcode == 1 && (source == 0 || source == 1);
  // an index past the pin space reads low
  wire now_level = (index < 28 && sample[index]) == polarity;
  wire was_other = (index < 28 && previous[index]) != polarity;
  wire [3:0] cond = instruction[12:9];
  wire pin_jump = decode_ok && opcode == 0 && (cond == 4 || cond == 5) && jmp_pin < 28;
`ifdef JUMP_LATE
  wire pin_high = previous[jmp_pin];
`else
  wire pin_high = sample[jmp_pin];
`endif
`ifdef LATE
  reg late_level = 0;
  always @(posedge clk) late_level <= now_level;
  wire ready = late_level;
`elsif LEVEL_ONLY
  wire ready = now_level;
`else
  wire ready = source == 0 ? now_level : now_level && was_other;
`endif

  // the registered decode agrees with the word, as issue_timing.sv proves
  always @(posedge clk)
    if (!clear) begin
      assert(opcode_onehot == 8'b1 << opcode);
      assert(wait_select == 28'd1 << index);
    end

  always @(*) begin
    if (!clear && issue && pin_wait) assert(advance == ready);
    if (!clear) begin
`ifdef WIRES_PLAIN
      assert(sample[27:20] == inputs[27:20]);
`else
      assert(sample[27:20] == (inputs[27:20] | pin_out[27:20]));
`endif
      assert(sample[4:0] == inputs[4:0]);
      assert((sample[19:12] & ~pin_dir[19:12]) == (inputs[19:12] & ~pin_dir[19:12]));
    end
  end

  // a wait that holds issues again, unless the host stops or starts the core
  reg held = 0, held_edge = 0;
  reg [8:0] held_pc = 0;
  always @(posedge clk) begin
    held <= !clear && issue && pin_wait && !advance && !stop && !start && !reset;
    held_edge <= source == 1;
`ifdef HELD_MOVES
    held_pc <= pc + 9'd1;
`else
    held_pc <= pc;
`endif
  end
  always @(*) if (held && !clear) assert(issue && pc == held_pc);

  // the jump lands where the sample says, unless the host stops or starts the core
  reg jumped = 0, jump_taken = 0, jump_not_pin = 0, jump_at_wrap = 0;
  reg [8:0] jump_target = 0, jump_following = 0;
  always @(posedge clk) begin
    jumped <= !clear && issue && pin_jump && !stop && !start && !reset;
    jump_taken <= pin_high == (cond == 4);
    jump_not_pin <= cond == 5;
    jump_at_wrap <= pc == wrap_top && wrap_bottom != pc + 9'd1;
    jump_target <= instruction[8:0];
    jump_following <= pc == wrap_top ? wrap_bottom : pc + 9'd1;
  end
  always @(*) if (jumped && !clear) assert(pc == (jump_taken ? jump_target : jump_following));

`ifndef LATE
  always @(*) cover(issue && pin_wait && source == 1 && advance && index == 0);
  always @(*) cover(issue && pin_wait && source == 0 && advance);
  always @(*) cover(held && !clear);
  always @(*) cover(held && held_edge && !clear);
  always @(*) cover(jumped && jump_taken && jump_target != jump_following);
  always @(*) cover(jumped && !jump_taken && jump_target != jump_following);
  always @(*) cover(jumped && jump_not_pin && jump_taken && jump_target != jump_following);
  always @(*) cover(jumped && jump_not_pin && !jump_taken && jump_target != jump_following);
  always @(*) cover(jumped && !jump_taken && jump_at_wrap && jump_target != jump_following);
`endif
endmodule
