// Fetch lemma: at every issue the core runs the word its program memory holds at pc, for
// any program and any config written while halted but not in a start's second cycle, with
// no program word written in a start's two cycles (both host_spacing.sv). That second
// cycle prefetches the word after pc 0 under the config of the time, so the teeth, a
// config or a word written then, break it (test_engine.ml shows the first). The memory is
// the flop stand-in for the SRAM macro (sram_equiv), followed at one free address. Stop,
// flush, start, fifos, data and the clear are free.

module fetch_step (input clk);
  // The config, as the host port holds it: a write lands only while the core is halted,
  // and not in a start's second cycle (host_spacing.sv). Free at the clear.
  (* anyseq *) wire config_write;
  (* anyseq *) wire [140:0] config_value;
  reg [140:0] config_bits;
  wire [1:0] side_set_count = config_bits[140:139];
  wire [4:0] side_set_base = config_bits[138:134];
  wire side_set_pindirs = config_bits[133];
  wire [4:0] in_base = config_bits[132:128], in_count = config_bits[127:123];
  wire [4:0] out_base = config_bits[122:118], out_count = config_bits[117:113];
  wire [4:0] set_base = config_bits[112:108];
  wire [2:0] set_count = config_bits[107:105];
  wire [4:0] jmp_pin = config_bits[104:100], capture_pin = config_bits[99:95];
  wire capture_rising = config_bits[94], in_shift_right = config_bits[93];
  wire out_shift_right = config_bits[92], autopush = config_bits[91];
  wire [4:0] push_threshold = config_bits[90:86];
  wire autopull = config_bits[85];
  wire [4:0] pull_threshold = config_bits[84:80], crc_width = config_bits[79:75];
  wire [15:0] crc_poly = config_bits[74:59], crc_init = config_bits[58:43];
  wire crc_reflect = config_bits[42];
  wire [4:0] stuff_threshold = config_bits[41:37];
  wire stuff_level = config_bits[36];
  wire [8:0] wrap_bottom = config_bits[35:27], wrap_top = config_bits[26:18];
  wire [15:0] period_fraction = config_bits[17:2];
  wire autopull_data = config_bits[1], manchester = config_bits[0];
  (* anyseq *) wire [15:0] data_word;
  (* anyseq *) wire stop, flush;
  (* anyseq *) wire start, program_write_valid, tx_valid, rx_pop, clear_irq;
  (* anyseq *) wire [8:0] program_write_addr;
  (* anyseq *) wire [15:0] program_write_data, tx_value;
  (* anyseq *) wire [27:0] inputs;

  (* anyseq *) wire reset;
  reg clear = 1;
  always @(posedge clk) clear <= reset;

  wire [27:0] pin_out, pin_dir, wait_select;
  wire [8:0] pc, fetch_addr, probe_addr;
  wire [15:0] x, y, p, osr, isr, rx_head, instruction, crc;
  wire [15:0] dout, probe_word;
  wire [23:0] t, now, capture;
  wire [4:0] osr_count, isr_count, stall, stuff_run;
  wire halted, irq, underflow, overflow, missed_deadline, decode, capture_armed;
  wire flip_pending, flip_bit, decode_ok, jmp_go, advance, refill;
  wire [3:0] tx_level, rx_level;
  wire [7:0] opcode_onehot;

  engine dut (
    .clock(clk), .clear(clear),
    .config$side_set_count(side_set_count), .config$side_set_base(side_set_base),
    .config$side_set_pindirs(side_set_pindirs), .config$in_base(in_base),
    .config$in_count(in_count), .config$out_base(out_base), .config$out_count(out_count),
    .config$set_base(set_base), .config$set_count(set_count), .config$jmp_pin(jmp_pin), .config$capture_pin(capture_pin),
    .config$capture_rising(capture_rising), .config$in_shift_right(in_shift_right),
    .config$out_shift_right(out_shift_right), .config$autopush(autopush),
    .config$push_threshold(push_threshold), .config$autopull(autopull),
    .config$pull_threshold(pull_threshold),
    .config$crc_width(crc_width), .config$crc_poly(crc_poly), .config$crc_init(crc_init),
    .config$crc_reflect(crc_reflect), .config$stuff_threshold(stuff_threshold),
    .config$stuff_level(stuff_level),
    .config$wrap_bottom(wrap_bottom), .config$wrap_top(wrap_top),
    .config$period_fraction(period_fraction),
    .config$autopull_data(autopull_data), .config$manchester(manchester),
    .stop(stop), .flush(flush),
    .start(start), .program_write$valid(program_write_valid),
    .program_write$addr(program_write_addr), .program_write$data(program_write_data),
    .data_word(data_word),
    .tx$valid(tx_valid), .tx$value(tx_value), .rx_pop(rx_pop), .clear_irq(clear_irq),
    .inputs(inputs),
    .pin_out(pin_out), .pin_dir(pin_dir), .pc(pc), .x(x), .y(y), .p(p), .t(t), .osr(osr),
    .osr_count(osr_count), .isr(isr), .isr_count(isr_count), .now(now), .stall(stall),
    .halted(halted), .irq(irq), .fault$underflow(underflow), .fault$overflow(overflow),
    .fault$missed_deadline(missed_deadline), .fault$decode(decode), .capture(capture),
    .capture_armed(capture_armed), .tx_level(tx_level), .rx_level(rx_level),
    .rx_head(rx_head), .instruction(instruction), .crc(crc), .stuff_run(stuff_run),
    .decode_ok(decode_ok), .opcode_onehot(opcode_onehot), .wait_select(wait_select),
    .flip_pending(flip_pending), .flip_bit(flip_bit),
    .eng_jmp_go(jmp_go), .eng_advance(advance), .eng_fetch_addr(fetch_addr),
    .eng_refill(refill), .eng_dout(dout), .eng_probe_addr(probe_addr),
    .eng_probe_word(probe_word));
  // the core's own start flop, which the clear zeroes
  reg started = 0;
  always @(posedge clk) started <= !clear && start;
