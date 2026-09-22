// P1: the gap between one issue and the next depends only on the instruction's
// delay field, never on data. A jump always takes two cycles. The host may write the
// configuration at any time, so here it can change in every cycle. A debugger that
// breaks, resumes or steps decides the gaps itself, so it sits still here.
//
// Each teeth task in issue_timing.sby defines one of the names tested below, which gets
// one part of the statement wrong, and the proof must then fail.
module issue_timing (input clk);
  (* anyseq *) wire [1:0] side_set_count;
  (* anyseq *) wire [4:0] side_set_base, in_base, in_count, out_base, out_count, set_base;
  (* anyseq *) wire [2:0] set_count;
  (* anyseq *) wire [4:0] jmp_pin, capture_pin, push_threshold, pull_threshold;
  (* anyseq *) wire side_set_pindirs, capture_rising, in_shift_right, out_shift_right, autopush, autopull;
  (* anyseq *) wire [4:0] crc_width, stuff_threshold;
  (* anyseq *) wire [15:0] crc_poly, crc_init;
  (* anyseq *) wire crc_reflect, stuff_level;
  (* anyseq *) wire [8:0] wrap_bottom, wrap_top;
  (* anyseq *) wire [15:0] period_fraction;
  (* anyseq *) wire break_enable, resume, single_step;
  (* anyseq *) wire [8:0] break_pc;
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
    .config$break_enable(break_enable), .config$break_pc(break_pc),
    .stop(stop), .flush(flush), .resume(resume), .single_step(single_step),
    .start(start), .program_write$valid(program_write_valid),
    .program_write$addr(program_write_addr), .program_write$data(program_write_data),
    .tx$valid(tx_valid), .tx$value(tx_value), .rx_pop(rx_pop), .clear_irq(clear_irq),
    .inputs(inputs),
    .pin_out(pin_out), .pin_dir(pin_dir), .pc(pc), .x(x), .y(y), .p(p), .t(t), .osr(osr),
    .osr_count(osr_count), .isr(isr), .isr_count(isr_count), .now(now), .stall(stall),
    .halted(halted), .resumed(resumed), .stepping(stepping), .irq(irq), .fault$underflow(underflow), .fault$overflow(overflow),
    .fault$missed_deadline(missed_deadline), .fault$decode(decode), .capture(capture),
    .capture_armed(capture_armed), .tx_level(tx_level), .rx_level(rx_level),
    .rx_head(rx_head), .instruction(instruction), .crc(crc), .stuff_run(stuff_run),
    .decode_ok(decode_ok), .opcode_onehot(opcode_onehot));

  always @(*) begin
    assume(side_set_count <= 2);
    assume(!start || halted);
    assume(!program_write_valid || halted);
    assume(!break_enable && !resume && !single_step);
  end

  reg started = 0;
  always @(posedge clk) started <= start;
  wire issue = !halted && stall == 0 && !started;
  wire [2:0] opcode = instruction[15:13];
  wire [4:0] ds = instruction[12:8];
`ifdef DELAY_IGNORES_SIDE_SET
  wire [4:0] delay = ds;
`else
  wire [4:0] delay = side_set_count == 0 ? ds : side_set_count == 1 ? ds[3:0] : ds[2:0];
`endif
  wire [4:0] count = instruction[4:0];
  wire waits = opcode == 1 && (instruction[6] ? count == 0 : count < 28);
  wire plain =
`ifdef WAITS_ARE_PLAIN
      waits ||
`endif
      (opcode == 2 && count >= 1 && count <= 16)   // in
   || (opcode == 3 && count >= 1 && count <= 16)   // out
   || (opcode == 4 && instruction[4:3] != 3)        // mov
   || (opcode == 5 && instruction[7:5] < 5)         // set
   || (opcode == 6 && instruction[5:4] != 3 && (!instruction[3] || instruction[2:0] < 5)); // alu
  wire jump = opcode == 0 && instruction[12:9] < 12;
  wire sys = opcode == 7 && instruction[7:3] == 0;

  // what the core registers beside the instruction always agrees with it, and with no
  // debugger nothing is waiting to halt it after a step
  always @(posedge clk)
    if (!clear) begin
      assert(decode_ok == (plain || jump || waits || sys));
      assert(opcode_onehot == 8'b1 << opcode);
      assert(!stepping);
    end

  reg armed = 0;
  reg [4:0] remaining = 0;
  always @(posedge clk)
    if (clear || start || stop) armed <= 0;
    else if (issue && plain) begin armed <= 1; remaining <= delay; end
`ifdef JUMP_IN_ONE
    else if (issue && jump) begin armed <= 1; remaining <= 0; end
`else
    else if (issue && jump) begin armed <= 1; remaining <= 1; end
`endif
    else if (issue) armed <= 0;
    else if (armed && remaining != 0) remaining <= remaining - 1;

  always @(posedge clk)
    if (!clear && armed) begin
      assert(stall == remaining);
      assert(!halted);
      if (remaining != 0) assert(!issue);
      else assert(issue);
    end

  always @(posedge clk) begin
    cover(armed && remaining == 31);
    cover(armed && remaining == 0 && issue && $past(jump, 2));
  end
endmodule
