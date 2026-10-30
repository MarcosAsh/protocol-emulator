// Line_stuff sends any bit stream as USB stuffs it: after six 1s on the wire a 0, and
// every other wire bit the stream's next, each once and in order, until after finish the
// drain ends with nothing owed. The stream is any run of up to N bits, N = 96 for SYNC,
// PID, eight data bytes and the CRC-16, which owes at most 13 bits of the 15 it can; the
// flag is usb_transmit's table, the wire's 1s since a 0. Each tooth must fail.

`ifndef N
`define N 96
`endif

module line_stuff_check (input clk);
  localparam N = `N;
  localparam RESET = 3'd0, PRE = 3'd1, DATA = 3'd2, FINISH = 3'd3, DRAIN = 3'd4, DONE = 3'd5;

  (* anyseq *) wire data;
  // where the data ends, and whether a finish comes first, as after an earlier packet
  (* anyseq *) wire stop;
  (* anyconst *) wire early;
  // the stream bit followed onto the wire
  (* anyconst *) wire [6:0] k;

  reg [2:0] phase = RESET;
  wire clear = phase == RESET;
  reg [6:0] n = 0;
  reg [6:0] j = 0;
  reg [2:0] ones = 0;
  reg [2:0] run = 0;
  reg [4:0] stuffs = 0;
  reg [5:0] drained = 0;
  reg followed = 0;

  wire stuffing = ones == 6;
  wire sent, owed, draining;
  wire [14:0] held;
  wire [3:0] count;
  wire step = phase == DATA || (phase == DRAIN && (stuffing || owed));
  wire finish = phase == FINISH || (phase == PRE && early);

  line_stuff_top dut (
    .clock(clk), .clear(clear), .start(1'b0), .enable(1'b1), .step(step),
    .stuffing(stuffing), .data(data), .finish(finish),
    .sent(sent), .owed(owed), .held(held), .count(count), .draining(draining));

  // the stream's own stuffing, for the covers
  wire [2:0] run_next = data ? run + 3'd1 : 3'd0;

  // the followed bit, this cycle if it is taken now
  wire taken_now = phase == DATA && n == k;
  wire want = taken_now ? data : followed;
  wire [6:0] paid = phase == DATA ? n + 7'd1 : n;

  always @(posedge clk) begin
    case (phase)
      RESET: phase <= PRE;
      PRE: phase <= DATA;
      DATA: begin
        n <= n + 7'd1;
        if (taken_now) followed <= data;
        run <= run_next == 6 ? 3'd0 : run_next;
        stuffs <= stuffs + (run_next == 6);
        if (stop || n + 7'd1 == N) phase <= FINISH;
      end
      FINISH: phase <= DRAIN;
      DRAIN: begin
        drained <= drained + 6'd1;
        if (!step) phase <= DONE;
      end
      default: ;
    endcase
    if (step) begin
      ones <= sent ? ones + 3'd1 : 3'd0;
      if (!stuffing) j <= j + 7'd1;
    end
  end

  always @(*) begin
    if (step && stuffing) assert(!sent);
    if (step && !stuffing) begin
      // no wire bit past the stream, and the followed one where it belongs
      assert(j < paid);
      if (j == k) assert(sent == want);
    end
    if (phase == DRAIN) assert(drained <= 31);
    if (phase == DONE) assert(j == n && !owed && count == 0);
  end

  always @(*) begin
    cover(phase == DONE && n == 96 && stuffs == 16);
    cover(phase == DONE && early && n == 12 && stuffs == 2);
  end
endmodule
