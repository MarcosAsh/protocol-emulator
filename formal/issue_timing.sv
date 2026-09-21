// P1: the gap between one issue and the next depends only on the instruction's
// delay field, never on data. A jump always takes two cycles.
module issue_timing (input clk);
  (* anyconst *) wire [1:0] side_set_count;
  (* anyconst *) wire [4:0] side_set_base, in_base, out_base, out_count, set_base;
  (* anyconst *) wire [2:0] set_count;
  (* anyconst *) wire [4:0] jmp_pin, capture_pin, push_threshold, pull_threshold;
  (* anyconst *) wire side_set_pindirs, capture_rising, in_shift_right, out_shift_right, autopush, autopull;
  (* anyseq *) wire start, program_write_valid, tx_valid, rx_pop, clear_irq;
  (* anyseq *) wire [8:0] program_write_addr;
  (* anyseq *) wire [15:0] program_write_data, tx_value;
  (* anyseq *) wire [19:0] inputs;

  reg clear = 1;
  always @(posedge clk) clear <= 0;

  wire [19:0] pin_out, pin_dir;
  wire [8:0] pc;
  wire [15:0] x, y, p, osr, isr, rx_head, instruction, crc;
  wire [23:0] t, now, capture;
  wire [4:0] osr_count, isr_count, stall, stuff_run;
  wire halted, irq, underflow, overflow, missed_deadline, decode, capture_armed;
  wire [2:0] tx_level, rx_level;
  wire decode_ok;
  wire [7:0] opcode_onehot;

  engine_top dut (
    .clock(clk), .clear(clear),
    .config$side_set_count(side_set_count), .config$side_set_base(side_set_base),
    .config$side_set_pindirs(side_set_pindirs), .config$in_base(in_base),
    .config$out_base(out_base), .config$out_count(out_count), .config$set_base(set_base),
    .config$set_count(set_count), .config$jmp_pin(jmp_pin), .config$capture_pin(capture_pin),
    .config$capture_rising(capture_rising), .config$in_shift_right(in_shift_right),
    .config$out_shift_right(out_shift_right), .config$autopush(autopush),
    .config$push_threshold(push_threshold), .config$autopull(autopull),
    .config$pull_threshold(pull_threshold),
    .start(start), .program_write$valid(program_write_valid),
    .program_write$addr(program_write_addr), .program_write$data(program_write_data),
    .tx$valid(tx_valid), .tx$value(tx_value), .rx_pop(rx_pop), .clear_irq(clear_irq),
    .inputs(inputs),
    .pin_out(pin_out), .pin_dir(pin_dir), .pc(pc), .x(x), .y(y), .p(p), .t(t), .osr(osr),
    .osr_count(osr_count), .isr(isr), .isr_count(isr_count), .now(now), .stall(stall),
    .halted(halted), .irq(irq), .fault$underflow(underflow), .fault$overflow(overflow),
    .fault$missed_deadline(missed_deadline), .fault$decode(decode), .capture(capture),
    .capture_armed(capture_armed), .tx_level(tx_level), .rx_level(rx_level),
    .rx_head(rx_head), .instruction(instruction), .crc(crc), .stuff_run(stuff_run),
    .decode_ok(decode_ok), .opcode_onehot(opcode_onehot));

  always @(*) begin
    assume(side_set_count <= 2);
    assume(!start || halted);
    assume(!program_write_valid || halted);
  end

  reg started = 0;
  always @(posedge clk) started <= start;
  wire issue = !halted && stall == 0 && !started;
  wire [2:0] opcode = instruction[15:13];
  wire [4:0] ds = instruction[12:8];
  wire [4:0] delay = side_set_count == 0 ? ds : side_set_count == 1 ? ds[3:0] : ds[2:0];
  wire [4:0] count = instruction[4:0];
  wire plain =
      (opcode == 2 && count >= 1 && count <= 16)   // in
   || (opcode == 3 && count >= 1 && count <= 16)   // out
   || (opcode == 4 && instruction[4:3] != 3)        // mov
   || (opcode == 5 && instruction[7:5] < 5)         // set
   || (opcode == 6 && instruction[5:4] != 3 && (!instruction[3] || instruction[2:0] < 5)); // alu
  wire jump = opcode == 0 && !instruction[9];
  wire waits = opcode == 1 && (instruction[6] ? count == 0 : count < 20);
  wire sys = opcode == 7 && instruction[7:3] == 0;

  // what the core registers beside the instruction always agrees with it
  always @(posedge clk)
    if (!clear) begin
      assert(decode_ok == (plain || jump || waits || sys));
      assert(opcode_onehot == 8'b1 << opcode);
    end

  reg armed = 0;
  reg [4:0] remaining = 0;
  always @(posedge clk)
    if (clear || start) armed <= 0;
    else if (issue && plain) begin armed <= 1; remaining <= delay; end
    else if (issue && jump) begin armed <= 1; remaining <= 1; end
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
