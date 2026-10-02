// Value lemma, beside edge_step.sv: at every issue of a word the ISA decodes, the ISA's
// value (ISA.md and machine.ml, restated here, not taken from the core) reaches the osr,
// isr, their counts, the data pointer, underflow, overflow, the fifo pops and pushes, and
// the pins, pindirs, x, y, p or t the word writes, as does a Manchester bit's second half
// at the next issue. Pins.write of that value on the pins holds only for a constant
// config, which edge_step.sv takes; a side-set or set under a config changed mid-run is
// proved nowhere. Trusted: x, y, now, capture and crc where read (their other updates
// are left to the engine's tests); the fifos' head, empty and full (fifo_order.sv);
// data_word as the memory's word at data_ptr; and when the core issues, and that these
// registers move at no other time (phase_step.sv, edge_step.sv, constant config). Host,
// pins, clear and config are otherwise free every cycle, and the chip has no debugger. A
// count above 16 acts as 16, as in Pins.

// the timer's width, narrower in the narrow tasks
`ifndef TIMER_BITS
`define TIMER_BITS 24
`endif

module value_step (input clk);
  localparam T = `TIMER_BITS;
  // a mov's source, as wide as t or the data registers, whichever is wider
  localparam M = T > 16 ? T : 16;
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
  (* anyseq *) wire autopull_data, manchester;
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
  wire [8:0] pc, data_ptr;
  wire [15:0] x, y, p, t_fraction, osr, isr, rx_head, instruction, crc;
  wire [T-1:0] t, now, capture;
  wire [4:0] osr_count, isr_count, stall, stuff_run;
  wire halted, irq, underflow, overflow, missed_deadline, decode, capture_armed;
  wire flip_pending, flip_bit;
  wire [3:0] tx_level, rx_level;
  wire decode_ok;
  wire [7:0] opcode_onehot;
  wire [27:0] wait_select;
  // the fifos' ports, and the cycles the core counts until a moved data pointer's word
  wire [15:0] tx_head, rx_push_value;
  wire tx_empty, tx_pop, rx_full, rx_push;
  wire [1:0] data_settling;

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
    .pin_out(pin_out), .pin_dir(pin_dir), .pc(pc), .data_ptr(data_ptr), .x(x), .y(y),
    .p(p), .t(t), .t_fraction(t_fraction), .osr(osr),
    .osr_count(osr_count), .isr(isr), .isr_count(isr_count), .now(now), .stall(stall),
    .halted(halted), .irq(irq), .fault$underflow(underflow), .fault$overflow(overflow),
    .fault$missed_deadline(missed_deadline), .fault$decode(decode), .capture(capture),
    .capture_armed(capture_armed), .tx_level(tx_level), .rx_level(rx_level),
    .rx_head(rx_head), .instruction(instruction), .crc(crc), .stuff_run(stuff_run),
    .decode_ok(decode_ok), .opcode_onehot(opcode_onehot), .wait_select(wait_select),
    .flip_pending(flip_pending), .flip_bit(flip_bit),
    .eng_tx_head(tx_head), .eng_tx_empty(tx_empty), .eng_tx_pop(tx_pop),
    .eng_rx_full(rx_full), .eng_rx_push(rx_push), .eng_rx_push_value(rx_push_value),
    .eng_data_settling(data_settling));

  // an issue, as the model's step has it: running, the delay run out, no start in flight
  reg started = 0;
  always @(posedge clk) started <= !clear && start;
  wire issue = !clear && !halted && stall == 0 && !started;

  // the ISA's decode table
  function decodes(input [15:0] w);
    case (w[15:13])
      0: decodes = w[12:9] < 12;
      1: decodes = w[6:5] < 2 ? w[4:0] < 28 : w[4:0] == 0;
      2, 3: decodes = w[4:0] >= 1 && w[4:0] <= 16;
      4: decodes = w[4:3] < 3;
      5: decodes = w[7:5] < 5;
      6: decodes = w[5:4] < 3 && (!w[3] || w[2:0] < 5);
      default: decodes = w[7:4] == 0 && w[3:0] < 9;
    endcase
  endfunction
  wire go = issue && decodes(instruction);
  wire [2:0] opcode = instruction[15:13];
  wire [2:0] target = instruction[7:5];
  wire [4:0] n = instruction[4:0];
  wire [1:0] mov_op = instruction[4:3];
  wire [2:0] mov_source = instruction[2:0];
  wire [3:0] sys_op = instruction[3:0];
  wire ins = go && opcode == 2;
  wire outs = go && opcode == 3;
  wire movs = go && opcode == 4;
  wire syss = go && opcode == 7;

  // Pins: the low [n] bits on a run from [base] up, wrapping at 28
  function [15:0] mask(input [4:0] count);
    mask = count >= 16 ? 16'hffff : (16'd1 << count) - 16'd1;
  endfunction
  function [27:0] place(input [15:0] v, input [4:0] base);
    reg [55:0] twice;
    begin
      twice = {12'd0, v, 12'd0, v} << (base >= 28 ? base - 5'd28 : base);
      place = twice[55:28];
    end
  endfunction
  function [15:0] pick(input [27:0] v, input [4:0] base);
    reg [55:0] twice;
    begin
      twice = {v, v} >> (base >= 28 ? base - 5'd28 : base);
      pick = twice[15:0];
    end
  endfunction
  function [15:0] reverse16(input [15:0] v);
    integer i;
    for (i = 0; i < 16; i = i + 1) reverse16[i] = v[15 - i];
  endfunction
  function [T-1:0] reverse_t(input [T-1:0] v);
    integer i;
    for (i = 0; i < T; i = i + 1) reverse_t[i] = v[T - 1 - i];
  endfunction

  // a read of the pins; a wire sees what any core drives
  localparam [27:0] INPUTS = 28'h000001f;
  localparam [27:0] OUTS = 28'h0000fe0;
  localparam [27:0] BIDIRS = 28'h00ff000;
  localparam [27:0] WIRES = 28'hff00000;
  wire [27:0] level =
      (pin_out & (OUTS | (BIDIRS & pin_dir)))
    | (inputs & (INPUTS | (BIDIRS & ~pin_dir)))
    | ((pin_out | inputs) & WIRES);

  // out: the autopull first, then the shift; each teeth task gets one part of it wrong
`ifdef WRONG_DIRECTION
  wire out_right = !out_shift_right;
`else
  wire out_right = out_shift_right;
`endif
`ifdef ONE_SHORT
  wire [4:0] out_n = n - 5'd1;
`else
  wire [4:0] out_n = n;
`endif
`ifdef PULL_PAST_THRESHOLD
  wire pull_due = autopull && osr_count > pull_threshold;
`else
  wire pull_due = autopull && osr_count >= pull_threshold;
`endif
  // the data memory is time-sliced, so a pointer moved at the start pulse, a seek or a
  // data pull has no word for 3 cycles (the model's data_age below data_settle)
  reg [1:0] settling = 0;
`ifdef DATA_NEVER_REFUSED
  wire refused = 0;
`else
  wire refused = settling != 0;
`endif
  wire pull_misses = autopull_data ? refused : tx_empty;
  wire [15:0] osr_from = !pull_due || pull_misses ? osr : autopull_data ? data_word : tx_head;
  wire [4:0] count_from = pull_due ? 5'd0 : osr_count;
  wire [15:0] out_bits =
    out_right ? osr_from & mask(out_n) : (osr_from >> (16 - out_n)) & mask(out_n);
  wire [15:0] osr_shifted = out_right ? osr_from >> out_n : osr_from << out_n;
  wire [4:0] osr_count_shifted = count_from + out_n > 16 ? 5'd16 : count_from + out_n;

  // mov: the source zero-extended, then the op over the destination's width
  wire [M-1:0] mov_from =
      mov_source == 0 ? pick(level, in_base) & mask(in_count)
    : mov_source == 1 ? x
    : mov_source == 2 ? y
    : mov_source == 3 ? {M{1'b0}}
    : mov_source == 4 ? isr
    : mov_source == 5 ? osr
    : mov_source == 6 ? now
    : capture;
  wire [T-1:0] reversed_over_t = reverse_t(mov_from[T-1:0]);
  wire [15:0] reversed_over_data = reverse16(mov_from[15:0]);
  // assignment cuts or zero-extends to the other width
`ifdef REVERSE_WRONG_WIDTH
  wire [15:0] reversed = reversed_over_t;
  wire [T-1:0] reversed_t = reversed_over_data;
`else
  wire [15:0] reversed = reversed_over_data;
  wire [T-1:0] reversed_t = reversed_over_t;
`endif
`ifdef NO_INVERT
  wire [M-1:0] inverted = mov_from;
`else
  wire [M-1:0] inverted = ~mov_from;
`endif
  wire [15:0] mov_bits =
    mov_op == 0 ? mov_from[15:0] : mov_op == 1 ? inverted[15:0] : reversed;
  wire [T-1:0] mov_bits_t =
    mov_op == 0 ? mov_from[T-1:0] : mov_op == 1 ? inverted[T-1:0] : reversed_t;

  // in: the low n bits of the source into the isr, then the autopush
  wire [M-1:0] capture_wide = capture;
  wire [15:0] in_from =
      target == 0 ? pick(level, in_base)
    : target == 1 ? x
    : target == 2 ? y
    : target == 3 ? 16'd0
    : target == 4 ? isr
    : target == 5 ? osr
    : target == 6 ? crc
    : capture_wide[15:0];
  wire [15:0] in_bits = in_from & mask(n);
`ifdef IN_WRONG_DIRECTION
  wire in_right = !in_shift_right;
`else
  wire in_right = in_shift_right;
`endif
  wire [15:0] isr_shifted = in_right ? (isr >> n) | (in_bits << (16 - n)) : (isr << n) | in_bits;
  wire [4:0] isr_count_shifted = isr_count + n > 16 ? 5'd16 : isr_count + n;
`ifdef PUSH_BEFORE_SHIFT
  wire push_due = autopush && isr_count >= push_threshold;
`else
  wire push_due = autopush && isr_count_shifted >= push_threshold;
`endif

  wire pulls = syss && sys_op == 4;
  wire pushes = ins && push_due || syss && sys_op == 3;
  wire seeks = syss && sys_op == 8;
  wire data_pull = outs && pull_due && autopull_data && !refused;
  wire fifo_pull = outs && pull_due && !autopull_data && !tx_empty || pulls && !tx_empty;
  wire misses_pull = outs && pull_due && pull_misses || pulls && tx_empty;
  wire misses_push = pushes && rx_full;
  wire [15:0] push_word = ins ? isr_shifted : isr;
  always @(posedge clk)
    settling <= clear ? 2'd0 : start || seeks || data_pull ? 2'd3
      : settling == 0 ? 2'd0 : settling - 2'd1;

  // the ISA's next value of each register, from this cycle
  wire [15:0] want_osr =
      outs ? osr_shifted
    : movs && target == 5 ? mov_bits
    : pulls && !tx_empty ? tx_head
    : osr;
  wire [4:0] want_osr_count =
    outs ? osr_count_shifted : movs && target == 5 || pulls ? 5'd0 : osr_count;
  wire [15:0] want_isr =
      ins ? (push_due ? 16'd0 : isr_shifted)
    : outs && target == 5 ? out_bits
    : movs && target == 4 ? mov_bits
    : pushes ? 16'd0
    : isr;
  wire [4:0] want_isr_count =
      ins ? (push_due ? 5'd0 : isr_count_shifted)
    : outs && target == 5 ? n
    : movs && target == 4 || pushes ? 5'd0
    : isr_count;
  wire [8:0] want_data_ptr =
    start || started ? 9'd0 : seeks ? x[8:0] : data_pull ? data_ptr + 9'd1 : data_ptr;
  // x, y, p and t are the same codes as out and as mov destinations
  wire writes_x = (outs || movs) && target == 1;
  wire writes_y = (outs || movs) && target == 2;
  wire writes_p = (outs || movs) && target == 6;
  wire writes_t = (outs || movs) && target == 7;
  wire [15:0] value = outs ? out_bits : mov_bits;
  wire [T-1:0] t_value = outs ? out_bits : mov_bits_t;
  // Pins.write takes only pins that drive (5 and up) or turn around (12 to 19)
  localparam [27:0] OUTPUTS = 28'hfffffe0;
  wire manchester_bit = outs && target == 0 && manchester && n == 1;
  wire [27:0] run_out =
      manchester_bit ? place(16'd3, out_base) & OUTPUTS
    : outs && target == 0 ? place(mask(n), out_base) & OUTPUTS
    : movs && target == 0 ? place(mask(out_count), out_base) & OUTPUTS
    : 28'd0;
  wire [27:0] run_dir =
      outs && target == 4 ? place(mask(n), out_base) & BIDIRS
    : movs && target == 3 ? place(mask(out_count), out_base) & BIDIRS
    : 28'd0;
  wire [27:0] shown =
    place(manchester_bit ? {14'd0, out_bits[0], !out_bits[0]} : value, out_base);

  // a Manchester bit's second half, owed from the out to the next issue
  reg owed = 0, owed_bit = 0;
  reg [4:0] owed_base = 0;
  always @(posedge clk)
    if (clear || started) owed <= 0;
    else if (manchester_bit) begin
      owed <= 1;
      owed_bit <= out_bits[0];
      owed_base <= out_base;
    end else if (issue) owed <= 0;
  // the flip lands at the out_base of the issue that shows it, not of the out
`ifdef FLIP_AT_OUTS_BASE
  wire [4:0] flip_base = owed_base;
`else
  wire [4:0] flip_base = out_base;
`endif
`ifdef FLIP_SAME_HALF
  wire [15:0] second_half = {14'd0, owed_bit, !owed_bit};
`else
  wire [15:0] second_half = {14'd0, !owed_bit, owed_bit};
`endif
  // the flip yields to side-set (none on a jump or undecoded word), set and the run
  wire [27:0] side_run =
      go && opcode != 0 && !side_set_pindirs
    ? place(mask({3'd0, side_set_count}), side_set_base) : 28'd0;
  wire [27:0] set_run =
    go && opcode == 5 && target == 0 ? place(mask({2'd0, set_count}), set_base) : 28'd0;
  wire [27:0] flip_run =
      issue && owed
    ? place(16'd3, flip_base) & OUTPUTS & ~side_run & ~set_run & ~run_out : 28'd0;
  wire [27:0] flip_shown = place(second_half, flip_base);

  reg powered = 0;
  reg [15:0] last_want_osr, last_want_isr, last_value;
  reg [4:0] last_want_osr_count, last_want_isr_count;
  reg [8:0] last_want_data_ptr;
  reg last_want_underflow, last_want_overflow;
  reg last_writes_x, last_writes_y, last_writes_p, last_writes_t;
  reg [T-1:0] last_t_value, last_reversed_over_data;
  reg [27:0] last_run_out, last_run_dir, last_shown, last_flip_run, last_flip_shown;
  always @(posedge clk) begin
    powered <= 1;
    last_want_osr <= clear ? 16'd0 : want_osr;
    last_want_osr_count <= clear ? 5'd16 : want_osr_count;
    last_want_isr <= clear ? 16'd0 : want_isr;
    last_want_isr_count <= clear ? 5'd0 : want_isr_count;
    last_want_data_ptr <= clear ? 9'd0 : want_data_ptr;
    last_want_underflow <= !clear && (underflow || misses_pull);
    last_want_overflow <= !clear && (overflow || misses_push);
    last_writes_x <= writes_x;
    last_writes_y <= writes_y;
    last_writes_p <= writes_p;
    last_writes_t <= writes_t;
    last_value <= value;
    last_t_value <= t_value;
    last_reversed_over_data <= reversed_over_data;
    last_run_out <= run_out;
    last_run_dir <= run_dir;
    last_shown <= shown;
    last_flip_run <= clear ? 28'd0 : flip_run;
    last_flip_shown <= flip_shown;
  end

  // the lemma, from the cycle after power-on
  always @(posedge clk)
    if (powered) begin
      assert(osr == last_want_osr);
      assert(osr_count == last_want_osr_count);
      assert(isr == last_want_isr);
      assert(isr_count == last_want_isr_count);
      assert(data_ptr == last_want_data_ptr);
      assert(underflow == last_want_underflow);
      assert(overflow == last_want_overflow);
      assert((pin_out & last_run_out) == (last_shown & last_run_out));
      assert((pin_dir & last_run_dir) == (last_shown & last_run_dir));
      assert((pin_out & last_flip_run) == (last_flip_shown & last_flip_run));
      if (last_writes_x) assert(x == last_value);
      if (last_writes_y) assert(y == last_value);
      if (last_writes_p) assert(p == last_value);
      if (last_writes_t) assert(t == last_t_value && t_fraction == 0);
    end
  // and the fifos, in the cycle of the word
  always @(posedge clk)
    if (!clear) begin
      assert(tx_pop == fifo_pull);
      assert(rx_push == (pushes && !rx_full));
      if (rx_push) assert(rx_push_value == push_word);
    end

  // invariants for induction
  always @(posedge clk)
    if (powered) begin
      assert(decode_ok == decodes(instruction));
      assert(opcode_onehot == 8'b1 << opcode);
      assert(data_settling == settling);
      assert(flip_pending == owed);
      if (owed) assert(flip_bit == owed_bit);
      assert(osr_count <= 16 && isr_count <= 16);
    end

  // no part of the lemma is vacuous
  reg last_clear = 1, last_outs, last_movs, last_ins, last_pulls, last_pushes, last_push_due;
  reg last_manchester_bit, last_fifo_pull, last_data_pull, last_misses_pull, last_rx_push;
  reg last_out_shift_right, last_in_shift_right, last_autopull_data;
  reg [2:0] last_target, last_mov_source;
  reg [1:0] last_mov_op;
  reg [15:0] last_osr, last_isr;
  reg [27:0] last_pin_out, last_pin_dir;
  always @(posedge clk) begin
    last_clear <= clear;
    last_outs <= outs;
    last_movs <= movs;
    last_ins <= ins;
    last_pulls <= pulls;
    last_pushes <= pushes;
    last_push_due <= push_due;
    last_manchester_bit <= manchester_bit;
    last_fifo_pull <= fifo_pull;
    last_data_pull <= data_pull;
    last_misses_pull <= misses_pull;
    last_rx_push <= rx_push && !clear;
    last_out_shift_right <= out_shift_right;
    last_in_shift_right <= in_shift_right;
    last_autopull_data <= autopull_data;
    last_target <= target;
    last_mov_source <= mov_source;
    last_mov_op <= mov_op;
    last_osr <= osr;
    last_isr <= isr;
    last_pin_out <= pin_out;
    last_pin_dir <= pin_dir;
  end
  // a pin of the word's own run moved, not one its side-set or a Manchester flip moved
  wire moved_out = ((pin_out ^ last_pin_out) & last_run_out) != 0;
  wire moved_dir = ((pin_dir ^ last_pin_dir) & last_run_dir) != 0;
  wire out_pins = last_outs && last_target == 0 && !last_manchester_bit;
  wire out_dirs = last_outs && last_target == 4;
  always @(posedge clk)
    if (powered && !last_clear) begin
      // an out each way, to the pins and to pindirs, and a Manchester bit
      cover(last_out_shift_right && out_pins && moved_out);
      cover(!last_out_shift_right && out_pins && moved_out);
      cover(last_out_shift_right && out_dirs && moved_dir);
      cover(!last_out_shift_right && out_dirs && moved_dir);
      cover(last_manchester_bit && moved_out);
      // each way the out's autopull goes, from the fifo and from the data memory
      cover(last_outs && last_fifo_pull && out_pins && moved_out);
      cover(last_outs && last_data_pull && out_pins && moved_out);
      cover(last_outs && last_misses_pull && !last_autopull_data);
      cover(last_outs && last_misses_pull && last_autopull_data);
      // a mov to t reversed from a 16-bit source, where t's width shows
      cover(last_movs && last_target == 7 && last_mov_op == 2 && last_mov_source < 6
            && t != last_reversed_over_data);
      // a mov to pindirs, which reads the count from out_count
      cover(last_movs && last_target == 3 && moved_dir);
      // an in each way, the autopush, and push and pull on their own
      cover(last_in_shift_right && last_ins && !last_push_due && isr != last_isr);
      cover(!last_in_shift_right && last_ins && !last_push_due && isr != last_isr);
      cover(last_ins && last_push_due && last_rx_push);
      cover(last_pushes && !last_ins && last_rx_push);
      cover(last_pulls && last_fifo_pull && osr != last_osr);
    end
  // the second half at a jump, and at a word under an out_base other than the out's
  always @(posedge clk)
    if (issue && owed) begin
      cover(opcode == 0 && flip_run != 0);
      cover(out_base != owed_base && flip_run != 0);
    end
  // a mov of every source under every op, onto the pins
  genvar s, o;
  generate
    for (s = 0; s < 8; s = s + 1) begin : by_source
      for (o = 0; o < 3; o = o + 1) begin : by_op
        always @(posedge clk)
          if (powered && !last_clear)
            cover(last_movs && last_target == 0 && last_mov_source == s && last_mov_op == o
                  && moved_out);
      end
    end
  endgenerate
endmodule
