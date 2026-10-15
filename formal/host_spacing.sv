// The host side of the halted window: the host port moves an engine's config only after a
// cycle with that engine halted and never the cycle after its start strobe, and writes no
// program or data word in the strobe's cycle or the next. The start's second cycle still
// reads halted and prefetches under the config of the time (test_engine.ml), which
// fetch_step.sv's teeth break. Pins and status are free, the clear after power-on's.

`define CONFIG(n, v) \
  .engines$config$side_set_count_``n(v[140:139]), \
    .engines$config$side_set_base_``n(v[138:134]), \
    .engines$config$side_set_pindirs_``n(v[133]), \
    .engines$config$in_base_``n(v[132:128]), .engines$config$in_count_``n(v[127:123]), \
    .engines$config$out_base_``n(v[122:118]), \
    .engines$config$out_count_``n(v[117:113]), \
    .engines$config$set_base_``n(v[112:108]), \
    .engines$config$set_count_``n(v[107:105]), .engines$config$jmp_pin_``n(v[104:100]), \
    .engines$config$capture_pin_``n(v[99:95]), \
    .engines$config$capture_rising_``n(v[94]), \
    .engines$config$in_shift_right_``n(v[93]), \
    .engines$config$out_shift_right_``n(v[92]), .engines$config$autopush_``n(v[91]), \
    .engines$config$push_threshold_``n(v[90:86]), .engines$config$autopull_``n(v[85]), \
    .engines$config$pull_threshold_``n(v[84:80]), \
    .engines$config$crc_width_``n(v[79:75]), .engines$config$crc_poly_``n(v[74:59]), \
    .engines$config$crc_init_``n(v[58:43]), .engines$config$crc_reflect_``n(v[42]), \
    .engines$config$stuff_threshold_``n(v[41:37]), \
    .engines$config$stuff_level_``n(v[36]), .engines$config$wrap_bottom_``n(v[35:27]), \
    .engines$config$wrap_top_``n(v[26:18]), \
    .engines$config$period_fraction_``n(v[17:2]), \
    .engines$config$autopull_data_``n(v[1]), .engines$config$manchester_``n(v[0])

module host_spacing (input clk);
  (* anyseq *) wire clear, sck, mosi, cs_n;
  (* anyseq *) wire [1:0] halted;
  (* anyseq *) wire [8:0] pc_0, pc_1;
  (* anyseq *) wire [23:0] now_0, now_1, capture_0, capture_1;
  (* anyseq *) wire [1:0] irq, underflow, overflow, missed_deadline, decode;
  (* anyseq *) wire [3:0] tx_level_0, tx_level_1, rx_level_0, rx_level_1;
  (* anyseq *) wire [15:0] rx_head_0, rx_head_1;

  wire [140:0] config_0, config_1;
  wire [1:0] start, program_write, data_write;
`define STATUS(n) \
    .status$pc_``n(pc_``n), .status$now_``n(now_``n), .status$capture_``n(capture_``n), \
    .status$halted_``n(halted[n]), .status$irq_``n(irq[n]), \
    .status$fault$underflow_``n(underflow[n]), .status$fault$overflow_``n(overflow[n]), \
    .status$fault$missed_deadline_``n(missed_deadline[n]), \
    .status$fault$decode_``n(decode[n]), .status$tx_level_``n(tx_level_``n), \
    .status$rx_level_``n(rx_level_``n), .status$rx_head_``n(rx_head_``n)
`define HOST(n) \
    `CONFIG(n, config_``n), .engines$start_``n(start[n]), \
    .engines$program_write$valid_``n(program_write[n]), \
    .engines$data_write$valid_``n(data_write[n])
  host_port dut (
    .clock(clk), .clear(clear), .sck(sck), .mosi(mosi), .cs_n(cs_n), .miso(),
    `STATUS(0), `STATUS(1), `HOST(0), `HOST(1));

  // the chip's reset at power-on, then free
  reg first = 1;
  always @(posedge clk) first <= 0;
  always @(*) if (first) assume(clear);

  reg ready = 0;
  reg [1:0] last_halted, last_start;
  reg [140:0] last_config_0, last_config_1;
  always @(posedge clk) begin
    ready <= !clear;
    last_halted <= halted;
    last_start <= start;
    last_config_0 <= config_0;
    last_config_1 <= config_1;
  end
  // a config moved in this cycle was written in the last one
  wire [1:0] moved = {config_1 != last_config_1, config_0 != last_config_0};

  always @(posedge clk)
    if (ready && !clear) begin
      written_halted: assert((moved & ~last_halted) == 0);
      written_apart: assert((moved & last_start) == 0);
      words_apart: assert(((program_write | data_write) & (start | last_start)) == 0);
    end

  // a start for engine 0, then its config written in a later frame
  reg started_0 = 0;
  always @(posedge clk) if (clear) started_0 <= 0; else if (start[0]) started_0 <= 1;
  always @(posedge clk) begin
    cover(ready && !clear && moved[0] && last_halted[0]);
    cover(ready && !clear && moved[0] && started_0);
  end
endmodule
