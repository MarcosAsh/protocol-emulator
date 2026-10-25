// The pin bits Hardcaml's coverage waives in src/engine.ml: no write reaches an input
// pin's output bit, nor the direction of a pin that is not bidirectional, so after a
// clear they stay zero for any config, program and inputs. Pins 0-4 are inputs, 5-11
// outputs, 12-19 bidirectional, 20-27 the wires between the engines and 28-31 the status
// pins, inputs again.
module unreachable (input clk);
  (* anyseq *) wire [1:0] side_set_count;
  (* anyseq *) wire [4:0] side_set_base, in_base, in_count, out_base, out_count, set_base;
  (* anyseq *) wire [2:0] set_count;
  (* anyseq *) wire [4:0] jmp_pin, capture_pin, push_threshold, pull_threshold;
  (* anyseq *) wire side_set_pindirs, capture_rising, in_shift_right, out_shift_right, autopush, autopull;
  (* anyseq *) wire [4:0] crc_width, stuff_threshold;
  (* anyseq *) wire [15:0] crc_poly, crc_init;
  (* anyseq *) wire crc_reflect, stuff_level;
  (* anyseq *) wire [8:0] wrap_bottom, wrap_top;
  (* anyseq *) wire [15:0] period_fraction;
  (* anyseq *) wire autopull_data, manchester, data_write_valid;
  (* anyseq *) wire [8:0] data_write_addr;
  (* anyseq *) wire [15:0] data_write_data;
  (* anyseq *) wire stop, flush;
  (* anyseq *) wire start, program_write_valid, tx_valid, rx_pop, clear_irq;
  (* anyseq *) wire [8:0] program_write_addr;
  (* anyseq *) wire [15:0] program_write_data, tx_value;
  (* anyseq *) wire [31:0] inputs;

  reg clear = 1;
  always @(posedge clk) clear <= 0;

  wire [31:0] pin_out, pin_dir;
  wire [8:0] pc;
  wire [15:0] x, y, p, osr, isr, rx_head, instruction, crc;
  wire [23:0] t, now, capture;
  wire [4:0] osr_count, isr_count, stall, stuff_run;
  wire halted, irq, underflow, overflow, missed_deadline, decode, capture_armed;
  wire [3:0] tx_level, rx_level;
  wire decode_ok;
  wire [7:0] opcode_onehot;
  wire [31:0] wait_select;

  engine_top dut (
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
    .data_write$valid(data_write_valid), .data_write$addr(data_write_addr),
    .data_write$data(data_write_data),
    .tx$valid(tx_valid), .tx$value(tx_value), .rx_pop(rx_pop), .clear_irq(clear_irq),
    .inputs(inputs),
    .pin_out(pin_out), .pin_dir(pin_dir), .pc(pc), .x(x), .y(y), .p(p), .t(t), .osr(osr),
    .osr_count(osr_count), .isr(isr), .isr_count(isr_count), .now(now), .stall(stall),
    .halted(halted), .irq(irq), .fault$underflow(underflow), .fault$overflow(overflow),
    .fault$missed_deadline(missed_deadline), .fault$decode(decode), .capture(capture),
    .capture_armed(capture_armed), .tx_level(tx_level), .rx_level(rx_level),
    .rx_head(rx_head), .instruction(instruction), .crc(crc), .stuff_run(stuff_run),
    .decode_ok(decode_ok), .opcode_onehot(opcode_onehot), .wait_select(wait_select));

  always @(posedge clk)
    if (!clear) begin
`ifdef ONE_MORE
      // teeth: pin 5 is an output, so this fails
      assert(pin_out[5:0] == 0);
`else
      assert(pin_out[4:0] == 0);
`endif
      assert(pin_out[31:28] == 0);
      assert(pin_dir[11:0] == 0);
      assert(pin_dir[31:20] == 0);
    end

  // the neighbours of the waived bits do move
  always @(posedge clk)
    if (!clear) begin
      cover(pin_out[5]);
      cover(pin_out[27]);
      cover(pin_dir[12]);
      cover(pin_dir[19]);
    end
endmodule
