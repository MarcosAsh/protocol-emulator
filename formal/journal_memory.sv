// The journal takes nothing from engine 0's reads of the data memory. Two data memories,
// one with the journal's port, whose writes are free, share halts, host writes, reads and
// clear; each memory is cut out. Proved: (a) the memories see the same commands but for
// journal writes, each in the top half while the other only reads; (b) engine 0's word is
// the same in both, once the journal has written provided engine 0 reads the low half.
// The engine_1 task: engine 1's word too, once it has read since the journal last wrote.
// Memory axiom: a read of an address both have written alike returns the same word.

module journal_memory (input clk);
  (* anyseq *) wire reset;
  (* anyseq *) wire [1:0] halted, write_valid;
  (* anyseq *) wire [8:0] write_addr_0, write_addr_1, reads_0, reads_1, journal_addr;
  (* anyseq *) wire [15:0] write_data_0, write_data_1, journal_data;
  (* anyseq *) wire journal_valid;
  (* anyseq *) wire [15:0] off_dout, on_dout;

  reg clear = 1;
  always @(posedge clk) clear <= reset;

  wire off_men, off_wen, off_ren, on_men, on_wen, on_ren;
  wire [8:0] off_addr, on_addr;
  wire [15:0] off_din, on_din, off_bm, on_bm;
  wire [15:0] off_word_0, off_word_1, on_word_0, on_word_1;
  wire slot;
  wire off_turn, on_turn, off_mine_0, on_mine_0, off_mine_1, on_mine_1;
  wire [15:0] off_last_0, on_last_0, off_last_1, on_last_1;

  dm_off off (
    .clock(clk), .clear(clear), .halted_0(halted[0]), .halted_1(halted[1]),
    .writes$valid_0(write_valid[0]), .writes$addr_0(write_addr_0), .writes$data_0(write_data_0),
    .writes$valid_1(write_valid[1]), .writes$addr_1(write_addr_1), .writes$data_1(write_data_1),
    .reads_0(reads_0), .reads_1(reads_1), .words_0(off_word_0), .words_1(off_word_1),
    .mem_men(off_men), .mem_wen(off_wen), .mem_ren(off_ren), .mem_addr(off_addr),
    .mem_din(off_din), .mem_bm(off_bm), .mem_dout(off_dout),
    .turn(off_turn), .mine_0(off_mine_0), .mine_1(off_mine_1), .last_0(off_last_0),
    .last_1(off_last_1));

  dm_on on (
    .clock(clk), .clear(clear), .halted_0(halted[0]), .halted_1(halted[1]),
    .writes$valid_0(write_valid[0]), .writes$addr_0(write_addr_0), .writes$data_0(write_data_0),
    .writes$valid_1(write_valid[1]), .writes$addr_1(write_addr_1), .writes$data_1(write_data_1),
    .reads_0(reads_0), .reads_1(reads_1), .words_0(on_word_0), .words_1(on_word_1),
    .journal$valid_0(journal_valid), .journal$addr_0(journal_addr),
    .journal$data_0(journal_data), .journal_slot_0(slot),
    .mem_men(on_men), .mem_wen(on_wen), .mem_ren(on_ren), .mem_addr(on_addr),
    .mem_din(on_din), .mem_bm(on_bm), .mem_dout(on_dout),
    .turn(on_turn), .mine_0(on_mine_0), .mine_1(on_mine_1), .last_0(on_last_0),
    .last_1(on_last_1));

  // the first cycle clears both; registers start anywhere before it
  reg started = 0;
  always @(posedge clk) if (clear) started <= 1;

  wire off_writes = off_men && off_wen;
  wire on_writes = on_men && on_wen;
  wire off_reads = off_men && off_ren && !off_wen;
  wire on_reads = on_men && on_ren && !on_wen;
  wire journal_writes = on_writes && !off_writes;

  // the journal has written the top half; memory keeps it through a clear
  reg dirty = 0;
  always @(posedge clk) if (journal_writes) dirty <= 1;

  // the axiom, for a read both made of an address both hold alike
  reg read_alike = 0;
  always @(posedge clk)
    read_alike <= off_reads && on_reads && off_addr == on_addr && (!off_addr[8] || !dirty);
  always @(*) if (read_alike) assume(on_dout == off_dout);

`ifndef JOURNAL_HALF
  always @(*) if (dirty) assume(!reads_0[8]);
`endif
`ifdef ENGINE_1
  always @(*) if (dirty) assume(!reads_1[8]);
`endif

  // engine 1 has read since the journal last wrote; a host write can hold its old word
  reg fresh_1 = 0, wrote = 0;
  reg [1:0] since = 0;
  always @(posedge clk) begin
    wrote <= journal_writes;
    since <= journal_writes ? 0 : (since == 3 ? 3 : since + 1);
    if (journal_writes) fresh_1 <= 0;
    else if (on_turn && on_reads) fresh_1 <= 1;
  end

  always @(*) if (started) begin
    assert(off_turn == on_turn && off_mine_0 == on_mine_0);
    if (!wrote) assert(off_mine_1 == on_mine_1);
    assert(!(off_writes && !on_writes));
    if (!journal_writes)
      assert(off_men == on_men && off_ren == on_ren && off_wen == on_wen
        && off_addr == on_addr && off_din == on_din && off_bm == on_bm);
    else
      assert(on_addr[8] && off_reads && slot);
`ifdef ENGINE_1
    if (fresh_1 && on_mine_1) assert(read_alike);
    if (fresh_1 && !on_mine_1) assert(off_last_1 == on_last_1);
`ifdef STOLEN_TURN
    assert(off_word_1 == on_word_1);
`elsif TIMED_QUIET
    if (!journal_writes && since >= 2) assert(off_word_1 == on_word_1);
`else
    if (fresh_1) assert(off_word_1 == on_word_1);
`endif
`else
    assert(off_last_0 == on_last_0);
    assert(off_word_0 == on_word_0);
`endif
  end
endmodule
