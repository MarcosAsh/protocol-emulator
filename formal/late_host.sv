// A late message can make the core fault, never make it jitter.
//
// Theorem: for a program with no fifo wait and no jump on a fifo test, two runs of the
// core from the same start, whose host sends the same words at different times and reads
// the replies at different times, drive the same pins on every cycle until one of them
// sets its underflow or overflow fault.
//
// The proof is host_timing's step with that restriction on the program, so the only doors
// left open are the two faults. [late_step] is one core with its fifos and memories pulled
// out: what the fifos report is free in each copy, so the two see any levels, any arrival
// times. Every register becomes an input and an output and two copies are compared, so
// this is the step of an induction from any state; the base is the reset both runs share.
// The pops are compared as well: while neither faults, both copies pop in the same cycles,
// so the k-th pop of each is the k-th word the host sent, which fifo_order proves of the
// fifo. That is why the word a pull takes is one port shared by the two.
//
// For a program that never pushes, the only fault left is underflow (the never_pushes
// task): the host is late, the core finds the fifo empty at the cycle its certificate
// fixed for the pull, and says so.
//
// Prior art: the temporal firewall of Kopetz's time-triggered architecture, and the
// logical execution time of Giotto (Henzinger, Horowitz and Kirsch, 2001), where inputs are
// read and outputs written at fixed instants whatever the computation does in between.
// What is new here is that it is proved of the RTL.
//
// Each teeth task in late_host.sby takes one part of the statement away, and the proof must
// then fail.
module late_step (
  input clock, clear, start, stop, clear_irq,
  input [140:0] config_bits,
  input [27:0] inputs,
  input [15:0] fetched, pulled, data_word,
  output [27:0] pin_out, pin_dir,
  output [8:0] sram_addr,
  output sram_men, sram_ren, sram_wen,
  output [8:0] data_addr,
  output data_men, data_ren, data_wen,
  output pops,
  output underflow, overflow
);
  (* anyseq *) wire tx_full, tx_empty, rx_full, rx_empty;
  (* anyseq *) wire [3:0] tx_level, rx_level;
  (* anyseq *) wire [15:0] tx_idle_head, rx_head;
  (* anyseq *) wire flush;

`ifdef PRIVATE_PULL
  wire [15:0] tx_head = tx_idle_head;
`else
  wire [15:0] tx_head = tx_pop ? pulled : tx_idle_head;
`endif
  wire tx_pop;
  // a clear empties the fifo under the pop, so only a pop out of reset takes a word
  assign pops = tx_pop && !clear;
  wire [15:0] instruction;
  wire [7:0] opcode_onehot;
  wire [27:0] wait_select;
  wire [27:0] wait_pin = 28'd1 << instruction[4:0];

  engine_top dut (
    .clock(clock), .clear(clear),
    .config$side_set_count(config_bits[1:0]), .config$side_set_base(config_bits[6:2]),
    .config$side_set_pindirs(config_bits[7]), .config$in_base(config_bits[12:8]),
    .config$in_count(config_bits[17:13]), .config$out_base(config_bits[22:18]),
    .config$out_count(config_bits[27:23]), .config$set_base(config_bits[32:28]),
    .config$set_count(config_bits[35:33]), .config$jmp_pin(config_bits[40:36]),
    .config$capture_pin(config_bits[45:41]), .config$capture_rising(config_bits[46]),
    .config$in_shift_right(config_bits[47]), .config$out_shift_right(config_bits[48]),
    .config$autopush(config_bits[49]), .config$push_threshold(config_bits[54:50]),
    .config$autopull(config_bits[55]), .config$pull_threshold(config_bits[60:56]),
    .config$crc_width(config_bits[65:61]), .config$crc_poly(config_bits[81:66]),
    .config$crc_init(config_bits[97:82]), .config$crc_reflect(config_bits[98]),
    .config$stuff_threshold(config_bits[103:99]), .config$stuff_level(config_bits[104]),
    .config$wrap_bottom(config_bits[113:105]), .config$wrap_top(config_bits[122:114]),
    .config$period_fraction(config_bits[138:123]),
    .config$autopull_data(config_bits[139]), .config$manchester(config_bits[140]),
    .start(start), .program_write$valid(1'b0), .program_write$addr(9'b0),
    .program_write$data(16'b0), .tx$valid(1'b0), .tx$value(16'b0), .rx_pop(1'b0),
    .clear_irq(clear_irq), .stop(stop), .flush(flush), .inputs(inputs),
    .pin_out(pin_out), .pin_dir(pin_dir), .instruction(instruction), .opcode_onehot(opcode_onehot),
    .wait_select(wait_select),
    .fault$underflow(underflow), .fault$overflow(overflow),
    .sram_addr(sram_addr), .sram_men(sram_men), .sram_ren(sram_ren), .sram_wen(sram_wen),
    .sram_dout(fetched),
    .data_sram_addr(data_addr), .data_sram_men(data_men), .data_sram_ren(data_ren),
    .data_sram_wen(data_wen),
    .data_sram_dout(data_word), .data_write$valid(1'b0), .data_write$addr(9'b0),
    .data_write$data(16'b0),
    .tx_fifo_pop(tx_pop), .tx_fifo_head(tx_head),
    .tx_fifo_level(tx_level), .tx_fifo_empty(tx_empty), .tx_fifo_full(tx_full),
    .rx_fifo_head(rx_head), .rx_fifo_level(rx_level), .rx_fifo_empty(rx_empty),
    .rx_fifo_full(rx_full));

  // as in host_timing: issue_timing proves these registers agree with the instruction
  always @(*) assume(opcode_onehot == 8'b1 << instruction[15:13]);
  always @(*) assume(wait_select == wait_pin);

  // the program: every word the core can act on is one the time-triggered check admits,
  // no wait on a fifo and no jump on a fifo test
`ifndef ADMIT_FIFO_WAIT
  always @(*) assume(!(instruction[15:13] == 1 && instruction[6:5] == 3));
`endif
`ifndef ADMIT_FIFO_JUMP
  always @(*) assume(!(instruction[15:13] == 0 && instruction[12:9] >= 8));
`endif
  // the never_pushes task: no push and no autopush, so the host's reads reach nothing
`ifdef NEVER_PUSHES
  always @(*) assume(!config_bits[49] && !(instruction[15:13] == 7 && instruction[3:0] == 3));
`endif
endmodule

// From the same state, every register, every output and the pop of the two copies are the
// same after the clock edge, unless a copy is about to set underflow or overflow.
module late_host;
  wire trigger;
  wire [1:0] underflow, overflow;
  late_step_miter pair (
    .trigger(trigger),
    .gold_underflow__d(underflow[0]), .gate_underflow__d(underflow[1]),
    .gold_overflow__d(overflow[0]), .gate_overflow__d(overflow[1]));
  always @(*) assert(!trigger
`ifndef NO_UNDERFLOW_EXCUSE
    || underflow != 0
`endif
`ifndef NO_OVERFLOW_EXCUSE
    || overflow != 0
`endif
    );
endmodule
