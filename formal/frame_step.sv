// Frame lemma, beside edge_step.sv: from the clear on, a pin outside the engine's
// footprint never moves in pin_out or pin_dir, whatever the host and the pins do. The
// footprint is what the program's writers reach under the config, on the pins each write
// takes (5 and up drive, 12 to 19 turn around), wrapping at 28 as Pins.write does:
// side-set on every word but a jump (a count of 3 carries two bits, so its third pin only
// gets 0); set; out to the widest out the program has (an out writes its own count,
// whatever out_count is), two wide for a one-bit Manchester out; mov to out_count. The
// one assumption is that every word the core runs writes no more than the program says;
// outs 16 wide with every writer used assume nothing. The host, fifos, data word, inputs
// and clear are free every cycle, and the chip has no debugger. The config holds between
// clears: a new one without a clear leaves the last program's pins driven.

module frame_step (input clk);
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
  // what the program writes: its widest out to pins and pindirs (0 for none), and
  // whether it sets or moves to either
  (* anyconst *) wire [4:0] out_pins_width, out_dirs_width;
  (* anyconst *) wire sets_pins, sets_dirs, movs_pins, movs_dirs;
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
  wire op_go;

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
    .eng_op_go(op_go));

  // Pins.write, as in edge_step.sv
  localparam [27:0] OUTPUTS = 28'hfffffe0;
  localparam [27:0] BIDIRS = 28'h00ff000;
  function [27:0] place(input [15:0] v, input [4:0] base);
    reg [55:0] twice;
    begin
      twice = {12'd0, v, 12'd0, v} << (base >= 28 ? base - 5'd28 : base);
`ifdef NO_WRAP
      place = twice[27:0];
`else
      place = twice[55:28];
`endif
    end
  endfunction
  function [15:0] mask(input [4:0] n);
    mask = n >= 16 ? 16'hffff : (16'd1 << n) - 16'd1;
  endfunction
  function [27:0] window(input [4:0] base, input [4:0] n, input [27:0] takes);
    window = place(mask(n), base) & takes;
  endfunction

  // the word the core runs; op_go excludes jumps and undecoded words
  wire [2:0] opcode = instruction[15:13];
  wire [2:0] dest = instruction[7:5];
  wire [4:0] count = instruction[4:0];
  wire set_pins = opcode == 5 && dest == 0;
  wire set_dirs = opcode == 5 && dest == 3;
  wire out_pins = opcode == 3 && dest == 0;
  wire out_dirs = opcode == 3 && dest == 4;
  wire mov_pins = opcode == 4 && dest == 0;
  wire mov_dirs = opcode == 4 && dest == 3;

  // the one assumption: every word that runs writes no more than the program says
  always @(*)
    if (op_go) begin
      assume(!set_pins || sets_pins);
      assume(!set_dirs || sets_dirs);
      assume(!mov_pins || movs_pins);
      assume(!mov_dirs || movs_dirs);
      assume(!out_pins || (mask(count) & ~mask(out_pins_width)) == 0);
      assume(!out_dirs || (mask(count) & ~mask(out_dirs_width)) == 0);
    end

  // the windows; each teeth task takes one pin off one of them, or puts one elsewhere
  wire [4:0] side_reach = side_set_count == 3 ? 5'd2 : side_set_count;
`ifdef NARROW_SIDE
  wire [4:0] side_width = side_reach == 0 ? 5'd0 : side_reach - 5'd1;
`else
  wire [4:0] side_width = side_reach;
`endif
`ifdef NARROW_SET
  wire [4:0] set_width = set_count == 0 ? 5'd0 : set_count - 5'd1;
`else
  wire [4:0] set_width = set_count;
`endif
`ifdef NARROW_OUT
  wire [4:0] out_width = out_pins_width == 0 ? 5'd0 : out_pins_width - 5'd1;
  wire [4:0] out_dir_width = out_dirs_width == 0 ? 5'd0 : out_dirs_width - 5'd1;
`else
  wire [4:0] out_width = out_pins_width;
  wire [4:0] out_dir_width = out_dirs_width;
`endif
`ifdef NARROW_MOV
  wire [4:0] mov_width = out_count == 0 ? 5'd0 : out_count - 5'd1;
`else
  wire [4:0] mov_width = out_count;
`endif
`ifdef NO_PAIR
  wire [4:0] pair_width = out_width;
`else
  wire [4:0] pair_width = manchester && out_width == 1 ? 5'd2 : out_width;
`endif
`ifdef SIDE_DIRS_ON_OUT
  wire side_on_out = side_set_count != 0;
  wire side_on_dir = 0;
`else
  wire side_on_out = side_set_count != 0 && !side_set_pindirs;
  wire side_on_dir = side_set_count != 0 && side_set_pindirs;
`endif

  wire [27:0] side_out = side_on_out ? window(side_set_base, side_width, OUTPUTS) : 0;
  wire [27:0] side_dir = side_on_dir ? window(side_set_base, side_width, BIDIRS) : 0;
  wire [27:0] set_out = sets_pins ? window(set_base, set_width, OUTPUTS) : 0;
  wire [27:0] set_dir = sets_dirs ? window(set_base, set_width, BIDIRS) : 0;
  wire [27:0] out_out = window(out_base, pair_width, OUTPUTS);
  wire [27:0] out_dir = window(out_base, out_dir_width, BIDIRS);
  wire [27:0] mov_out = movs_pins ? window(out_base, mov_width, OUTPUTS) : 0;
  wire [27:0] mov_dir = movs_dirs ? window(out_base, mov_width, BIDIRS) : 0;
  wire [27:0] footprint_out = side_out | set_out | out_out | mov_out;
  wire [27:0] footprint_dir = side_dir | set_dir | out_dir | mov_dir;

  // the lemma, in every cycle after the first clear
  reg cleared = 0;
  always @(posedge clk) if (clear) cleared <= 1;
  always @(posedge clk)
    if (cleared) begin
      assert((pin_out & ~footprint_out) == 0);
      assert((pin_dir & ~footprint_dir) == 0);
      // for induction
      assert(opcode_onehot == 8'b1 << opcode);
      assert(!flip_pending || (manchester && out_pins_width != 0));
    end

  // covers: each writer moves a pin of its window while the pin just above, written but
  // outside the footprint, stays put; a one-bit out moves a Manchester pair's second pin
  function [27:0] pin_at(input [4:0] base, input [4:0] n);
    reg [5:0] k;
    begin
      k = (base >= 28 ? base - 5'd28 : base) + n;
      pin_at = 28'd1 << (k >= 28 ? k - 6'd28 : k);
    end
  endfunction
  function past(input [27:0] beside, input [27:0] takes, input [27:0] footprint);
    past = (beside & takes & ~footprint) != 0;
  endfunction
  reg last_clear = 1, last_cleared = 0, last_op_go = 0, last_flip_pending = 0;
  reg last_set_pins, last_set_dirs, last_out_pins, last_out_dirs, last_mov_pins, last_mov_dirs;
  reg [4:0] last_count;
  reg [27:0] last_out, last_dir;
  always @(posedge clk) begin
    last_clear <= clear;
    last_cleared <= cleared;
    last_op_go <= op_go;
    last_flip_pending <= flip_pending;
    last_set_pins <= set_pins;
    last_set_dirs <= set_dirs;
    last_out_pins <= out_pins;
    last_out_dirs <= out_dirs;
    last_mov_pins <= mov_pins;
    last_mov_dirs <= mov_dirs;
    last_count <= count;
    last_out <= pin_out;
    last_dir <= pin_dir;
  end
  // a step of the core's own, not the clear's, with no second half owed
  wire went = last_cleared && !last_clear && !clear && last_op_go && !last_flip_pending;
  wire [27:0] moved_out = pin_out ^ last_out;
  wire [27:0] moved_dir = pin_dir ^ last_dir;
  wire side_alone_out = !last_set_pins && !last_out_pins && !last_mov_pins;
  wire side_alone_dir = !last_set_dirs && !last_out_dirs && !last_mov_dirs;
  always @(posedge clk) begin
    cover(went && side_alone_out && (moved_out & side_out) != 0
          && past(pin_at(side_set_base, side_reach), OUTPUTS, footprint_out));
    cover(went && side_alone_dir && (moved_dir & side_dir) != 0
          && past(pin_at(side_set_base, side_reach), BIDIRS, footprint_dir));
    cover(went && last_set_pins && (moved_out & set_out & ~side_out) != 0
          && past(pin_at(set_base, set_count), OUTPUTS, footprint_out));
    cover(went && last_set_dirs && (moved_dir & set_dir & ~side_dir) != 0
          && past(pin_at(set_base, set_count), BIDIRS, footprint_dir));
    cover(went && last_out_pins && (moved_out & out_out & ~side_out) != 0
          && past(pin_at(out_base, last_count), OUTPUTS, footprint_out));
    cover(went && last_out_dirs && (moved_dir & out_dir & ~side_dir) != 0
          && past(pin_at(out_base, last_count), BIDIRS, footprint_dir));
    cover(went && last_mov_pins && (moved_out & mov_out & ~side_out) != 0
          && past(pin_at(out_base, out_count), OUTPUTS, footprint_out));
    cover(went && last_mov_dirs && (moved_dir & mov_dir & ~side_dir) != 0
          && past(pin_at(out_base, out_count), BIDIRS, footprint_dir));
    cover(went && last_out_pins && manchester && out_pins_width == 1
          && (moved_out & pin_at(out_base, 1) & OUTPUTS & ~side_out) != 0
          && past(pin_at(out_base, 2), OUTPUTS, footprint_out));
  end
endmodule
