// The start gate on the two-engine chip as it is built. From the clear on, for each
// engine n: (a) a start reaches the core only while n is certified; (b) n is certified
// only after a walk of n that began after the last program, configuration or line table
// write to n, held n free and saw no data write, the host's or the frame receiver's,
// throughout, and finished accepted; (c) a start never comes the cycle after the checker
// held n's ports; (d) the frame receiver writes only while n is free or does not pull data;
// (e) a walk of n checks under the setup it began with, and n's core, while certified,
// watches the premises of that setup; (f) a walk of n runs only in n's turn at the checker.
// Every host field is free every cycle, and so is each memory's output.

module gate (input clk);
  (* anyseq *) wire reset;
  (* anyseq *) wire [1:0] start, check, program_write, config_written, data_write;
  (* anyseq *) wire [1:0] line_write, autopull_data;
  (* anyseq *) wire setup_valid, setup_floor, setup_single_edge;
  (* anyseq *) wire [15:0] setup_value;
  // the premises of a check's setup: the loaded period, the floor and the single edge
  wire [18:0] setup = {setup_valid, setup_value, setup_floor, setup_single_edge};
  wire [18:0] walk_setup, premises_0, premises_1;
  wire [18:0] premises [0:1];
  assign premises[0] = premises_0;
  assign premises[1] = premises_1;
  reg clear = 1, cleared = 0;
  always @(posedge clk) begin
    clear <= reset;
    cleared <= 1;
  end

  wire certified_0, certified_1, go, chosen, checked, checking, accepts, lent_0, lent_1;
  wire turn_starts;
  wire started_0, started_1, free_0, free_1, frame_write;
  wire [1:0] certified = {certified_1, certified_0};
  wire [1:0] lent = {lent_1, lent_0};
  wire [1:0] started = {started_1, started_0};
  wire [1:0] free = {free_1, free_0};

  engines_top dut (
    .clock(clk), .clear(clear),
    .hosts$start_0(start[0]), .hosts$start_1(start[1]),
    .hosts$check_0(check[0]), .hosts$check_1(check[1]),
    .hosts$program_write$valid_0(program_write[0]),
    .hosts$program_write$valid_1(program_write[1]),
    .hosts$config_written_0(config_written[0]), .hosts$config_written_1(config_written[1]),
    .hosts$data_write$valid_0(data_write[0]), .hosts$data_write$valid_1(data_write[1]),
    .hosts$line_write$valid_0(line_write[0]), .hosts$line_write$valid_1(line_write[1]),
    .hosts$config$autopull_data_0(autopull_data[0]),
    .hosts$config$autopull_data_1(autopull_data[1]),
    .check_setup$loaded$valid(setup_valid), .check_setup$loaded$value(setup_value),
    .check_setup$floor(setup_floor), .check_setup$single_edge(setup_single_edge),
    .certified_0(certified_0), .certified_1(certified_1), .go(go), .chosen(chosen),
    .checked(checked), .checking(checking), .accepts(accepts), .turn_starts(turn_starts),
    .lent_0(lent_0), .lent_1(lent_1), .started_0(started_0), .started_1(started_1),
    .free_0(free_0), .free_1(free_1), .frame_write(frame_write),
    .walk_valid(walk_setup[18]), .walk_value(walk_setup[17:2]),
    .walk_floor(walk_setup[1]), .walk_single_edge(walk_setup[0]),
    .premises_valid_0(premises_0[18]), .premises_value_0(premises_0[17:2]),
    .premises_floor_0(premises_0[1]), .premises_single_edge_0(premises_0[0]),
    .premises_valid_1(premises_1[18]), .premises_value_1(premises_1[17:2]),
    .premises_floor_1(premises_1[1]), .premises_single_edge_1(premises_1[0]));

  // what each walk of n saw: begun after n's last write (fresh), with n free and no data
  // write while it ran (quiet), and whether it ended accepted with both (good)
  reg [1:0] fresh = 0, quiet = 0, good = 0, was_lent = 0;
  genvar n;
  generate
    for (n = 0; n < 2; n = n + 1) begin : engine
      wire begins = go && chosen == n;
      wire walking = checking && checked == n;
      reg [18:0] begun_with;
      always @(posedge clk) if (begins) begun_with <= setup;
      always @(posedge clk) begin
        was_lent[n] <= lent[n];
        if (clear) begin
          fresh[n] <= 0;
          quiet[n] <= 0;
          good[n] <= 0;
        end else begin
          if (begins) fresh[n] <= 1;
          else if (program_write[n] || config_written[n] || line_write[n]) fresh[n] <= 0;
          if (begins) quiet[n] <= 1;
          else if (walking && (!free[n] || |data_write || frame_write)) quiet[n] <= 0;
          if (begins || program_write[n] || config_written[n] || line_write[n])
            good[n] <= 0;
          else if (accepts && checked == n && fresh[n] && quiet[n]) good[n] <= 1;
        end
      end

      always @* if (cleared && !clear) begin
        if (started[n]) assert (certified[n]);
        if (certified[n]) assert (good[n]);
        if (started[n]) assert (!was_lent[n]);
        if (frame_write) assert (free[n] || !autopull_data[n]);
        if (walking) assert (walk_setup == begun_with);
        if (certified[n] || walking) assert (premises[n] == begun_with);
`ifndef NO_INVARIANT
        // a walk of n runs fresh and quiet, as a write or n leaving free ends it, and
        // holds n uncertified and not yet good; a good walk leaves n fresh
        if (walking) assert (fresh[n] && quiet[n] && !certified[n] && !good[n]);
        if (good[n]) assert (fresh[n] && quiet[n]);
`endif
      end
    end
  endgenerate

  always @* if (cleared && !clear) begin
    if (checking) assert (checked == chosen);
`ifndef NO_INVARIANT
    // a turn's last cycle aborts its walk, so each begins with the checker idle
    if (turn_starts) assert (!checking);
`endif
  end

  // a walk of each engine begins and borrows its ports, and a start is refused; an
  // accepted walk takes thousands of cycles, so certified starts are covered with the
  // walk ended at pc 1
  always @* if (cleared) begin
`ifdef SHORT_WALK
    cover (started[0]);
    cover (started[0] && checking && checked == 1);
`else
    cover (lent[0]);
    cover (lent[1]);
    cover (start[0] && !certified[0] && !started[0]);
`endif
  end
endmodule