`ifdef CONFIG_AT_START
  // the host port's gate alone
  always @(posedge clk) if (config_write && halted) config_bits <= config_value;
`else
  always @(posedge clk)
    if (config_write && halted && !started) config_bits <= config_value;
`endif
`ifndef PROGRAM_AT_START
  always @(*) assume(!program_write_valid || !(start || started));
`endif

  // the address the memory read in the last cycle, and the pc after a word
  wire [8:0] read_addr = program_write_valid && halted ? program_write_addr : fetch_addr;
  reg [8:0] last_read;
  reg ready = 0;
  always @(posedge clk) begin
    last_read <= read_addr;
    ready <= 1;
  end
  function [8:0] after(input [8:0] a);
    after = a == wrap_top ? wrap_bottom : a + 9'd1;
  endfunction
  wire issue = !clear && !halted && stall == 0 && !started;

  // the lemma
  always @(posedge clk)
    if (issue && pc == probe_addr) runs_memory: assert(instruction == probe_word);

  // invariants for induction: the read the core made, and the word it holds
  always @(posedge clk)
    if (ready && !clear) begin
      if (last_read == probe_addr) assert(dout == probe_word);
      if (started) assert(refill && last_read == 0);
      else if (!halted && refill) assert(stall != 0 && last_read == pc);
      else if (!halted) begin
        assert(last_read == after(pc));
        if (pc == probe_addr) assert(instruction == probe_word);
      end
    end

  // a run past a jump and a wrap, to a word written while halted
  reg jumped = 0, wrapped = 0;
  always @(posedge clk) begin
    if (clear || start) begin
      jumped <= 0;
      wrapped <= 0;
    end else begin
      if (jmp_go) jumped <= 1;
      if (advance && pc == wrap_top && wrap_bottom != wrap_top + 9'd1) wrapped <= 1;
    end
  end
  always @(posedge clk) cover(issue && jumped && wrapped && pc == probe_addr);
endmodule
