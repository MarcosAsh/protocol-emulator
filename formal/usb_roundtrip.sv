// Round trip: a host sends one packet, any PID byte, from any sampling phase at exactly
// 8 samples a bit, into usb_frame_rx with may_write free: data of up to BYTES bytes with
// its CRC-16, a token with its CRC-5, or a handshake. Each word written is the bytes sent
// as the receiver packs them, at base + its index; at finished the counts, half, aligned
// and CRC are right. With SEVEN, any bits after SYNC with seven 1s end in stuff_error.

`ifndef BYTES
`define BYTES 8
`endif

module usb_roundtrip (input clk);
  localparam N = `BYTES;
  localparam M = 8 * N + 24;
  localparam DATA = 2'd0, TOKEN = 2'd1, HANDSHAKE = 2'd2;
  localparam [1:0] J = 2'b10, K = 2'b01, SE0 = 2'b00;
  localparam GAP = 3'd0, SYNC = 3'd1, MESSAGE = 3'd2, EOP = 3'd3, DONE = 3'd4;
  localparam IDLE = 2'd0, HUNT = 2'd1, PACKET = 2'd2;

  (* anyconst *) wire [1:0] kind;
  (* anyconst *) wire [7:0] pid;
  (* anyconst *) wire [7:0] len;
  (* anyconst *) wire [8*N-1:0] payload;
  (* anyconst *) wire [10:0] token;
  (* anyconst *) wire [2:0] offset;
  (* anyconst *) wire [1:0] gap;
  (* anyconst *) wire [8:0] base;
  (* anyseq *) wire may_write;
  // SEVEN: any bits after SYNC, unstuffed
  (* anyseq *) wire raw;

  always @(*) begin
    assume(kind != 3);
    assume(len <= N);
  end

`ifdef SHORT
  // a tooth's packet, short enough to fail fast
  always @(*) assume(gap == 0 && offset == 0 && len == 0);
`endif
`ifdef PINNED
  // each cover from the bus idle as soon as may be, DATA0 with all 1s to stuff the most,
  // so that the solver has only the kind and may_write to choose
  always @(*) begin
    assume(gap == 0 && offset == 0 && pid == 8'hc3);
    assume(payload == {8*N{1'b1}} && token == 11'h7ff);
`ifdef LONG
    assume(kind == DATA && len == N);
`else
    assume(len == 0);
`endif
  end
`endif

  // cleared, then armed, then left alone
  reg [1:0] age = 0;
  always @(posedge clk) if (age != 3) age <= age + 2'd1;
  wire clear = age == 0;
  wire arm = age == 1;

  // the message after SYNC, first bit lowest: PID, then the payload and its CRC-16 or the
  // address and endpoint and their CRC-5, each CRC complemented as USB sends it
  reg [15:0] crc16 = 16'hffff;
  reg [4:0] crc5 = 5'h1f;
`ifdef CRC_RAW
  wire [15:0] crc16_sent = crc16;
  wire [4:0] crc5_sent = crc5;
