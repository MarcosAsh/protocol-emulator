// The frame lemma of frame_step.sv carried to the two-engine chip: the cores and the pins
// between them as Engines builds them. The chip's pin_out is the OR of what each engine
// holds where it drives, its pin_dir the OR of theirs, and each engine reads the pads but
// where the other drives a bidirectional pin, and on a wire what the other drives. For any
// two programs under any two configs whose footprints share no pad, from the clear on:
//
//   (a) on a pad in one engine's footprint the chip shows what that engine would alone:
//       on an output pad its pin_out, on a bidirectional pad its pin_dir as the output
//       enable and its pin_out where that is set. Outside both footprints the chip's
//       pin_out and pin_dir are 0.
//   (b) an engine reads what it would alone on every pin but where it hears the other: a
//       wire the other can move, and a bidirectional pad whose direction the other sets and
//       its own does not. Alone it reads its own level on an output, on a wire and on a
//       bidirectional pin whose direction it sets, and the pad elsewhere.
//   (c) where it hears the other, an engine reads what the other drives, on a wire together
//       with what it drives itself. This is how engines talk.
//
// All three rest on each engine keeping to its footprint, which is proved again here of the
// two in the chip, with frame_step.sv's footprint and its one assumption, that every word a
// core goes with writes no more than its program says. Only the first half of (a), what the
// chip shows on each engine's pads, needs the footprints apart on the pads as well; the
// pads_shared task drops that and proves the rest without it. The wires are not pads and
// two engines may both write one.
//
// The host's fields, the pads and the clear are free in every cycle; the data memory is the
// chip's, shared by time slice, which no claim here reads. Each config holds from one clear
// to the next, as in frame_step.sv.

