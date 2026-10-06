// The load checker's walk, for any program, configuration, setup and data memory: an
// accepted walk passed every pc's check, and where pc g falls through, the next row it
// checked g against is the row it held at g + 1. The program memory gives the same word
// at g each time, and the data memory holds still, as the gate keeps them through an
// accepted walk (gate.sv); an abort only ends a walk unaccepted, so none comes.

module certify (input clk);
  (* anyconst *) wire [1:0] side_set_count;
  (* anyconst *) wire [4:0] capture_pin;
  (* anyconst *) wire capture_rising;
  (* anyconst *) wire [8:0] wrap_bottom, wrap_top;
  (* anyconst *) wire [15:0] period_fraction;
  (* anyconst *) wire [8:0] base;
  (* anyconst *) wire loaded_valid, single_edge;
  (* anyconst *) wire [15:0] loaded_value;
  (* anyseq *) wire check;
  // the pc the claims are about, and its word
  (* anyconst *) wire [8:0] g;
  (* anyconst *) wire [15:0] word_g;
  (* anyseq *) wire [15:0] any_word;

  reg clear = 1;
  always @(posedge clk) clear <= 0;
`ifdef SHORT_WALK
  // the walk ended at pc 1, so only g up to 1 is walked
  always @* assume (g <= 9'd1);
`endif

  wire program_read_valid, data_read_valid, busy, finished, accepted;
  wire [8:0] program_read_value, data_read_value;
  wire [9:0] reject_pc;
  wire [4:0] reason;
  wire [3:0] sm;
  wire [1:0] purpose;
  wire [8:0] pc;
  wire next_fails, target_fails, falls_to_next;
  wire [23:0] row_phase_lo, other_phase_lo;
  wire [23:0] row_phase_hi, other_phase_hi;
  wire [23:0] row_slope, other_slope;
  wire [23:0] row_offset_lo, other_offset_lo;
  wire [23:0] row_offset_hi, other_offset_hi;
  wire [23:0] row_arm_lo, other_arm_lo;
  wire [23:0] row_arm_hi, other_arm_hi;
  wire [15:0] row_period_lo, other_period_lo;
  wire [15:0] row_period_hi, other_period_hi;
  wire [15:0] row_x_lo, other_x_lo;
  wire [15:0] row_x_hi, other_x_hi;
  wire [15:0] row_y_lo, other_y_lo;
  wire [15:0] row_y_hi, other_y_hi;
  wire row_captured, other_captured;
  wire row_awaiting, other_awaiting;
  wire [265:0] row = {row_phase_lo, row_phase_hi, row_slope, row_offset_lo,
    row_offset_hi, row_arm_lo, row_arm_hi, row_period_lo, row_period_hi, row_x_lo,
    row_x_hi, row_y_lo, row_y_hi, row_captured, row_awaiting};
  wire [265:0] other = {other_phase_lo, other_phase_hi, other_slope, other_offset_lo,
    other_offset_hi, other_arm_lo, other_arm_hi, other_period_lo, other_period_hi,
    other_x_lo, other_x_hi, other_y_lo, other_y_hi, other_captured, other_awaiting};

  // a word a cycle after its address, and a data word once its address has held
  reg [8:0] program_at, data_at;
  reg [15:0] data [0:511];
  always @(posedge clk) begin
    program_at <= program_read_value;
    data_at <= data_read_value;
  end
  wire [15:0] program_word = program_at == g ? word_g : any_word;
  wire [15:0] data_word = data[data_at];

  load_checker dut (
    .clock(clk), .clear(clear), .check(check), .abort(1'b0),
    .config$side_set_count(side_set_count), .config$capture_pin(capture_pin),
    .config$capture_rising(capture_rising), .config$wrap_bottom(wrap_bottom),
    .config$wrap_top(wrap_top), .config$period_fraction(period_fraction),
    .setup$base(base), .setup$loaded$valid(loaded_valid),
    .setup$loaded$value(loaded_value), .setup$single_edge(single_edge),
    .program_word(program_word), .data_word(data_word),
    .program_read$valid(program_read_valid), .program_read$value(program_read_value),
    .data_read$valid(data_read_valid), .data_read$value(data_read_value),
    .busy(busy), .finished(finished), .accepted(accepted), .reject_pc(reject_pc),
    .reason(reason),
    .sm(sm), .purpose(purpose), .pc(pc), .next_fails(next_fails),
    .target_fails(target_fails),
    .falls_to_next(falls_to_next),
    .row_phase_lo(row_phase_lo), .row_phase_hi(row_phase_hi), .row_slope(row_slope),
    .row_offset_lo(row_offset_lo), .row_offset_hi(row_offset_hi),
    .row_arm_lo(row_arm_lo), .row_arm_hi(row_arm_hi), .row_period_lo(row_period_lo),
    .row_period_hi(row_period_hi), .row_x_lo(row_x_lo), .row_x_hi(row_x_hi),
    .row_y_lo(row_y_lo), .row_y_hi(row_y_hi), .row_captured(row_captured),
    .row_awaiting(row_awaiting), .other_phase_lo(other_phase_lo),
    .other_phase_hi(other_phase_hi), .other_slope(other_slope),
    .other_offset_lo(other_offset_lo), .other_offset_hi(other_offset_hi),
    .other_arm_lo(other_arm_lo), .other_arm_hi(other_arm_hi),
    .other_period_lo(other_period_lo), .other_period_hi(other_period_hi),
    .other_x_lo(other_x_lo), .other_x_hi(other_x_hi), .other_y_lo(other_y_lo),
    .other_y_hi(other_y_hi), .other_captured(other_captured),
    .other_awaiting(other_awaiting));

  localparam IDLE = 0, SEARCH = 5, ENTRY = 6, FIELD = 7, CHECK_NEXT = 10, ADVANCE = 11,
    RELOAD = 12, FINISH = 13;
  localparam RELOADING = 3;
  // past g's check: advancing, reloading the row for g + 1, or finishing
  wire after_check = sm == ADVANCE || sm == RELOAD || sm == FINISH
    || purpose == RELOADING && (sm == ENTRY || sm == FIELD);
  wire begins = sm == IDLE && check;
  wire passes = sm == CHECK_NEXT && !next_fails && !target_fails;

  // whether this walk passed g, whether g fell through, and the next row it checked
  reg passed = 0, fell = 0;
  reg [265:0] next_of_g;
  always @(posedge clk)
    if (clear || begins) begin
      passed <= 0;
      fell <= 0;
    end else if (passes && pc == g) begin
      passed <= 1;
      fell <= falls_to_next;
      next_of_g <= other;
    end

  always @* if (!clear) begin
    if (finished && accepted) assert (passed);
    if (sm == CHECK_NEXT && pc == g + 9'd1 && g != 9'd511 && fell)
      assert (row == next_of_g);
`ifndef NO_INVARIANT
    if (sm == FINISH) assert (pc == 9'd511);
    // only a target's or a successor's lookup searches
    if (sm == SEARCH) assert (purpose != RELOADING);
    if (busy && pc > g) assert (passed);
    if (busy && (pc < g || pc == g && !after_check)) assert (!passed);
    if (after_check && pc == g) assert (passed);
    if (sm == IDLE && finished && accepted) assert (passed);
    if (passed && fell && sm == ADVANCE && pc == g) assert (other == next_of_g);
    if (passed && fell && busy && sm != FINISH && pc == g + 9'd1) assert (row == next_of_g);
    if (fell) assert (passed && g != 9'd511);
    // g's word stays in the walk until g + 1's comes, and a row that fell through is not
    // reloaded
    if (passed && busy && sm != FINISH && pc == g) assert (fell == falls_to_next);
    if (fell && pc == g)
      assert (sm != RELOAD && !(purpose == RELOADING && (sm == ENTRY || sm == FIELD)));
`endif
  end

  always @* if (!clear) begin
`ifdef SHORT_WALK
    cover (finished && accepted && g == 9'd1);
`endif
    cover (passes && pc == g && falls_to_next);
    cover (sm == CHECK_NEXT && pc == g + 9'd1 && fell);
  end
endmodule
