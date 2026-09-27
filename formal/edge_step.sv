// Edge lemma, beside the step lemma in phase_step.sv and on its cycles: an entry is the
// first issue after a start or after a completion. For any program, pin_out and pin_dir
// change only in the cycle after an entry whose word writes them, and then to what it
// writes, in this order: the second half of a Manchester bit the word before left owed,
// side-set, then the word's own set, out or mov to pins or pindirs. So a word entered at
// phase q shows its edge at q + 1, and the pins hold it until the cycle after the next
// entry. A wait that holds issues again every cycle and drives the same side-set, which
// moves nothing. The second half of a Manchester bit shows the cycle after the next
// word's entry, whatever that word is, a jump, a wait or a word that fails to decode, and
// that entry comes one step of the out, its delay plus one, after the out's own, so the
// second half shows one step after the first. A start or a clear before then drops it; a
// stop holds it, and the core goes again only by a start, which drops it.
//
// Nothing is assumed of the host: stop, flush, start, program writes, the fifos and the
// data memory's word are free in every cycle, even while the core runs, and none moves a
// pin. The clear is free too, at power-on and in any cycle after, and zeroes both. For
// out and mov the data is the value the core shifts or moves in the issue cycle; which
// value that is belongs to the engine's tests, and here only when it shows.