`else
  wire [15:0] crc16_sent = ~crc16;
  wire [4:0] crc5_sent = ~crc5;
`endif
  wire [9:0] covered = kind == DATA ? {len, 3'd0} : kind == TOKEN ? 10'd11 : 10'd0;
  wire [9:0] message_bits = 10'd8 + covered
    + (kind == DATA ? 10'd16 : kind == TOKEN ? 10'd5 : 10'd0);
  wire [7:0] bytes = message_bits[9:3];
  wire [8*N-1:0] shown = payload & ~({8*N{1'b1}} << covered);
  wire [M-1:0] message = kind == DATA
      ? {{M-8*N-8{1'b0}}, shown, pid} | ({{M-16{1'b0}}, crc16_sent} << (covered + 10'd8))
    : kind == TOKEN ? {{M-24{1'b0}}, crc5_sent, token, pid} : {{M-8{1'b0}}, pid};

  reg [2:0] state = GAP;
  reg [9:0] count = 0;
  reg [2:0] ones = 0;
  reg seven = 0;
  reg stuffed = 0;
  reg [1:0] line = J;
  reg [2:0] sub = 0;

  wire [M-1:0] message_at = message >> count;
`ifdef SEVEN
  // chosen a bit ahead, so it holds while on the wire
  reg raw_bit = 0;
  always @(posedge clk) if (sub == 3 || sub == 4) raw_bit <= raw;
  wire data_bit = raw_bit;
`else
  wire data_bit = message_at[0];
`endif
`ifdef NO_STUFF
  wire stuff = 0;
`else
  wire stuff = ones == 6;
`endif
  wire [1:0] toggled = line == J ? K : J;

  // the encoder after one more bit, and that bit's line state
  reg [1:0] next_line;
  reg [2:0] next_state;
  reg [9:0] next_count;
  reg [2:0] next_ones;
  reg [15:0] next_crc16;
  reg [4:0] next_crc5;
  always @(*) begin
    next_line = line;
    next_state = state;
    next_count = count + 10'd1;
    next_ones = ones;
    next_crc16 = crc16;
    next_crc5 = crc5;
    case (state)
      GAP: begin
        next_line = J;
        if (count == gap) begin
          next_state = SYNC;
          next_count = 0;
        end
      end
      SYNC: begin
        // KJKJKJKK: seven 0s and a 1, which starts the run
        next_line = count == 7 ? line : toggled;
        if (count == 7) begin
          next_state = MESSAGE;
          next_count = 0;
          next_ones = 1;
        end
      end
      MESSAGE:
        if (stuff) begin
          next_line = toggled;
          next_count = count;
          next_ones = 0;
        end else if (count < message_bits) begin
          next_line = data_bit ? line : toggled;
          next_ones = data_bit ? (ones == 7 ? ones : ones + 3'd1) : 3'd0;
          if (count >= 8 && count < 8 + covered) begin
            next_crc16 = {1'b0, crc16[15:1]} ^ (crc16[0] ^ data_bit ? 16'ha001 : 16'd0);
            next_crc5 = {1'b0, crc5[4:1]} ^ (crc5[0] ^ data_bit ? 5'h14 : 5'd0);
          end
        end else begin
          next_line = SE0;
          next_state = EOP;
          next_count = 1;
        end
      EOP: begin
        next_line = count == 1 ? SE0 : J;
        if (count == 2) next_state = DONE;
      end
      default: begin
        next_line = J;
        next_count = count;
      end
    endcase
  end

  // The bit on the wire is decided at its centre, sample 4 of 8; line and the state are
  // the encoder's as of the last bit decided. Two samples a cycle, sub the first's place.
  wire decide = sub == 3 || sub == 4;
  wire [1:0] first = sub <= 4 ? next_line : line;
  wire [1:0] second = sub == 5 || sub == 6 ? line : next_line;
  always @(posedge clk) begin
    sub <= clear ? offset : sub + 3'd2;
    if (!clear && decide) begin
      line <= next_line;
      state <= next_state;
      count <= next_count;
      ones <= next_ones;
      crc16 <= next_crc16;
      crc5 <= next_crc5;
      if (state == MESSAGE && !stuff && count < message_bits && ones == 6 && data_bit)
        seven <= 1;
      if (state == MESSAGE && stuff) stuffed <= 1;
    end
  end

  wire write_valid;
  wire [8:0] write_addr;
  wire [15:0] write_data;
  wire [9:0] words;
  wire finished, crc5_ok, crc16_ok, half, aligned, stuff_error, dropped, receiving, armed;
  // the receiver's state, which the lemmas below tie to the encoder's
  wire [2:0] rx_phase, rx_ones, pid_bits;
  wire [1:0] rx_sm, rx_zeros;
  wire [15:0] rx_word, frame_crc16;
  wire [3:0] rx_word_bits;
  wire [4:0] frame_crc5;
  wire rx_last_dp, rx_was_low, pending, ended, past_pid;

  usb_frame_rx_top dut (
    .clock(clk), .clear(clear),
    .dp({second[1], first[1]}), .dm({second[0], first[0]}),
    .control$arm(arm), .control$base(base), .may_write(may_write),
    .write$valid(write_valid), .write$addr(write_addr), .write$data(write_data),
    .status$words(words), .status$finished(finished), .status$crc5_ok(crc5_ok),
    .status$crc16_ok(crc16_ok), .status$half(half), .status$aligned(aligned),
    .status$stuff_error(stuff_error), .status$dropped(dropped),
    .status$receiving(receiving), .status$armed(armed),
    .rx_phase(rx_phase), .rx_last_dp(rx_last_dp), .rx_was_low(rx_was_low), .rx_sm(rx_sm),
    .rx_zeros(rx_zeros), .rx_ones(rx_ones), .rx_word(rx_word),
    .rx_word_bits(rx_word_bits), .pending(pending), .ended(ended), .pid_bits(pid_bits),
    .past_pid(past_pid), .frame_crc16(frame_crc16), .frame_crc5(frame_crc5));

  // the message two bytes to a word, as the receiver packs it; past its end, 0
  wire [9:0] expected_words = (message_bits + 10'd15) >> 4;
  wire [8:0] index = write_addr - base;
  wire [M+15:0] message_word = {16'd0, message} >> {index, 4'd0};
  wire [15:0] expected = message_word[15:0];

  reg [9:0] wrote = 0;
  always @(posedge clk) if (!clear && write_valid) wrote <= wrote + 10'd1;

  // may_write comes once the line is idle, so the last word lands
  reg [1:0] idle = 0;
  always @(posedge clk) if (state == DONE && idle != 3) idle <= idle + 2'd1;
  always @(*) if (state == DONE) assume(may_write);

  always @(*) if (!clear) begin
`ifndef SEVEN
    if (write_valid) begin
      assert(index < expected_words);
      assert(write_data == expected);
      assert(dropped || index == wrote);
    end
    assert(!stuff_error);
    if (finished) begin
      assert(words == expected_words);
      assert(half == bytes[0]);
      assert(aligned);
      assert(dropped || wrote == expected_words);
      if (kind == DATA) assert(crc16_ok);
      if (kind == TOKEN) assert(crc5_ok);
    end
    if (idle >= 2) assert(finished);
`else
    // seven 1s in a row: a stuffing error, never a good packet
    if (finished && seven) assert(stuff_error);
    if (idle >= 2 && seven) assert(finished && stuff_error);
`endif
  end

  // the CRC register after n of the bits sent from its frozen value r
  function [15:0] crc16_tail(input [15:0] r, input [15:0] sent, input [4:0] n);
    integer i;
    reg [15:0] c;
    begin
      c = r;
      for (i = 0; i < 16; i = i + 1)
        if (i < n) c = {1'b0, c[15:1]} ^ (c[0] ^ sent[i] ? 16'ha001 : 16'd0);
      crc16_tail = c;
    end
  endfunction
  function [4:0] crc5_tail(input [4:0] r, input [4:0] sent, input [2:0] n);
    integer i;
    reg [4:0] c;
    begin
      c = r;
      for (i = 0; i < 5; i = i + 1)
        if (i < n) c = {1'b0, c[4:1]} ^ (c[0] ^ sent[i] ? 5'h14 : 5'd0);
      crc5_tail = c;
    end
  endfunction

  wire taking = sub == 5 || sub == 6;
  wire heard = state > SYNC || (state == SYNC && (count != 0 || (sub >= 1 && sub <= 4)));
  wire [M+15:0] received = {message, 16'd0} >> count;
  wire [15:0] known = count >= 16 ? 16'hffff : ~(16'hffff >> count);
  wire [9:0] crc_bits = count - 10'd8 - covered;

  // Lemmas, which make the above inductive. The receiver keeps step with the encoder: it
  // decides each bit in the cycle the encoder does, and the frame takes the receiver's
  // outputs the cycle after, while sub is 5 or 6.
`ifndef NO_LEMMAS
  always @(*) begin
    assert(clear == (age == 0));
    assert(state <= DONE);
    if (age <= 1) assert(state == GAP && line == J);
    if (age == 0) assert(count == 0);
    if (state == GAP) assert(count <= gap && line == J);
    if (state == SYNC) assert(count <= 7 && line == (count[0] ? K : J));
    if (state == MESSAGE) assert(count <= message_bits && (line == J || line == K));
    if (state == EOP) assert((count == 1 || count == 2) && line == SE0);
    if (state == DONE) assert(line == J);
    if (state != DONE) assert(idle == 0);
    if (state < MESSAGE || (state == MESSAGE && count <= 8))
      assert(crc16 == 16'hffff && crc5 == 5'h1f);
`ifndef NO_STUFF
    assert(ones <= 6);
`endif
    if (!seven) assert(!(state == MESSAGE && ones == 7));
  end

  // the receiver
  always @(*) if (age >= 2) begin
    assert(rx_last_dp == (sub >= 1 && sub <= 4 ? next_line[1] : line[1]));
    assert(rx_was_low == !line[1]);
    if (heard) assert(rx_phase == sub - 3'd1);
    if (state == GAP || (state == SYNC && count == 0)) assert(rx_sm == IDLE);
    if (state == SYNC && count != 0)
      assert(rx_sm == HUNT && rx_zeros == (count >= 3 ? 2'd3 : count[1:0]));
    if (!seven) begin
      if (state == MESSAGE) assert(rx_sm == PACKET && rx_ones == ones);
      if (state >= EOP) assert(rx_sm == IDLE);
`ifndef SEVEN
      if (state == MESSAGE)
        assert(rx_word_bits == count[3:0] && ((rx_word ^ received[15:0]) & known) == 0);
`endif
    end
  end

  // the frame, as of the last bit decided
  always @(*) if (age >= 2 && !taking) begin
    assert(armed == (!seven && state <= MESSAGE));
    assert(receiving == (!seven && state == MESSAGE));
    assert(ended == (seven || state >= EOP));
    if (state < MESSAGE) assert(words == 0 && !pending && !dropped && wrote == 0);
    if (seven) assert(stuff_error);
`ifndef SEVEN
    if (state == MESSAGE) begin
      assert(pid_bits == count[2:0] && past_pid == count >= 8 && words == count >> 4);
      if (kind == DATA)
        assert(frame_crc16 == (count <= 8 + covered ? crc16
          : crc16_tail(crc16, crc16_sent, crc_bits)));
      if (kind == TOKEN)
        assert(frame_crc5 == (count <= 8 + covered ? crc5
          : crc5_tail(crc5, crc5_sent, crc_bits)));
    end
    if (state >= EOP) begin
      assert(words == expected_words && half == bytes[0] && aligned);
      if (kind == DATA) assert(crc16_ok);
      if (kind == TOKEN) assert(crc5_ok);
    end
`endif
  end

  // the word waiting for may_write
  always @(*) if (age >= 2) begin
`ifndef SEVEN
    if (pending) assert(index + 9'd1 == words && write_data == expected);
    if (!dropped) assert(wrote + pending == words);
`endif
    if (idle >= 1) assert(!pending);
  end
`endif

  always @(*) if (!clear) begin
`ifdef SEVEN
    cover(finished && seven && stuff_error);
`elsif LONG
    cover(finished && stuffed && !dropped && crc16_ok);
`else
    cover(finished && kind == DATA && len == 0 && crc16_ok);
    cover(finished && kind == TOKEN && crc5_ok);
    cover(finished && kind == HANDSHAKE);
    cover(finished && dropped);
`endif
  end
endmodule
