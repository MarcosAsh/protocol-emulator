// The fault fail-safe on the two-engine chip. From the clear on, an engine with a fault
// latched drives no pin, from the edge the fault shows; it halts within two edges and stays
// halted with its pc held, whatever its host does, until the next clear. With no fault the
// pins are the plain OR of both engines' drive. Host fields, pads and clear are free every
// cycle; each config holds between clears.

module fail_safe (input clk);
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
  wire [27:0] pin_out_0, pin_dir_0, pin_out_1, pin_dir_1;
  wire [8:0] pc_0, pc_1;
  wire halted_0, halted_1;
  wire underflow_0, overflow_0, missed_deadline_0, decode_0;
  wire underflow_1, overflow_1, missed_deadline_1, decode_1;
  wire any_fault_0, any_fault_1;

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
    // the load checker idle, which ungated engines.v leaves out of every start
    .hosts$check_0(1'b0), .hosts$config_written_0(1'b0),
    .hosts$check_1(1'b0), .hosts$config_written_1(1'b0),
    .check_setup$base(9'd0), .check_setup$loaded$valid(1'b0),
    .check_setup$loaded$value(16'd0), .check_setup$single_edge(1'b0),
    .pads(pads),
    .engines$pin_out_0(pin_out_0), .engines$pin_dir_0(pin_dir_0),
    .engines$pc_0(pc_0), .engines$halted_0(halted_0),
    .engines$fault$underflow_0(underflow_0), .engines$fault$overflow_0(overflow_0),
    .engines$fault$missed_deadline_0(missed_deadline_0), .engines$fault$decode_0(decode_0),
    .engines$faulted_0(any_fault_0),
    .engines$pin_out_1(pin_out_1), .engines$pin_dir_1(pin_dir_1),
    .engines$pc_1(pc_1), .engines$halted_1(halted_1),
    .engines$fault$underflow_1(underflow_1), .engines$fault$overflow_1(overflow_1),
    .engines$fault$missed_deadline_1(missed_deadline_1), .engines$fault$decode_1(decode_1),
    .engines$faulted_1(any_fault_1),
    .pin_out(pin_out), .pin_dir(pin_dir));

  reg cleared = 0;
  always @(posedge clk) if (clear) cleared <= 1;

  // the four sticky faults STATUS shows, and what each engine may still drive
  wire faulted_0 = underflow_0 | overflow_0 | missed_deadline_0 | decode_0;
  wire faulted_1 = underflow_1 | overflow_1 | missed_deadline_1 | decode_1;
  // tooth 1: the chip still shows a faulted engine 0's direction bits
`ifdef KEEP_DRIVE
  wire [27:0] live_dir_0 = pin_dir_0;
`else
  wire [27:0] live_dir_0 = faulted_0 ? 28'd0 : pin_dir_0;
`endif
  wire [27:0] live_out_0 = faulted_0 ? 28'd0 : pin_out_0;
  wire [27:0] live_dir_1 = faulted_1 ? 28'd0 : pin_dir_1;
  wire [27:0] live_out_1 = faulted_1 ? 28'd0 : pin_out_1;
  // pins 0-11, where the chip takes an engine's level without a direction bit
  localparam [27:0] OUTPUT_ONLY = 28'h0000fff;
  wire [27:0] combine_dir = live_dir_0 | live_dir_1;
  wire [27:0] combine_out = (live_out_0 & (live_dir_0 | OUTPUT_ONLY))
                          | (live_out_1 & (live_dir_1 | OUTPUT_ONLY));
  wire [27:0] raw_dir = pin_dir_0 | pin_dir_1;
  wire [27:0] raw_out = (pin_out_0 & (pin_dir_0 | OUTPUT_ONLY))
                      | (pin_out_1 & (pin_dir_1 | OUTPUT_ONLY));

  reg last_cleared = 0, last_clear = 1, last_faulted_0 = 0, last_faulted_1 = 0;
  reg last_halted_0 = 0, last_halted_1 = 0;
  reg [8:0] last_pc_0, last_pc_1;
  // the fault showed the last two cycles with no clear, so no start was taken since
  reg settled_0 = 0, settled_1 = 0;
  always @(posedge clk) begin
    last_cleared <= cleared;
    last_clear <= clear;
    last_faulted_0 <= faulted_0;
    last_faulted_1 <= faulted_1;
    last_halted_0 <= halted_0;
    last_halted_1 <= halted_1;
    last_pc_0 <= pc_0;
    last_pc_1 <= pc_1;
    settled_0 <= cleared && !clear && faulted_0 && last_faulted_0;
    settled_1 <= cleared && !clear && faulted_1 && last_faulted_1;
  end
  // the step from the last cycle to this one was the engines' own, not a clear's
  wire went = last_cleared && !last_clear;

  always @(posedge clk)
    if (cleared) begin
      // the flop the chip gates on is the OR of the four
      assert (any_fault_0 == faulted_0 && any_fault_1 == faulted_1);
      // F1, release: the chip shows only engines with no fault
      assert (pin_dir == combine_dir[19:0]);
      assert (pin_out == combine_out[19:0]);
      assert (!(faulted_0 && faulted_1) || (pin_dir == 0 && pin_out == 0));
      // F5, identity: with no fault the pins are what they always were
      assert (faulted_0 || faulted_1 || (pin_dir == raw_dir[19:0] && pin_out == raw_out[19:0]));
    end

  always @(posedge clk)
    if (went) begin
      // F4, sticky: only a clear takes a fault away
      assert (!last_faulted_0 || faulted_0);
      assert (!last_faulted_1 || faulted_1);
      // F2, halt: by the second edge after the fault shows (the first, unless the host
      // started the engine as its faulting word ran)
      assert (!settled_0 || halted_0);
      assert (!settled_1 || halted_1);
      // F3, frozen: from then on the pc holds and no start runs the engine
      assert (!(settled_0 && last_halted_0) || (halted_0 && pc_0 == last_pc_0));
      assert (!(settled_1 && last_halted_1) || (halted_1 && pc_1 == last_pc_1));
    end

  // tooth 2: engine 0 runs on two edges after a fault
  // tooth 3: a start while faulted takes engine 0 back to 0
  reg [1:0] last_start = 0, start_before = 0;
  always @(posedge clk) begin
    last_start <= start;
    start_before <= last_start;
  end
`ifdef RUNS_ON
  always @(posedge clk) if (settled_0) assert (!halted_0);
`endif
`ifdef RESTARTS
  always @(posedge clk) if (settled_0 && start_before[0]) assert (pc_0 == 0);
`endif

  always @(posedge clk)
    if (went && !clear) begin
      // a drive engine 0 had on a bidirectional pad, let go by its fault
      cover (faulted_0 && !last_faulted_0 && (pin_dir_0[19:12] & ~pin_dir_1[19:12]) != 0);
      // the same while engine 1 still drives a pad of its own
      cover (faulted_0 && !last_faulted_0 && (pin_dir_0[19:12] & ~pin_dir_1[19:12]) != 0
             && !faulted_1 && pin_dir[19:12] != 0);
      // a start after the fault, and engine 0 still halted
      cover (settled_0 && start_before[0] && halted_0 && pc_0 != 0);
    end
endmodule