module chip_frame (input clk);
  (* anyconst *) wire [1:0] side_set_count_0, side_set_count_1;
  (* anyconst *) wire [4:0] side_set_base_0, in_base_0, in_count_0, out_base_0, out_count_0, set_base_0;
  (* anyconst *) wire [4:0] side_set_base_1, in_base_1, in_count_1, out_base_1, out_count_1, set_base_1;
  (* anyconst *) wire [2:0] set_count_0, set_count_1;
  (* anyconst *) wire [4:0] jmp_pin_0, capture_pin_0, push_threshold_0, pull_threshold_0;
  (* anyconst *) wire [4:0] jmp_pin_1, capture_pin_1, push_threshold_1, pull_threshold_1;
  (* anyconst *) wire side_set_pindirs_0, capture_rising_0, in_shift_right_0, out_shift_right_0, autopush_0, autopull_0;
  (* anyconst *) wire side_set_pindirs_1, capture_rising_1, in_shift_right_1, out_shift_right_1, autopush_1, autopull_1;
  (* anyconst *) wire [4:0] crc_width_0, stuff_threshold_0, crc_width_1, stuff_threshold_1;
  (* anyconst *) wire [15:0] crc_poly_0, crc_init_0, crc_poly_1, crc_init_1;
  (* anyconst *) wire crc_reflect_0, stuff_level_0, crc_reflect_1, stuff_level_1;
  (* anyconst *) wire [8:0] wrap_bottom_0, wrap_top_0, wrap_bottom_1, wrap_top_1;
  (* anyconst *) wire [15:0] period_fraction_0, period_fraction_1;
  (* anyconst *) wire autopull_data_0, manchester_0, autopull_data_1, manchester_1;
  // each engine's host fields, bit n for engine n
  (* anyseq *) wire [1:0] start, stop, flush, rx_pop, clear_irq, tx_valid;
  (* anyseq *) wire [1:0] program_write_valid, data_write_valid;
  (* anyseq *) wire [8:0] program_write_addr_0, program_write_addr_1;
  (* anyseq *) wire [8:0] data_write_addr_0, data_write_addr_1;
  (* anyseq *) wire [15:0] program_write_data_0, program_write_data_1;
  (* anyseq *) wire [15:0] data_write_data_0, data_write_data_1, tx_value_0, tx_value_1;
  (* anyseq *) wire [19:0] pads;

  // the top clears both engines at power-on and whenever its reset comes again
  (* anyseq *) wire reset;
  reg clear = 1;
  always @(posedge clk) clear <= reset;

  wire [19:0] pin_out, pin_dir;
  wire [27:0] pin_out_0, pin_dir_0, pin_out_1, pin_dir_1, sample_0, sample_1;
  wire [15:0] instruction_0, instruction_1;
  wire [7:0] opcode_onehot_0, opcode_onehot_1;
  wire flip_pending_0, flip_pending_1, op_go_0, op_go_1;

  engines_top dut (
    .clock(clk), .clear(clear),
    .hosts$config$side_set_count_0(side_set_count_0), .hosts$config$side_set_base_0(side_set_base_0),
    .hosts$config$side_set_pindirs_0(side_set_pindirs_0), .hosts$config$in_base_0(in_base_0),
    .hosts$config$in_count_0(in_count_0), .hosts$config$out_base_0(out_base_0),
    .hosts$config$out_count_0(out_count_0), .hosts$config$set_base_0(set_base_0),
    .hosts$config$set_count_0(set_count_0), .hosts$config$jmp_pin_0(jmp_pin_0),
    .hosts$config$capture_pin_0(capture_pin_0), .hosts$config$capture_rising_0(capture_rising_0),
    .hosts$config$in_shift_right_0(in_shift_right_0),
    .hosts$config$out_shift_right_0(out_shift_right_0), .hosts$config$autopush_0(autopush_0),
    .hosts$config$push_threshold_0(push_threshold_0), .hosts$config$autopull_0(autopull_0),
    .hosts$config$pull_threshold_0(pull_threshold_0), .hosts$config$crc_width_0(crc_width_0),
    .hosts$config$crc_poly_0(crc_poly_0), .hosts$config$crc_init_0(crc_init_0),
    .hosts$config$crc_reflect_0(crc_reflect_0),
    .hosts$config$stuff_threshold_0(stuff_threshold_0),
    .hosts$config$stuff_level_0(stuff_level_0), .hosts$config$wrap_bottom_0(wrap_bottom_0),
    .hosts$config$wrap_top_0(wrap_top_0), .hosts$config$period_fraction_0(period_fraction_0),
    .hosts$config$autopull_data_0(autopull_data_0), .hosts$config$manchester_0(manchester_0),
    .hosts$start_0(start[0]), .hosts$program_write$valid_0(program_write_valid[0]),
    .hosts$program_write$addr_0(program_write_addr_0),
    .hosts$program_write$data_0(program_write_data_0),
    .hosts$data_write$valid_0(data_write_valid[0]), .hosts$data_write$addr_0(data_write_addr_0),
    .hosts$data_write$data_0(data_write_data_0),
    .hosts$tx$valid_0(tx_valid[0]), .hosts$tx$value_0(tx_value_0), .hosts$rx_pop_0(rx_pop[0]),
    .hosts$clear_irq_0(clear_irq[0]), .hosts$stop_0(stop[0]), .hosts$flush_0(flush[0]),
    .hosts$config$side_set_count_1(side_set_count_1), .hosts$config$side_set_base_1(side_set_base_1),
    .hosts$config$side_set_pindirs_1(side_set_pindirs_1), .hosts$config$in_base_1(in_base_1),
    .hosts$config$in_count_1(in_count_1), .hosts$config$out_base_1(out_base_1),
    .hosts$config$out_count_1(out_count_1), .hosts$config$set_base_1(set_base_1),
    .hosts$config$set_count_1(set_count_1), .hosts$config$jmp_pin_1(jmp_pin_1),
    .hosts$config$capture_pin_1(capture_pin_1), .hosts$config$capture_rising_1(capture_rising_1),
    .hosts$config$in_shift_right_1(in_shift_right_1),
    .hosts$config$out_shift_right_1(out_shift_right_1), .hosts$config$autopush_1(autopush_1),
    .hosts$config$push_threshold_1(push_threshold_1), .hosts$config$autopull_1(autopull_1),
    .hosts$config$pull_threshold_1(pull_threshold_1), .hosts$config$crc_width_1(crc_width_1),
    .hosts$config$crc_poly_1(crc_poly_1), .hosts$config$crc_init_1(crc_init_1),
    .hosts$config$crc_reflect_1(crc_reflect_1),
    .hosts$config$stuff_threshold_1(stuff_threshold_1),
    .hosts$config$stuff_level_1(stuff_level_1), .hosts$config$wrap_bottom_1(wrap_bottom_1),
    .hosts$config$wrap_top_1(wrap_top_1), .hosts$config$period_fraction_1(period_fraction_1),
    .hosts$config$autopull_data_1(autopull_data_1), .hosts$config$manchester_1(manchester_1),
    .hosts$start_1(start[1]), .hosts$program_write$valid_1(program_write_valid[1]),
    .hosts$program_write$addr_1(program_write_addr_1),
    .hosts$program_write$data_1(program_write_data_1),
    .hosts$data_write$valid_1(data_write_valid[1]), .hosts$data_write$addr_1(data_write_addr_1),
    .hosts$data_write$data_1(data_write_data_1),
    .hosts$tx$valid_1(tx_valid[1]), .hosts$tx$value_1(tx_value_1), .hosts$rx_pop_1(rx_pop[1]),
    .hosts$clear_irq_1(clear_irq[1]), .hosts$stop_1(stop[1]), .hosts$flush_1(flush[1]),
    .pads(pads),
    .engines$pin_out_0(pin_out_0), .engines$pin_dir_0(pin_dir_0),
    .engines$instruction_0(instruction_0), .engines$opcode_onehot_0(opcode_onehot_0),
    .engines$flip_pending_0(flip_pending_0),
    .engines$pin_out_1(pin_out_1), .engines$pin_dir_1(pin_dir_1),
    .engines$instruction_1(instruction_1), .engines$opcode_onehot_1(opcode_onehot_1),
    .engines$flip_pending_1(flip_pending_1),
    .pin_out(pin_out), .pin_dir(pin_dir),
    .op_go_0(op_go_0), .op_go_1(op_go_1), .sample_0(sample_0), .sample_1(sample_1));

  reg cleared = 0;
  always @(posedge clk) if (clear) cleared <= 1;

  wire [27:0] footprint_out_0, footprint_dir_0, footprint_out_1, footprint_dir_1;
  engine_frame frame_0 (
    .clk(clk), .cleared(cleared),
    .side_set_count(side_set_count_0), .side_set_base(side_set_base_0),
    .side_set_pindirs(side_set_pindirs_0), .set_base(set_base_0), .set_count(set_count_0),
    .out_base(out_base_0), .out_count(out_count_0), .manchester(manchester_0),
    .op_go(op_go_0), .instruction(instruction_0), .opcode_onehot(opcode_onehot_0),
    .flip_pending(flip_pending_0), .pin_out(pin_out_0), .pin_dir(pin_dir_0),
    .footprint_out(footprint_out_0), .footprint_dir(footprint_dir_0));
  // the second tooth: engine 1's words write where its program does not say, so it can
  // drive a pin of engine 0's
