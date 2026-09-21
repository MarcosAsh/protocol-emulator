// The other half of P3: a fifo hands over the words it was given, in order, whenever
// they were pushed and popped. One pushed word is followed from the push to the head.
module fifo_order (input clk);
  (* anyconst *) wire [15:0] word;
  (* anyseq *) wire push_valid, pop, flush, follow;
  (* anyseq *) wire [15:0] push_value;

  reg clear = 1;
  always @(posedge clk) clear <= 0;

  wire [15:0] head;
  wire [3:0] level;
  wire empty, full;

  host_fifo dut (
    .clock(clk), .clear(clear), .push$valid(push_valid), .push$value(push_value),
    .pop(pop), .flush(flush), .head(head), .level(level), .empty(empty), .full(full));

  wire pushed = push_valid && !full && !flush;
  wire popped = pop && !empty;

  reg following = 0;
  reg [3:0] ahead = 0;
  always @(posedge clk)
    if (clear || flush) following <= 0;
    else if (!following && follow && pushed && push_value == word) begin
      following <= 1;
`ifdef STALE_AHEAD
      // the teeth task: forget a pop in the cycle of the push, and the proof must fail
      ahead <= level;
`else
      ahead <= level - popped;
`endif
    end else if (following && popped) begin
      if (ahead == 0) following <= 0;
      else ahead <= ahead - 1;
    end

  always @(posedge clk)
    if (!clear) begin
      assert(level <= 8);
      assert(empty == (level == 0));
      if (following) assert(!empty && ahead < level);
      if (following && ahead == 0) assert(head == word);
      if ($past(flush)) assert(empty);
    end

  always @(posedge clk) begin
    cover(following && ahead == 7);
    cover(following && ahead == 0 && popped && level == 8);
  end
endmodule
