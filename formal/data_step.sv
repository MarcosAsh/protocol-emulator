// Data lemma: which bits of which word an out sends. A ghost count of bits shifted out
// since the osr last took a word (on past 16 to 32), and whether a pull or an autopull
// took it, move as osr_step.v (the checker's own step) says. From the clear on, osr_count
// is the count stopped at 16, the osr holds the word shifted by it, and each out whose
// word was pulled sends bits [c, c + n) of it from the end the osr shifts from (c the
// count, 0 after an autopull), or underflow is set by that out or before, unless a
// sending CRC gives a single-bit out its own bit (value_step.sv). A take finds
// no word from an empty fifo or a data pointer moved the cycle before; a mov to the osr
// writes none. The word is the tx fifo's head (fifo_order.sv) or the data memory's word;
// the value reaches the pins by edge_step.sv. Nothing is assumed of the host (stop, flush,
// start, program writes, fifos, data word, clear all free); the config holds still with
// side-set on at most 2 pins, as in phase_step.sv.

module data_step (input clk);
  (* anyconst *) wire [1:0] side_set_count;
  (* anyconst *) wire [4:0] side_set_base, in_base, in_count, out_base, out_count, set_base;
  (* anyconst *) wire [2:0] set_count;
  (* anyconst *) wire [4:0] jmp_pin, capture_pin, push_threshold, pull_threshold;
  (* anyconst *) wire side_set_pindirs, capture_rising, in_shift_right, out_shift_right, autopush, autopull;
  (* anyconst *) wire [5:0] crc_width;
  (* anyconst *) wire [4:0] stuff_threshold;
  (* anyconst *) wire [15:0] crc_poly, crc_init, crc_poly_high, crc_init_high;
  (* anyconst *) wire crc_reflect, crc_complement, stuff_level;
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
  wire [15:0] x, y, p, osr, isr, rx_head, instruction;
  wire [31:0] crc;
  wire crc_sending;
  wire [23:0] t, now, capture;
  wire [4:0] osr_count, isr_count, stall, stuff_run;
  wire halted, irq, underflow, overflow, missed_deadline, decode, capture_armed;
  wire [3:0] tx_level, rx_level;
  wire decode_ok;
  wire [7:0] opcode_onehot;
  wire [27:0] wait_select;
  // the value an out shifts, the tx fifo's head, and the core's note of a data pointer
  // that moved the cycle before
  wire [15:0] out_value, tx_head;
  wire tx_empty, data_moved;

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
    .config$crc_poly_high(crc_poly_high), .config$crc_init_high(crc_init_high),
    .config$crc_complement(crc_complement),
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
    .rx_head(rx_head), .instruction(instruction), .crc(crc), .crc_sending(crc_sending), .stuff_run(stuff_run),
    .decode_ok(decode_ok), .opcode_onehot(opcode_onehot), .wait_select(wait_select),
    .eng_out_value(out_value), .eng_tx_head(tx_head), .eng_tx_empty(tx_empty),
    .eng_data_moved(data_moved));

  always @(*) assume(side_set_count <= 2);

  // an issue, as the model's step has it: running, the delay run out, no start in flight
  reg started = 0;
  always @(posedge clk) started <= !clear && start;
  wire issue = !clear && !halted && stall == 0 && !started;
  wire go = issue && decode_ok;

  wire [2:0] opcode = instruction[15:13];
  wire [4:0] n = instruction[4:0];
  wire is_out = opcode == 3;
  wire is_mov_osr = opcode == 4 && instruction[7:5] == 5;

  // the osr kernel's step, on the count and the note the ghost keeps
  reg [5:0] shifted = 16;
  reg pulled = 0;
  wire [5:0] next_shifted;
  wire next_pulled, takes;
  osr_step step (
    .side_set_count(side_set_count), .autopull(autopull), .pull_threshold(pull_threshold),
    .word(instruction), .shifted(shifted), .pulled(pulled), .next_shifted(next_shifted),
    .next_pulled(next_pulled), .takes(takes));

  // The word the osr last took, and whether the take found one: an autopull reads the data
  // memory with autopull_data, and every other take the tx fifo.
  wire from_data = is_out && autopull_data;
  wire found = from_data ? !data_moved : !tx_empty;
  wire [15:0] found_word = from_data ? data_word : tx_head;
  reg holds_word = 0;
  reg [15:0] word = 0;
  always @(posedge clk)
    if (clear) begin
      shifted <= 16;
      pulled <= 0;
      holds_word <= 0;
    end else if (go) begin
      shifted <= next_shifted;
      pulled <= next_pulled;
      if (takes) begin
`ifdef STALE_WORD
        // a take that finds nothing keeps the word before it
        holds_word <= holds_word || found;
`else
        holds_word <= found;
`endif
        if (found) word <= found_word;
      end else if (is_mov_osr) holds_word <= 0;
    end

  // w shifted by c, which past 15 leaves nothing
  function [15:0] shifted_by(input [15:0] w, input [5:0] c);
`ifdef WRONG_WAY
    shifted_by = out_shift_right ? w << c : w >> c;
`else
    shifted_by = out_shift_right ? w >> c : w << c;
`endif
  endfunction
  // the n bits of w from c on, counted from the end the osr shifts from, low bit first
  function [15:0] bits(input [15:0] w, input [5:0] c, input [4:0] n);
    reg [15:0] mask;
    begin
      mask = n >= 16 ? 16'hffff : (16'd1 << n) - 16'd1;
      bits = (out_shift_right ? shifted_by(w, c) : shifted_by(w, c) >> (5'd16 - n)) & mask;
    end
  endfunction

  // what an out starts from: after an autopull, the word it takes at count 0
  wire pull_now = autopull && osr_count >= pull_threshold;
  wire [5:0] c = pull_now ? 6'd0 : shifted;
  wire [15:0] out_word = pull_now ? found_word : word;
  wire out_has_word = pull_now ? found : holds_word;
  reg sets_underflow = 0;
  always @(posedge clk) sets_underflow <= go && is_out && pull_now && !found;

  always @(posedge clk)
    if (!clear) begin
      assert(opcode_onehot == 8'b1 << opcode);
      assert(shifted <= 32);
      assert(osr_count == (shifted > 16 ? 5'd16 : shifted[4:0]));
      if (pulled) assert(holds_word || underflow);
      if (holds_word) assert(osr == shifted_by(word, shifted));
      if (sets_underflow) assert(underflow);
      // the lemma
      if (go && is_out && next_pulled && !(crc_sending && n == 1))
`ifdef OFF_BY_ONE
        assert(out_has_word ? out_value == bits(out_word, c + 6'd1, n) : underflow || pull_now);
`else
        assert(out_has_word ? out_value == bits(out_word, c, n) : underflow || pull_now);
`endif
    end

  always @(posedge clk) begin
    cover(go && is_out && out_has_word && out_shift_right && c == 7 && n == 1);
    cover(go && is_out && out_has_word && !out_shift_right && c == 3 && n == 2);
    cover(go && is_out && pull_now && found && from_data);
    cover(go && is_out && pulled && !holds_word && underflow);
    cover(go && is_out && out_has_word && shifted == 17);
  end
endmodule