module edge_step (input clk);
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
    .eng_mov_value(mov_value));
  // an instruction completes when a jump issues, or anything else issues and goes on
  wire completes = jmp_go || advance;

  // an entry is the first issue after a start or after a completion, as in phase_step.sv
  reg started = 0;
  always @(posedge clk) started <= start;
  wire issue = !clear && !halted && stall == 0 && !started;
  reg fresh = 0;
  always @(posedge clk)
    if (clear || start || completes) fresh <= 1;
    else if (issue) fresh <= 0;
  wire entry = issue && fresh;

  // the pin writers, by the word in the instruction register; a jump or a word that fails
  // to decode writes nothing of its own
  wire [2:0] opcode = instruction[15:13];
  wire [2:0] dest = instruction[7:5];
  wire [4:0] count = instruction[4:0];
  wire runs = decode_ok && opcode != 0;
  wire side_pins = runs && side_set_count != 0 && !side_set_pindirs;
  wire side_dirs = runs && side_set_count != 0 && side_set_pindirs;
  wire set_pins = runs && opcode == 5 && dest == 0;
  wire set_dirs = runs && opcode == 5 && dest == 3;
  wire out_pins = runs && opcode == 3 && dest == 0;
  wire out_dirs = runs && opcode == 3 && dest == 4;
  wire mov_pins = runs && opcode == 4 && dest == 0;
  wire mov_dirs = runs && opcode == 4 && dest == 3;
  wire manchester_bit = out_pins && manchester && count == 1;
  wire writes_out = side_pins || set_pins || out_pins || mov_pins;
  wire writes_dir = side_dirs || set_dirs || out_dirs || mov_dirs;

  // the second half of a Manchester bit is owed from the out's entry to the next entry
  reg flip_owed = 0;
  always @(posedge clk)
    if (clear || started) flip_owed <= 0;
    else if (entry) flip_owed <= manchester_bit;
  // and the cycles since that entry, beside the out's step, its delay plus one
  wire [4:0] ds = instruction[12:8];
  wire [4:0] delay = side_set_count == 0 ? ds : side_set_count == 1 ? ds[3:0] : ds[2:0];
  reg [5:0] since_out = 0, out_step = 0;
  always @(posedge clk)
    if (entry && manchester_bit) begin
      since_out <= 1;
      out_step <= delay + 6'd1;
    end else if (since_out != 63) since_out <= since_out + 6'd1;

  // Pins.write: the low [n] bits of [v] onto the pins from [base] up, around the 28 of
  // them, on the pins that take them: 5 and up drive, 12 to 19 turn around
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
  function [27:0] write
    (input [27:0] old, input [4:0] base, input [4:0] n, input [15:0] v, input [27:0] takes);
    reg [27:0] hit;
    begin
      hit = place(mask(n), base) & takes;
      write = old & ~hit | place(v, base) & hit;
    end
  endfunction

  wire [15:0] side_value =
    side_set_count == 1 ? {15'd0, instruction[12]} : {14'd0, instruction[12:11]};
  wire [15:0] set_value = {11'd0, count};
  // a Manchester out drives its bit on the pin above out_base and the complement on it
  wire [15:0] first_half = {14'd0, out_value[0], !out_value[0]};
  wire [27:0] pair = place(16'd3, out_base) & OUTPUTS;

  // what the pins hold the cycle after an entry, from what they hold at it
`ifdef NO_FLIP
  wire [27:0] flipped = pin_out;
`else
  wire [27:0] flipped = flip_owed ? pin_out ^ pair : pin_out;
`endif
  wire [27:0] sided_out =
      side_pins ? write(flipped, side_set_base, side_set_count, side_value, OUTPUTS)
    : flipped;
  wire [27:0] want_out =
      set_pins ? write(sided_out, set_base, set_count, set_value, OUTPUTS)
    : manchester_bit ? write(sided_out, out_base, 5'd2, first_half, OUTPUTS)
    : out_pins ? write(sided_out, out_base, count, out_value, OUTPUTS)
    : mov_pins ? write(sided_out, out_base, out_count, mov_value, OUTPUTS)
    : sided_out;
  wire [27:0] sided_dir =
      side_dirs ? write(pin_dir, side_set_base, side_set_count, side_value, BIDIRS)
    : pin_dir;
  wire [27:0] want_dir =
      set_dirs ? write(sided_dir, set_base, set_count, set_value, BIDIRS)
    : out_dirs ? write(sided_dir, out_base, count, out_value, BIDIRS)
    : mov_dirs ? write(sided_dir, out_base, out_count, mov_value, BIDIRS)
    : sided_dir;

  // the last cycle, for the check in this one
  reg last_clear = 1, last_entry = 0, last_flip_owed = 0;
  reg last_writes_out, last_writes_dir, last_side_pins, last_side_dirs;
  reg last_set_pins, last_set_dirs, last_out_pins, last_out_dirs;
  reg last_mov_pins, last_mov_dirs, last_manchester_bit;
  reg [27:0] last_out, last_dir, last_want_out, last_want_dir;
  always @(posedge clk) begin
    last_clear <= clear;
    last_entry <= entry;
    last_flip_owed <= flip_owed;
    last_writes_out <= writes_out;
    last_writes_dir <= writes_dir;
    last_side_pins <= side_pins;
    last_side_dirs <= side_dirs;
    last_set_pins <= set_pins;
    last_set_dirs <= set_dirs;
    last_out_pins <= out_pins;
    last_out_dirs <= out_dirs;
    last_mov_pins <= mov_pins;
    last_mov_dirs <= mov_dirs;
    last_manchester_bit <= manchester_bit;
    last_out <= pin_out;
    last_dir <= pin_dir;
    last_want_out <= want_out;
    last_want_dir <= want_dir;
  end

  // the entry whose writes the pins show in this cycle, by the claim; each teeth task
  // gets one part of it wrong
`ifdef ONE_CYCLE_LATER
  reg shown_entry = 0, shown_flip_owed = 0, shown_writes_out, shown_writes_dir;
  reg [27:0] shown_want_out, shown_want_dir;
  always @(posedge clk) begin
    shown_entry <= last_entry;
    shown_flip_owed <= last_flip_owed;
    shown_writes_out <= last_writes_out;
    shown_writes_dir <= last_writes_dir;
    shown_want_out <= last_want_out;
    shown_want_dir <= last_want_dir;
  end
`else
  wire shown_entry = last_entry, shown_flip_owed = last_flip_owed;
  wire shown_writes_out = last_writes_out, shown_writes_dir = last_writes_dir;
  wire [27:0] shown_want_out = last_want_out, shown_want_dir = last_want_dir;
`endif
`ifdef PINS_NEVER_CHANGE
  wire moves_out = 0;
  wire moves_dir = 0;
`elsif SIDE_SET_ONLY
  wire moves_out = shown_entry && last_side_pins;
  wire moves_dir = shown_entry && last_side_dirs;
`elsif NO_FLIP
  wire moves_out = shown_entry && shown_writes_out;
  wire moves_dir = shown_entry && shown_writes_dir;
`else
  wire moves_out = shown_entry && (shown_writes_out || shown_flip_owed);
  wire moves_dir = shown_entry && shown_writes_dir;
`endif

  // the lemma
  always @(posedge clk)
    if (!clear) begin
      if (last_clear) assert(pin_out == 0 && pin_dir == 0);
      else begin
        // when: only the cycle after an entry whose word writes them
        if (!moves_out) assert(pin_out == last_out);
        if (!moves_dir) assert(pin_dir == last_dir);
        // what: that word's writes, over the flip, side-set and the pins before
        if (shown_entry) assert(pin_out == shown_want_out && pin_dir == shown_want_dir);
      end
      // and the entry a second half is owed to comes one step of the out after the out's
      if (entry && flip_owed) assert(since_out == out_step);
    end
`ifdef FLIP_OFF_ISSUE
  // the second half by the clock instead, the cycle after the out's step ends, whether or
  // not the core issues then
  reg [5:0] last_since_out = 0, last_out_step = 0;
  always @(posedge clk) begin
    last_since_out <= since_out;
    last_out_step <= out_step;
  end
  always @(posedge clk)
    if (!clear && !last_clear && last_flip_owed && last_since_out == last_out_step
        && pair != 0 && !(last_entry && last_writes_out))
      assert((pin_out & pair) == ((last_out & pair) ^ pair));
`endif

  // What the core holds between entries, for induction: its decode flags agree with the
  // word, the flip owed is the one the core has pending, the pair shows the first half
  // and the out's stall counts down the rest of its step, and a wait that holds already
  // drives its side-set.
  wire [27:0] first_half_held = place({14'd0, flip_bit, !flip_bit}, out_base) & OUTPUTS;
  always @(posedge clk)
    if (!clear) begin
      assert(opcode_onehot == 8'b1 << opcode);
      assert(flip_pending == flip_owed);
      if (flip_owed) assert((pin_out & pair) == first_half_held);
      if (flip_owed && !halted)
        assert(since_out <= out_step && stall == out_step - since_out);
      if (!fresh && !halted) begin
        assert(opcode == 1 && decode_ok && stall == 0 && !started);
        if (side_pins) assert(sided_out == pin_out);
        if (side_dirs) assert(sided_dir == pin_dir);
      end
    end

  // each writer on its own moves a pin, so no part of the lemma is vacuous
  wire flipless = !last_flip_owed;
  wire moved_out = pin_out != last_out;
  wire moved_dir = pin_dir != last_dir;
  always @(posedge clk)
    if (!clear && !last_clear && last_entry) begin
      cover(last_set_pins && !last_side_pins && flipless && moved_out);
      cover(last_set_dirs && !last_side_dirs && moved_dir);
      cover(last_out_pins && !last_manchester_bit && !last_side_pins && flipless
            && moved_out);
      cover(last_manchester_bit && !last_side_pins && flipless && moved_out);
      cover(last_out_dirs && !last_side_dirs && moved_dir);
      cover(last_mov_pins && !last_side_pins && flipless && moved_out);
      cover(last_mov_dirs && !last_side_dirs && moved_dir);
      cover(last_side_pins && !last_set_pins && !last_out_pins && !last_mov_pins && flipless
            && moved_out);
      cover(last_side_dirs && !last_set_dirs && !last_out_dirs && !last_mov_dirs
            && moved_dir);
      // the second half, at the entry of a word that writes no pins
      cover(last_flip_owed && !last_writes_out && moved_out);
    end
  // the second half after an out with a delay
  always @(posedge clk) cover(entry && flip_owed && out_step >= 3);
  // and a wait that holds does issue again, driving its side-set
  always @(posedge clk) cover(issue && !entry && (side_pins || side_dirs));
endmodule
