// Round trip: one 10BASE-T frame into frame_rx, may_write free. Any preamble length, any
// whole bytes, TP_IDL 250 to 400 ns, any sampling phase. Each half bit is PER_BIT / 2
// samples within DRIFT, chosen afresh, and each edge moves by up to JITTER on its own, both
// in 1/4096 samples. Each word lands at base + its index as sent; at finished the count,
// half and FCS verdict are right, two cycles after the line rests at the latest.

`ifndef PER_BIT
`define PER_BIT 8
`endif
`ifndef DRIFT
`define DRIFT 0
`endif
`ifndef JITTER
`define JITTER 0
`endif

// One sample of the sender: where the next boundary falls, what the line shows.
module sender_sample #(parameter W = 24) (
  input [2:0] state, input half, input bit_now, input [5:0] left, input [2:0] in_byte,
  input [3:0] tail, input signed [W-1:0] until, input signed [W-1:0] jit,
  input signed [W-1:0] half_bit, input [3:0] idle_halves,
  input signed [W-1:0] jit_next, input raw, input stop,
  output reg [2:0] state_out, output reg half_out, output reg bit_out,
  output reg [5:0] left_out, output reg [2:0] in_byte_out, output reg [3:0] tail_out,
  output reg signed [W-1:0] until_out, output reg signed [W-1:0] jit_out,
  output reg level, output reg boundary, output reg centre, output reg data_centre,
  output reg sfd_centre, output reg signed [W-1:0] centre_at);
  localparam GAP = 3'd0, PREAMBLE = 3'd1, DATA = 3'd2, IDLE = 3'd3, DONE = 3'd4;
  localparam signed [W-1:0] S = 4096;
  always @(*) begin
    state_out = state;
    half_out = half;
    bit_out = bit_now;
    left_out = left;
    in_byte_out = in_byte;
    tail_out = tail;
    until_out = until;
    jit_out = jit;
    boundary = state != DONE && until + jit <= 0;
    centre = 0;
    data_centre = 0;
    sfd_centre = 0;
    // the nominal centre, before this sample by this much
    centre_at = -until;
    if (boundary) begin
      until_out = until + half_bit;
      jit_out = jit_next;
      case (state)
        GAP: begin
          // the preamble's first bit is a 1, its first half low like the line at rest
          state_out = PREAMBLE;
          half_out = 0;
          bit_out = 1;
        end
        PREAMBLE, DATA:
          if (!half) begin
            half_out = 1;
            centre = 1;
            data_centre = state == DATA;
            sfd_centre = state == PREAMBLE && left == 0;
            if (state == DATA) in_byte_out = in_byte + 3'd1;
          end else if (state == PREAMBLE) begin
            half_out = 0;
            if (left == 0) begin
              state_out = DATA;
              in_byte_out = 0;
              bit_out = raw;
            end else begin
              left_out = left - 6'd1;
              // 1010...1011: the start of frame's last two bits are both 1
              bit_out = left == 1 ? 1'b1 : !bit_now;
            end
          end else if (in_byte == 0 && stop) begin
            state_out = IDLE;
            tail_out = 0;
          end else begin
            half_out = 0;
            bit_out = raw;
          end
        IDLE:
          if (tail + 4'd1 == idle_halves) state_out = DONE;
          else tail_out = tail + 4'd1;
        default: ;
      endcase
    end
    case (state_out)
      PREAMBLE, DATA: level = half_out ? bit_out : !bit_out;
      IDLE: level = 1;
      default: level = 0;
    endcase
    // at rest for good, the sender stops counting
    if (state_out != DONE) until_out = until_out - S;
  end
endmodule

module frame_roundtrip (input clk);
  localparam W = 24;
  localparam GAP = 3'd0, PREAMBLE = 3'd1, DATA = 3'd2, IDLE = 3'd3, DONE = 3'd4;
  localparam RX_IDLE = 2'd0, RX_HUNT = 2'd1, RX_FRAME = 2'd2;
  localparam signed [W-1:0] S = 4096;
  localparam signed [W-1:0] HALF = `PER_BIT * 2048;
  localparam [31:0] RESIDUE = 32'hdebb20e3;

  // each half bit's length, chosen as it starts
  (* anyseq *) wire signed [W-1:0] drift0, drift1;
  (* anyconst *) wire signed [W-1:0] start;
  (* anyconst *) wire [5:0] pairs;
  (* anyconst *) wire [3:0] idle_halves;
  (* anyconst *) wire [8:0] base;
  (* anyseq *) wire signed [W-1:0] jit0, jit1;
  (* anyseq *) wire raw0, raw1, stop0, stop1;
  (* anyseq *) wire may_write;

  always @(*) begin
    assume(drift0 >= -`DRIFT && drift0 <= `DRIFT);
    assume(drift1 >= -`DRIFT && drift1 <= `DRIFT);
    assume(jit0 >= -`JITTER && jit0 <= `JITTER);
    assume(jit1 >= -`JITTER && jit1 <= `JITTER);
    // 802.3 has 56 bits before the start of frame, a repeater may eat some
    assume(pairs <= 6'd28);
`ifdef SHORT_IDLE
    // a tooth: TP_IDL of 100 ns, which the receiver takes for a bit
    assume(idle_halves == 4'd2);
`else
    // TP_IDL, 250 to 400 ns
    assume(idle_halves >= 4'd5 && idle_halves <= 4'd8);
`endif
    // the first edge after the arm
    assume(start >= 0 && start <= 4 * HALF);
  end

  // cleared, then armed, then left alone
  reg [1:0] age = 0;
  always @(posedge clk) if (age != 3) age <= age + 2'd1;
  wire clear = age == 0;
  wire arm = age == 1;

  reg [2:0] state = GAP;
  reg half = 0;
  reg bit_now = 0;
  reg [5:0] left = 0;
  reg [2:0] in_byte = 0;
  reg [3:0] tail = 0;
  reg signed [W-1:0] until = 0;
  reg signed [W-1:0] jit = 0;
  reg level = 0;
  // from the last nominal centre to the last sample
  reg signed [W-1:0] since = 0;

  wire [2:0] state_a, state_b;
  wire half_a, half_b, bit_a, bit_b, level_a, level_b;
  wire [5:0] left_a, left_b;
  wire [2:0] in_byte_a, in_byte_b;
  wire [3:0] tail_a, tail_b;
  wire signed [W-1:0] until_a, until_b, jit_a, jit_b, at_a, at_b;
  wire boundary_a, boundary_b, centre_a, centre_b, data_a, data_b, sfd_a, sfd_b;
  // the preamble's count is taken in the gap
  wire [5:0] left_in = state == GAP ? pairs + pairs + 6'd7 : left;
  sender_sample #(W) a (
    .state(state), .half(half), .bit_now(bit_now), .left(left_in), .in_byte(in_byte),
    .tail(tail), .until(until), .jit(jit), .half_bit(HALF + drift0),
    .idle_halves(idle_halves),
    .jit_next(jit0), .raw(raw0), .stop(stop0),
    .state_out(state_a), .half_out(half_a), .bit_out(bit_a), .left_out(left_a),
    .in_byte_out(in_byte_a), .tail_out(tail_a), .until_out(until_a), .jit_out(jit_a),
    .level(level_a), .boundary(boundary_a), .centre(centre_a), .data_centre(data_a),
    .sfd_centre(sfd_a), .centre_at(at_a));
  sender_sample #(W) b (
    .state(state_a), .half(half_a), .bit_now(bit_a), .left(left_a), .in_byte(in_byte_a),
    .tail(tail_a), .until(until_a), .jit(jit_a), .half_bit(HALF + drift1),
    .idle_halves(idle_halves), .jit_next(jit1), .raw(raw1), .stop(stop1),
    .state_out(state_b), .half_out(half_b), .bit_out(bit_b), .left_out(left_b),
    .in_byte_out(in_byte_b), .tail_out(tail_b), .until_out(until_b), .jit_out(jit_b),
    .level(level_b), .boundary(boundary_b), .centre(centre_b), .data_centre(data_b),
    .sfd_centre(sfd_b), .centre_at(at_b));

  // a cycle's centre, at most one, and its bit
  wire centred = centre_a || centre_b;
  wire decided = data_a || data_b;
  wire decided_bit = data_a ? bit_a : bit_b;
  wire sfd_done = sfd_a || sfd_b;
  wire signed [W-1:0] since_next = centre_b ? at_b : centre_a ? at_a + S : since + 2 * S;
  // the half bits since the last centre, which since and until share out between them
  reg signed [W-1:0] ahead = 0;
  wire signed [W-1:0] ahead_next = boundary_a ? (centre_a ? 0 : ahead) + HALF + drift0
    : boundary_b ? (centre_b ? 0 : ahead) + HALF + drift1 : ahead;

  always @(posedge clk) begin
    if (clear) begin
      until <= start;
      jit <= 0;
    end else begin
      state <= state_b;
      half <= half_b;
      bit_now <= bit_b;
      left <= left_b;
      in_byte <= in_byte_b;
      tail <= tail_b;
      until <= until_b;
      jit <= jit_b;
      level <= level_b;
      if (state_b != DONE) ahead <= ahead_next;
      // past the frame it stops counting, well past the receiver's timeout
      if (since_next < 16 * HALF) since <= since_next;
    end
  end

  // The bits after the start of frame as the receiver keeps them: a word filling from the
  // top, and, a cycle later as the frame takes them, the CRC and the last two words.
  reg [15:0] word = 0;
  reg [3:0] word_bits = 0;
  reg taken = 0, taken_bit = 0, sfd_taken = 0;
  reg [31:0] crc = 0;
  reg [2:0] byte_bit = 0;
  reg good = 0;
  reg [15:0] last = 0, before = 0;
  reg [9:0] words = 0;
  reg odd = 0;
  wire [15:0] word_next = {decided_bit, word[15:1]};
  wire [31:0] crc_next = {1'b0, crc[31:1]} ^ (crc[0] ^ taken_bit ? 32'hedb88320 : 32'd0);
  always @(posedge clk) if (!clear) begin
    taken <= decided;
    taken_bit <= decided_bit;
    sfd_taken <= sfd_done;
    if (decided) begin
      word <= word_next;
      word_bits <= word_bits + 4'd1;
    end
    if (sfd_done) word_bits <= 0;
    if (sfd_taken) begin
      crc <= 32'hffffffff;
      byte_bit <= 0;
      good <= 0;
      words <= 0;
    end else if (taken) begin
      crc <= crc_next;
      byte_bit <= byte_bit + 3'd1;
      if (byte_bit == 7) good <= crc_next == RESIDUE;
      if (word_bits == 0) begin
        before <= last;
        last <= word;
        if (words != 10'h3ff) words <= words + 10'd1;
      end
    end
  end
  // the frame ended on a half word, whose byte the receiver writes once the carrier goes
  always @(posedge clk)
    if (!clear && state == DATA && state_b == IDLE) odd <= word_bits == 8;
  wire [15:0] half_word = {8'd0, word[15:8]};

  wire write_valid, ready;
  wire [8:0] write_addr;
  wire [15:0] write_data;
  wire [9:0] rx_words;
  wire finished, fcs_ok, rx_half, dropped, receiving, armed;
  wire [10:0] rx_count;
  wire [1:0] rx_sm;
  wire [7:0] rx_shift;
  wire [15:0] rx_word;
  wire [3:0] rx_word_bits;
  wire rx_last;
  wire [31:0] rx_crc;
  wire [2:0] rx_byte_bit;
  wire rx_good, pending, ended;
  wire [9:0] rx_index;

  frame_rx_top dut (
    .clock(clk), .clear(clear), .rd({level_b, level_a}),
    .control$arm(arm), .control$base(base), .control$fifty(`PER_BIT == 10),
    .may_write(may_write),
    .write$valid(write_valid), .write$addr(write_addr), .write$data(write_data),
    .ready(ready), .status$words(rx_words), .status$finished(finished),
    .status$fcs_ok(fcs_ok), .status$half(rx_half), .status$dropped(dropped),
    .status$receiving(receiving), .status$armed(armed),
    .rx_count(rx_count), .rx_sm(rx_sm), .rx_shift(rx_shift), .rx_word(rx_word),
    .rx_word_bits(rx_word_bits), .rx_last(rx_last), .rx_crc(rx_crc),
    .rx_byte_bit(rx_byte_bit), .rx_good(rx_good), .pending(pending), .ended(ended),
    .rx_index(rx_index));

  // the bits before the start of frame, as the receiver's hunt keeps them, and the frame's
  // start as the receiver takes it
  reg [7:0] heard = 0;
  reg started = 0;
  reg was_frame = 0;
  always @(posedge clk) was_frame <= rx_sm == RX_FRAME;
  always @(posedge clk) if (!clear) begin
    if (centred && state_b == PREAMBLE || sfd_done) heard <= {bit_b, heard[7:1]};
    if (sfd_taken) started <= 1;
  end
  // may_write comes once the line is at rest for good, so the last word lands
  reg [1:0] idle = 0;
  always @(posedge clk) if (state == DONE && idle != 3) idle <= idle + 2'd1;
  always @(*) if (state == DONE) assume(may_write);
