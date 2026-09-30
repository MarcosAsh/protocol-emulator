// P3: when the host talks to the core never reaches the pins. [step] is one core with
// its fifos and memories pulled out; two copies share configuration, pins, the fetched
// word, the data word and the pulled word, while what the fifos report is free in each.
// The script makes every register an input and an output, so this is one induction step
// from any state. Each teeth task in host_timing.sby removes one part, and must fail.
module step (
  input clock, clear, start, stop, clear_irq,
  input [174:0] config_bits,
  input [27:0] inputs,
  input [15:0] fetched, pulled, data_word,
  output [27:0] pin_out, pin_dir,
  output [8:0] sram_addr,
  output sram_men, sram_ren, sram_wen,
  output [8:0] data_addr,
  output data_men, data_ren, data_wen,
  output underflow, overflow, fifo_wait
);
  (* anyseq *) wire tx_full, tx_empty, rx_full, rx_empty;
  (* anyseq *) wire [3:0] tx_level, rx_level;
  (* anyseq *) wire [15:0] tx_idle_head, rx_head;
  // a flush is the host at a fifo, so each copy has its own
  (* anyseq *) wire flush;

  wire tx_pop;
`ifdef PRIVATE_PULL
  wire [15:0] tx_head = tx_idle_head;
`else
  wire [15:0] tx_head = tx_pop ? pulled : tx_idle_head;
`endif
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
    .config$crc_width(config_bits[66:61]), .config$crc_poly(config_bits[82:67]),
    .config$crc_init(config_bits[98:83]), .config$crc_reflect(config_bits[99]),
    .config$stuff_threshold(config_bits[104:100]), .config$stuff_level(config_bits[105]),
    .config$wrap_bottom(config_bits[114:106]), .config$wrap_top(config_bits[123:115]),
    .config$period_fraction(config_bits[139:124]), .config$autopull_data(config_bits[140]),
    .config$manchester(config_bits[141]), .config$crc_poly_high(config_bits[157:142]),
    .config$crc_init_high(config_bits[173:158]), .config$crc_complement(config_bits[174]),
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

  // trusted from issue_timing: the registered opcode and wait pin agree with the word
  always @(*) assume(opcode_onehot == 8'b1 << instruction[15:13]);
  always @(*) assume(wait_select == wait_pin);
  assign fifo_wait = 0
`ifndef NO_WAIT_EXCUSE
    || (instruction[15:13] == 1 && instruction[6:5] == 3)
`endif
`ifndef NO_JUMP_EXCUSE
    || (instruction[15:13] == 0 && instruction[12:9] >= 8)
`endif
    ;
endmodule

// From the same state the two copies agree on every register and output after the edge,
// unless one is about to fault or the word is a fifo wait or a jump on a fifo test.
module host_timing;
  wire trigger, fifo_wait;
  wire [1:0] underflow, overflow;
  step_miter pair (
    .trigger(trigger), .gold_fifo_wait(fifo_wait),
    .gold_underflow__d(underflow[0]), .gate_underflow__d(underflow[1]),
    .gold_overflow__d(overflow[0]), .gate_overflow__d(overflow[1]));
  always @(*) assert(!trigger || fifo_wait
`ifndef NO_UNDERFLOW_EXCUSE
    || underflow != 0
`endif
`ifndef NO_OVERFLOW_EXCUSE
    || overflow != 0
`endif
    );
endmodule