`ifdef UNBOUND
  engine_frame #(.KEEPS_TO(0)) frame_1 (
`else
  engine_frame frame_1 (
`endif
    .clk(clk), .cleared(cleared),
    .side_set_count(side_set_count_1), .side_set_base(side_set_base_1),
    .side_set_pindirs(side_set_pindirs_1), .set_base(set_base_1), .set_count(set_count_1),
    .out_base(out_base_1), .out_count(out_count_1), .manchester(manchester_1),
    .op_go(op_go_1), .instruction(instruction_1), .opcode_onehot(opcode_onehot_1),
    .flip_pending(flip_pending_1), .pin_out(pin_out_1), .pin_dir(pin_dir_1),
    .footprint_out(footprint_out_1), .footprint_dir(footprint_dir_1));

  // the pins each engine can move, and the pads among them
  wire [27:0] moves_0 = footprint_out_0 | footprint_dir_0;
  wire [27:0] moves_1 = footprint_out_1 | footprint_dir_1;
  wire [19:0] pads_0 = moves_0[19:0];
  wire [19:0] pads_1 = moves_1[19:0];
  // the first tooth lets the footprints share a pad, and so does pads_shared, which leaves
  // out the half of (a) that needs them apart
`ifndef OVERLAP
  always @(*) assume ((pads_0 & pads_1) == 0);
`endif

  // A pad as the chip's top drives it: an output pad always, a bidirectional pad where
  // pin_dir is set, and the level where it drives. A lone engine's top is the same with
  // its own pin_out and pin_dir.
  localparam [19:0] OUTPUT_PADS = 20'h00fe0;
  localparam [19:0] BIDIR_PADS = 20'hff000;
  wire [19:0] oe = OUTPUT_PADS | (pin_dir & BIDIR_PADS);
  wire [19:0] level = pin_out & oe;
  wire [19:0] alone_oe_0 = OUTPUT_PADS | (pin_dir_0[19:0] & BIDIR_PADS);
  wire [19:0] alone_level_0 = pin_out_0[19:0] & alone_oe_0;
  wire [19:0] alone_oe_1 = OUTPUT_PADS | (pin_dir_1[19:0] & BIDIR_PADS);
  wire [19:0] alone_level_1 = pin_out_1[19:0] & alone_oe_1;

  // What an engine reads alone: its own level where it drives, which on an output and on a
  // wire is always, since a lone engine finds nothing else on a wire, and on a
  // bidirectional pin is where its direction is set; the pad everywhere else.
  localparam [27:0] OWN = 28'hff00fe0;
  localparam [27:0] BIDIRS = 28'h00ff000;
  localparam [27:0] WIRES = 28'hff00000;
  wire [27:0] own_0 = OWN | (pin_dir_0 & BIDIRS);
  wire [27:0] own_1 = OWN | (pin_dir_1 & BIDIRS);
  wire [27:0] alone_sample_0 = (pin_out_0 & own_0) | ({8'd0, pads} & ~own_0);
  wire [27:0] alone_sample_1 = (pin_out_1 & own_1) | ({8'd0, pads} & ~own_1);
  // Where an engine hears the other, and what it hears there: the other's level, and on a
  // wire its own as well.
  wire [27:0] hears_0 = (WIRES & moves_1) | (pin_dir_1 & BIDIRS & ~pin_dir_0);
  wire [27:0] hears_1 = (WIRES & moves_0) | (pin_dir_0 & BIDIRS & ~pin_dir_1);
  wire [27:0] heard_0 = pin_out_1 | (pin_out_0 & WIRES);
  wire [27:0] heard_1 = pin_out_0 | (pin_out_1 & WIRES);
  // the third tooth has each engine read alone on every pin, the other's too
`ifdef READ_EVERYWHERE
  wire [27:0] apart_0 = 28'hfffffff;
  wire [27:0] apart_1 = 28'hfffffff;
`else
  wire [27:0] apart_0 = ~hears_0;
  wire [27:0] apart_1 = ~hears_1;
`endif

  // the second tooth keeps only engine 0's half of (a), which is where engine 1 driving a
  // pad of engine 0's has to show
  always @(posedge clk)
    if (cleared) begin
      // (a)
`ifndef PADS_SHARED
      assert (((oe ^ alone_oe_0) & pads_0) == 0);
      assert (((level ^ alone_level_0) & pads_0) == 0);
`endif
`ifndef UNBOUND
`ifndef PADS_SHARED
      assert (((oe ^ alone_oe_1) & pads_1) == 0);
      assert (((level ^ alone_level_1) & pads_1) == 0);
`endif
      assert ((pin_out & ~(footprint_out_0[19:0] | footprint_out_1[19:0])) == 0);
      assert ((pin_dir & ~(footprint_dir_0[19:0] | footprint_dir_1[19:0])) == 0);
      // (b)
      assert (((sample_0 ^ alone_sample_0) & apart_0) == 0);
      assert (((sample_1 ^ alone_sample_1) & apart_1) == 0);
      // (c)
      assert (((sample_0 ^ heard_0) & hears_0) == 0);
      assert (((sample_1 ^ heard_1) & hears_1) == 0);
`endif
    end

  // The covers: both engines move a pad of their own in one cycle; both drive a
  // bidirectional pad at once; an engine reads a pad of its own as the pad has it while
  // the other drives a bidirectional pad high; and one engine reads a wire the other
  // writes, which is (c).
  reg last_clear = 1, last_cleared = 0;
  reg [19:0] last_oe, last_level;
  always @(posedge clk) begin
    last_clear <= clear;
    last_cleared <= cleared;
    last_oe <= oe;
    last_level <= level;
  end
  // a step of the engines' own, not the clear's
  wire went = last_cleared && !last_clear && !clear;
  wire [19:0] moved = (oe ^ last_oe) | (level ^ last_level);
  always @(posedge clk)
    if (went) begin
      cover ((moved & pads_0) != 0 && (moved & pads_1) != 0);
      cover ((oe & BIDIR_PADS & pads_0) != 0 && (oe & BIDIR_PADS & pads_1) != 0);
      cover ((sample_0[19:0] & pads & pads_0 & BIDIR_PADS & ~pin_dir_0[19:0]) != 0
             && (level & BIDIR_PADS & pads_1) != 0);
      cover ((sample_0 & ~pin_out_0 & pin_out_1 & WIRES) != 0);
    end
endmodule

// One engine of the chip as frame_step.sv takes it: what its program writes, every word
// its core goes with keeping to that, and the footprint they make under its config, which
// it proves the engine's pins keep to, with frame_step.sv's two invariants for induction.
module engine_frame #(parameter KEEPS_TO = 1) (
  input clk, input cleared,
  input [1:0] side_set_count, input [4:0] side_set_base, input side_set_pindirs,
  input [4:0] set_base, input [2:0] set_count, input [4:0] out_base, input [4:0] out_count,
  input manchester,
  input op_go, input [15:0] instruction, input [7:0] opcode_onehot, input flip_pending,
  input [27:0] pin_out, input [27:0] pin_dir,
  output [27:0] footprint_out, output [27:0] footprint_dir);
  // what the program writes: its widest out to pins and to pindirs, 0 for none, and
  // whether it sets or moves to either
  (* anyconst *) wire [4:0] out_pins_width, out_dirs_width;
  (* anyconst *) wire sets_pins, sets_dirs, movs_pins, movs_dirs;

  // Pins.write, as in frame_step.sv: the low [n] bits of a word onto the pins from [base]
  // up, around the 28 of them, on the pins that take them
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
  function [27:0] window(input [4:0] base, input [4:0] n, input [27:0] takes);
    window = place(mask(n), base) & takes;
  endfunction

  wire [2:0] opcode = instruction[15:13];
  wire [2:0] dest = instruction[7:5];
  wire [4:0] count = instruction[4:0];
  wire set_pins = opcode == 5 && dest == 0;
  wire set_dirs = opcode == 5 && dest == 3;
  wire out_pins = opcode == 3 && dest == 0;
  wire out_dirs = opcode == 3 && dest == 4;
  wire mov_pins = opcode == 4 && dest == 0;
  wire mov_dirs = opcode == 4 && dest == 3;

  generate
    if (KEEPS_TO)
      always @(*)
        if (op_go) begin
          assume (!set_pins || sets_pins);
          assume (!set_dirs || sets_dirs);
          assume (!mov_pins || movs_pins);
          assume (!mov_dirs || movs_dirs);
          assume (!out_pins || (mask(count) & ~mask(out_pins_width)) == 0);
          assume (!out_dirs || (mask(count) & ~mask(out_dirs_width)) == 0);
        end
  endgenerate

  wire [4:0] side_width = side_set_count == 3 ? 5'd2 : side_set_count;
  wire [4:0] pair_width = manchester && out_pins_width == 1 ? 5'd2 : out_pins_width;
  wire side_on_out = side_set_count != 0 && !side_set_pindirs;
  wire side_on_dir = side_set_count != 0 && side_set_pindirs;
  assign footprint_out =
    (side_on_out ? window(side_set_base, side_width, OUTPUTS) : 0)
    | (sets_pins ? window(set_base, set_count, OUTPUTS) : 0)
    | window(out_base, pair_width, OUTPUTS)
    | (movs_pins ? window(out_base, out_count, OUTPUTS) : 0);
  assign footprint_dir =
    (side_on_dir ? window(side_set_base, side_width, BIDIRS) : 0)
    | (sets_dirs ? window(set_base, set_count, BIDIRS) : 0)
    | window(out_base, out_dirs_width, BIDIRS)
    | (movs_dirs ? window(out_base, out_count, BIDIRS) : 0);

  // every tooth drops these, so that only the chip's claims can fail
`ifndef TEETH
  always @(posedge clk)
    if (cleared) begin
      assert ((pin_out & ~footprint_out) == 0);
      assert ((pin_dir & ~footprint_dir) == 0);
      assert (opcode_onehot == 8'b1 << opcode);
      assert (!flip_pending || (manchester && out_pins_width != 0));
    end
`endif
endmodule