`ifdef TEETH_PINNED
  // a tooth's frame from the line at rest as soon as may be, every word landing, on the
  // sampling grid, or for the jitter tooth half a sample off it, where jitter shows
  always @(*) assume(pairs == 0 && may_write);
`ifdef JITTER_TOOTH
  always @(*) assume(start == S / 2);
`else
  always @(*) assume(start == 0);
`endif
`endif

  // the words sent: every whole one, then the half
  wire [9:0] sent_words = words + (odd && state >= IDLE && words != 10'h3ff);
  wire [10:0] at = {2'd0, base} + {1'd0, sent_words} - 11'd1;
  wire [10:0] at_before = at - 11'd1;
  wire [15:0] newest = odd && state >= IDLE ? half_word : last;
  wire [15:0] older = odd && state >= IDLE ? last : before;

  always @(*) if (!clear) begin
    if (write_valid) begin
      assert((write_addr == at[8:0] && write_data == newest)
        || (write_addr == at_before[8:0] && write_data == older));
      assert(sent_words != 0);
    end
    if (finished) begin
      assert(rx_words == sent_words);
      assert(rx_half == odd);
      assert(fcs_ok == good);
    end
    if (idle >= 2) assert(finished);
  end

  // Lemmas, which make the above inductive. The receiver sees each edge in the sample the
  // sender makes it, so it takes each centre in the cycle the sender crosses it, and its
  // phase stays near the sender's last nominal centre.
  // the preamble's bits decided, 1010... from the first, latest at the top of heard
  wire [6:0] decided_count = {1'b0, pairs + pairs + 6'd7 - left} + half;
  wire [7:0] alternating = (decided_count[0] ? 8'haa : 8'h55)
    & (decided_count >= 8 ? 8'hff : ~(8'hff >> decided_count));
  wire signed [W-1:0] phase_error =
    $signed({{(W-11){rx_count[10]}}, rx_count}) * 128 - since;
  // {v
  //   at a centre, with x the error before it plus the drift's and q where the sample
  //   that sees the edge falls after the true centre, in [-JITTER, JITTER + S):
  //   phase_error' = x - 128 * floor((x + q) / 1024), about 7/8 x - q/8
  // v} so it stays in [-S - JITTER - 14 DRIFT, JITTER + 14 DRIFT + 1024], the last for the
  // floors
  wire locked = phase_error >= -S - `JITTER - 14 * `DRIFT - 128
    && phase_error <= `JITTER + 14 * `DRIFT + 1024 + 128;
  // past the first centre, before the receiver lets the frame go
  wire hearing = (state == PREAMBLE && (half || left != pairs + pairs + 6'd7))
    || state == DATA || (state >= IDLE && rx_sm == RX_FRAME);
`ifndef NO_LEMMAS
  always @(*) begin
    assert(clear == (age == 0));
    assert(state <= DONE);
    assert(jit >= -`JITTER && jit <= `JITTER);
    if (state == GAP) assert(!level && jit == 0 && until >= -S && until <= start);
    else assert(until >= -S - 2 * `JITTER && until <= HALF + `DRIFT + 2 * `JITTER);
    if (age <= 1) assert(state == GAP);
    if (state == PREAMBLE) begin
      assert(left <= pairs + pairs + 6'd7);
      assert(bit_now == (left[0] || left == 0));
      assert(level == (half ? bit_now : !bit_now));
    end
    if (state == DATA) assert(level == (half ? bit_now : !bit_now));
    if (state == IDLE) assert(level && tail < idle_halves);
    if (state == DONE) assert(!level);
    if (state <= PREAMBLE) assert(word_bits == 0 && !odd && words == 0);
    if (state <= PREAMBLE && !(half && left == 0)) assert(!started);
    if (state == DATA) assert(in_byte == word_bits[2:0] && started && !odd);
    if (state == PREAMBLE && !(half && left == 0))
      assert(!sfd_taken && heard == alternating);
    if (state >= IDLE) assert(word_bits[2:0] == 0 && odd == (word_bits == 8) && started);
  end

  always @(*) if (age >= 1) begin
    assert(rx_sm != 3);
    assert(rx_last == level);
    assert(rx_word == word && rx_word_bits == word_bits);
    assert(rx_crc == crc && rx_byte_bit == byte_bit && rx_good == good);
    if (hearing) assert(locked);
    // since and until run down together between boundaries
    if (hearing && state <= DATA || state == IDLE) assert(since + until == ahead - S);
    if (hearing && state <= DATA)
      assert(ahead >= (half ? 1 : 2) * (HALF - `DRIFT)
        && ahead <= (half ? 1 : 2) * (HALF + `DRIFT));
    if (state == IDLE)
      assert(ahead >= (4'd2 + tail) * (HALF - `DRIFT)
        && ahead <= (4'd2 + tail) * (HALF + `DRIFT));
    if (state == IDLE && tail >= 3) assert(rx_sm != RX_FRAME);
    if (state == GAP || (state == PREAMBLE && !half && left == pairs + pairs + 6'd7))
      assert(rx_sm == RX_IDLE && heard == 0);
    if (state == PREAMBLE && (half || left != pairs + pairs + 6'd7) && !(half && left == 0))
      assert(rx_sm == RX_HUNT && rx_shift == heard);
    if (state == PREAMBLE && half && left == 0) assert(rx_sm == RX_FRAME);
    if (state == DATA) assert(rx_sm == RX_FRAME);
    if (state == DONE) assert(rx_sm != RX_FRAME);
  end

  // the frame, as of the last bit taken
  always @(*) if (age >= 2) begin
    assert(receiving == (started && !ended));
    assert(armed == !ended);
    if (state <= DATA || rx_sm == RX_FRAME) assert(!ended);
    // the receiver says the carrier went the cycle after it lets the frame go
    if (state >= IDLE && rx_sm != RX_FRAME) assert(ended || was_frame);
    if (!started) assert(rx_words == 0 && !pending);
    if (!ended) assert(rx_words == words);
    if (ended) assert(rx_words == sent_words && rx_half == odd && fcs_ok == good);
    if (state == DONE) assert(ended || was_frame);
    if (state != DONE) assert(idle == 0);
    if (idle >= 1) assert(ended && !pending);
    if (pending) begin
      assert(rx_index + 10'd1 == rx_words || rx_index == 10'h3ff && rx_words == 10'h3ff);
      assert(write_data == (ended && odd ? half_word : last));
    end
  end
`endif

`ifdef PINNED
  // each cover from the line at rest as soon as may be
  always @(*) assume(start == 0 && pairs == 0 && idle_halves == 5);
`endif
  always @(*) if (!clear) begin
    // the shortest frame with a good FCS, its four bytes, and a lone byte judged bad
    cover(finished && fcs_ok && !dropped && rx_words == 2);
    cover(finished && !fcs_ok && rx_half && rx_words == 1);
  end
endmodule
