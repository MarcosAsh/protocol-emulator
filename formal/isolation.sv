// Engine 0 cannot tell what engine 1 or engine 1's host does. Two copies of the two-engine
// chip as built, starts gated, share the clear, the pads and all of engine 0's inputs;
// engine 1's are free in each. From the first clear on, engine 0's pins and what the host
// reads of it, its check's verdict too, agree, by induction on engine 0's flops
// (isolation.tcl), the frame receivers' when engine 0 owns them, and the load checker's
// while neither copy has walked engine 1 since engine 0's last check. The data memory's
// turns are proved to hide engine 1's reads, and the checker's fixed
// turns its checks; the assumptions below close the other channels, and a tooth drops
// each. Five are premises on how the chip is used, not channels it closes: no routed
// pushes between the two (ROUTED), no start of every engine at once (START_ALL), the
// receivers' words above engine 0's region while engine 1 owns them (FRAME_IN_REGION),
// no load by engine 1's host while a word engine 0's receiver took waits to land
// (LOAD_PENDING), and engine 0's certificate in its region (CERT_OUTSIDE). The owner is
// fixed. The teeth that need engine 0 running drop the gate, as a certified start takes a
// full walk.

`include "pairs.sv"

typedef struct packed {
  logic [1:0] side_set_count;
  logic [4:0] side_set_base;
  logic side_set_pindirs;
  logic [4:0] in_base, in_count, out_base, out_count, set_base;
  logic [2:0] set_count;
  logic [4:0] jmp_pin, capture_pin;
  logic capture_rising, in_shift_right, out_shift_right, autopush;
  logic [4:0] push_threshold;
  logic autopull;
  logic [4:0] pull_threshold;
  logic [5:0] crc_width;
  logic [15:0] crc_poly, crc_init;
  logic crc_reflect;
  logic [4:0] stuff_threshold;
  logic stuff_level;
  logic [8:0] wrap_bottom, wrap_top;
  logic [15:0] period_fraction;
  logic autopull_data, manchester, line_code, route;
  logic [15:0] crc_poly_high, crc_init_high;
  logic crc_complement;
} config_t;

typedef struct packed {
  logic start, stop, flush, rx_pop, clear_irq, tx_valid;
  logic [15:0] tx_value;
  logic program_valid;
  logic [8:0] program_addr;
  logic [15:0] program_data;
  logic data_valid;
  logic [8:0] data_addr;
  logic [15:0] data_data;
  logic check, config_written;
  logic line_valid;
  logic [4:0] line_addr;
  logic [15:0] line_data;
} host_t;

// the load checker's settings, the chip's and not an engine's
typedef struct packed {
  logic [8:0] base;
  logic loaded_valid;
  logic [15:0] loaded_value;
  logic single_edge, floor;
} check_setup_t;

// the chip's own host fields: the frame receiver's and the edge stamps' controls, and the
// start of every engine
typedef struct packed {
  logic arm;
  logic [8:0] base;
  logic fifty;
  logic usb;
} frame_t;

typedef struct packed {
  logic [19:0] mask;
  logic engine, flush, pop;
} stamps_t;

// a macro's inputs
typedef struct packed {
  logic men, wen, ren;
  logic [8:0] addr;
  logic [15:0] din, bm;
} port_t;

// what the host port reads of an engine (Host_port.Status)
typedef struct packed {
  logic halted, irq;
  logic [3:0] fault, tx_level, rx_level;
  logic [15:0] rx_head;
  logic [8:0] pc;
  logic [23:0] now, capture;
} status_t;

// engine 0's check as the host reads it
typedef struct packed {
  logic busy, accepted;
  logic [9:0] reject_pc;
  logic [4:0] reason;
} verdict_t;

// One copy, its macros pulled out, and what the miter reads of it.
module isolation_copy (
  input clk, clear,
  input [19:0] pads,
  input [1:0] rd, dm,
  input config_t config_0, config_1,
  input host_t host_0, host_1,
  input check_setup_t check_setup,
  input frame_t frame,
  input owner,
  input stamps_t stamps,
  input start_all,
  input [15:0] dout_0, dout_1, dout_data,
  output port_t port_0, port_1, port_data,
  output [31:0] pin_out_0, pin_dir_0, pin_out_1, pin_dir_1,
  output [19:0] pin_out, pin_dir,
  output status_t status,
  output halted_1,
  output [15:0] instruction,
  output [7:0] opcode_onehot,
  output [31:0] wait_select,
  output capture_armed, holding,
  output [8:0] data_addr,
  output [`STATE_BITS - 1:0] state,
  output fifo_t rx, tx,
  output [31:0] pins_sampled,
  output started, data_mine, lent,
  output [15:0] data_word,
  output [8:0] held_addr,
  output held_valid,
  output [`RECEIVER_BITS - 1:0] receivers,
  output pending,
  output certified, refused,
  output verdict_t verdict,
  output checking, checked, chosen, turn_starts, finished, read_done,
  output load_checker_t load_checker,
  output [`WORD_CLASS_BITS - 1:0] word_class,
  output [`CHECKER_BITS - 1:0] checker_flops,
  output [9:0] walk_span,
  output [8:0] walk_base, walk_read_at,
  output walk_reads
);
`define CONFIG(n, c) \
    .hosts$config$side_set_count_``n(c.side_set_count), \
    .hosts$config$side_set_base_``n(c.side_set_base), \
    .hosts$config$side_set_pindirs_``n(c.side_set_pindirs), \
    .hosts$config$in_base_``n(c.in_base), .hosts$config$in_count_``n(c.in_count), \
    .hosts$config$out_base_``n(c.out_base), .hosts$config$out_count_``n(c.out_count), \
    .hosts$config$set_base_``n(c.set_base), .hosts$config$set_count_``n(c.set_count), \
    .hosts$config$jmp_pin_``n(c.jmp_pin), .hosts$config$capture_pin_``n(c.capture_pin), \
    .hosts$config$capture_rising_``n(c.capture_rising), \
    .hosts$config$in_shift_right_``n(c.in_shift_right), \
    .hosts$config$out_shift_right_``n(c.out_shift_right), \
    .hosts$config$autopush_``n(c.autopush), .hosts$config$push_threshold_``n(c.push_threshold), \
    .hosts$config$autopull_``n(c.autopull), .hosts$config$pull_threshold_``n(c.pull_threshold), \
    .hosts$config$crc_width_``n(c.crc_width), .hosts$config$crc_poly_``n(c.crc_poly), \
    .hosts$config$crc_init_``n(c.crc_init), .hosts$config$crc_reflect_``n(c.crc_reflect), \
    .hosts$config$stuff_threshold_``n(c.stuff_threshold), \
    .hosts$config$stuff_level_``n(c.stuff_level), \
    .hosts$config$wrap_bottom_``n(c.wrap_bottom), .hosts$config$wrap_top_``n(c.wrap_top), \
    .hosts$config$period_fraction_``n(c.period_fraction), \
    .hosts$config$autopull_data_``n(c.autopull_data), \
    .hosts$config$manchester_``n(c.manchester), \
    .hosts$config$line_code_``n(c.line_code), .hosts$config$route_``n(c.route), \
    .hosts$config$crc_poly_high_``n(c.crc_poly_high), \
    .hosts$config$crc_init_high_``n(c.crc_init_high), \
    .hosts$config$crc_complement_``n(c.crc_complement),
`define HOST(n, h) \
    .hosts$start_``n(h.start), .hosts$stop_``n(h.stop), .hosts$flush_``n(h.flush), \
    .hosts$rx_pop_``n(h.rx_pop), .hosts$clear_irq_``n(h.clear_irq), \
    .hosts$tx$valid_``n(h.tx_valid), .hosts$tx$value_``n(h.tx_value), \
    .hosts$program_write$valid_``n(h.program_valid), \
    .hosts$program_write$addr_``n(h.program_addr), \
    .hosts$program_write$data_``n(h.program_data), \
    .hosts$data_write$valid_``n(h.data_valid), .hosts$data_write$addr_``n(h.data_addr), \
    .hosts$data_write$data_``n(h.data_data), \
    .hosts$check_``n(h.check), .hosts$config_written_``n(h.config_written), \
    .hosts$line_write$valid_``n(h.line_valid), .hosts$line_write$addr_``n(h.line_addr), \
    .hosts$line_write$data_``n(h.line_data),
`define PORT(prefix, p) \
    .prefix``_men(p.men), .prefix``_wen(p.wen), .prefix``_ren(p.ren), \
    .prefix``_addr(p.addr), .prefix``_din(p.din), .prefix``_bm(p.bm),

  wire frame_pending, usb_pending;
  engines_top chip (
    .clock(clk), .clear(clear), .pads(pads),
    .check_setup$base(check_setup.base), .check_setup$loaded$valid(check_setup.loaded_valid),
    .check_setup$loaded$value(check_setup.loaded_value),
    .check_setup$single_edge(check_setup.single_edge),
    .check_setup$floor(check_setup.floor),
    .start_all(start_all), .rd(rd), .dm(dm),
    .frame$arm(frame.arm), .frame$base(frame.base), .frame$fifty(frame.fifty),
    .frame_usb(frame.usb), .frame_owner(owner),
    .stamps$mask(stamps.mask), .stamps$engine(stamps.engine), .stamps$flush(stamps.flush),
    .stamps$pop(stamps.pop),
    `CONFIG(0, config_0) `HOST(0, host_0)
    `CONFIG(1, config_1) `HOST(1, host_1)
    `PORT(sram_0, port_0) `PORT(sram_1, port_1) `PORT(data_sram, port_data)
    .sram_0_dout(dout_0), .sram_1_dout(dout_1), .data_sram_dout(dout_data),
    .engines$pin_out_0(pin_out_0), .engines$pin_dir_0(pin_dir_0),
    .engines$pin_out_1(pin_out_1), .engines$pin_dir_1(pin_dir_1),
    .pin_out(pin_out), .pin_dir(pin_dir),
    .engines$halted_0(status.halted), .engines$irq_0(status.irq),
    .engines$fault$underflow_0(status.fault[3]), .engines$fault$overflow_0(status.fault[2]),
    .engines$fault$missed_deadline_0(status.fault[1]),
    .engines$fault$decode_0(status.fault[0]),
    .engines$tx_level_0(status.tx_level), .engines$rx_level_0(status.rx_level),
    .engines$rx_head_0(status.rx_head), .engines$pc_0(status.pc),
    .engines$now_0(status.now), .engines$capture_0(status.capture),
    .engines$halted_1(halted_1),
    .engines$instruction_0(instruction), .engines$opcode_onehot_0(opcode_onehot),
    .engines$wait_select_0(wait_select), .engines$capture_armed_0(capture_armed),
    .holding_0(holding),
    .engines$data_addr_0(data_addr),
    .state_0(state), .rx_0(rx), .tx_0(tx), .pins_sampled_0(pins_sampled),
    .started_0(started), .data_mine_0(data_mine), .lent_0(lent),
    .data_word_0(data_word), .held_addr_0(held_addr), .held_valid_0(held_valid),
    .receivers(receivers), .frame_pending(frame_pending), .usb_pending(usb_pending),
    .check$certified_0(certified), .check$refused_0(refused),
    .check$verdicts$busy_0(verdict.busy), .check$verdicts$accepted_0(verdict.accepted),
    .check$verdicts$reject_pc_0(verdict.reject_pc), .check$verdicts$reason_0(verdict.reason),
    .checking(checking), .checked(checked), .chosen(chosen), .turn_starts(turn_starts),
    .finished(finished), .read_done(read_done), .load_checker(load_checker),
    .word_class(word_class), .checker_flops(checker_flops), .walk_span(walk_span),
    .walk_base(walk_base), .walk_read_at(walk_read_at), .walk_reads(walk_reads));
  assign pending = frame_pending || usb_pending;
endmodule

// The data memory of each copy, as the register its reads fill. Both read the same word
// alike where it is engine 0's region, whose words agree in both copies since each write
// into it lands in both alike, which the miter asserts. One word, at probe, is held as
// each copy has it, so a write landing in one copy alone can reach engine 0's pins.
module data_pair (
  input clk,
  input first,
  input [511:0] region,
  input [8:0] probe,
  input port_t a, b,
  output reg [15:0] dout_a, dout_b, held_a, held_b
);
  (* anyseq *) wire [15:0] shared, own_a, own_b;

  wire same = !first && !a.wen && !b.wen && a.addr == b.addr && region[a.addr];
  always @(posedge clk) begin
    if (a.men && a.ren)
      dout_a <= a.wen ? own_a : a.addr == probe ? held_a : same ? shared : own_a;
    if (b.men && b.ren)
      dout_b <= b.wen ? own_b : b.addr == probe ? held_b : same ? shared : own_b;
    if (a.men && a.wen && a.addr == probe) held_a <= (held_a & ~a.bm) | (a.din & a.bm);
    if (b.men && b.wen && b.addr == probe) held_b <= (held_b & ~b.bm) | (b.din & b.bm);
  end
endmodule

module isolation (input clk);
  localparam [31:0] WIRES = 32'h0ff00000;

  // what both copies share
  (* anyseq *) wire reset;
  (* anyseq *) wire [19:0] pads;
  (* anyseq *) config_t config_0;
  (* anyseq *) host_t host_0;
  // the pins engine 0 reads, engine 0's data words, and one of them
  (* anyconst *) wire [31:0] listens;
  (* anyconst *) wire [511:0] region;
  (* anyconst *) wire [8:0] probe;
  // the engine the frame receivers belong to
`ifdef OWNER_MOVES
  (* anyseq *) wire owner;
`else
  (* anyconst *) wire owner;
`endif
  // and what each has of its own
  (* anyseq *) config_t config_1_a, config_1_b;
  (* anyseq *) host_t host_1_a, host_1_b;
  // shared by both copies, as the host port holds it; the checker may run on either engine
  (* anyseq *) check_setup_t check_setup;
  (* anyseq *) frame_t frame;
  (* anyseq *) stamps_t stamps;
  (* anyseq *) wire start_all;
  // the 10BASE-T or USB D+ pad's samples on both edges, and USB D-'s, as the top takes
  // them off the pads
  (* anyseq *) wire [1:0] rd, dm;
  (* anyseq *) wire [15:0] dout_1_a, dout_1_b;

  // both copies clear at the first edge, and together whenever reset comes again
  reg clear = 1, cleared = 0, warm = 0;
  always @(posedge clk) begin
    clear <= reset;
    cleared <= 1;
    warm <= cleared;
  end

  config_t last_config_0;
  always @(posedge clk) last_config_0 <= config_0;

  wire [15:0] dout_0_a, dout_0_b, dout_data_a, dout_data_b, held_a, held_b;
  port_t port_0_a, port_0_b, port_1_a, port_1_b, port_data_a, port_data_b;
  wire [31:0] pin_out_0_a, pin_dir_0_a, pin_out_1_a, pin_dir_1_a;
  wire [31:0] pin_out_0_b, pin_dir_0_b, pin_out_1_b, pin_dir_1_b;
  wire [19:0] pin_out_a, pin_dir_a, pin_out_b, pin_dir_b;
  status_t status_a, status_b;
  wire halted_1_a, halted_1_b, capture_armed_a, capture_armed_b, holding_a, holding_b;
  wire [15:0] instruction_a, instruction_b, data_word_a, data_word_b;
  wire [7:0] opcode_onehot_a, opcode_onehot_b;
  wire [31:0] wait_select_a, wait_select_b, pins_sampled_a, pins_sampled_b;
  wire [8:0] data_addr_a, data_addr_b;
  wire [`STATE_BITS - 1:0] state_a, state_b;
  fifo_t rx_a, tx_a, rx_b, tx_b;
  wire started_a, started_b, data_mine_a, data_mine_b, lent_a, lent_b;
  wire [8:0] held_addr_a, held_addr_b;
  wire held_valid_a, held_valid_b;
  wire [`RECEIVER_BITS - 1:0] receivers_a, receivers_b;
  wire pending_a, pending_b;
  wire certified_a, certified_b, refused_a, refused_b;
  verdict_t verdict_a, verdict_b;
  wire checking_a, checking_b, checked_a, checked_b, chosen_a, chosen_b;
  wire turn_starts_a, turn_starts_b, finished_a, finished_b, read_done_a, read_done_b;
  load_checker_t load_checker_a, load_checker_b;
  wire [`WORD_CLASS_BITS - 1:0] word_class_a, word_class_b;
  wire [`CHECKER_BITS - 1:0] checker_a, checker_b;
  wire [9:0] walk_span_a, walk_span_b;
  wire [8:0] walk_base_a, walk_base_b, walk_read_at_a, walk_read_at_b;
  wire walk_reads_a, walk_reads_b;

`define COPY(side) \
  isolation_copy side ( \
    .clk(clk), .clear(clear), .pads(pads), .rd(rd), .dm(dm), \
    .config_0(config_0), .config_1(config_1_``side), .host_0(host_0), .host_1(host_1_``side), \
    .check_setup(check_setup), .frame(frame), .owner(owner), .stamps(stamps), \
    .start_all(start_all), \
    .dout_0(dout_0_``side), .dout_1(dout_1_``side), .dout_data(dout_data_``side), \
    .port_0(port_0_``side), .port_1(port_1_``side), .port_data(port_data_``side), \
    .pin_out_0(pin_out_0_``side), .pin_dir_0(pin_dir_0_``side), \
    .pin_out_1(pin_out_1_``side), .pin_dir_1(pin_dir_1_``side), \
    .pin_out(pin_out_``side), .pin_dir(pin_dir_``side), .status(status_``side), \
    .halted_1(halted_1_``side), .instruction(instruction_``side), \
    .opcode_onehot(opcode_onehot_``side), .wait_select(wait_select_``side), \
    .capture_armed(capture_armed_``side), .holding(holding_``side), \
    .data_addr(data_addr_``side), \
    .state(state_``side), .rx(rx_``side), .tx(tx_``side), \
    .pins_sampled(pins_sampled_``side), .started(started_``side), \
    .data_mine(data_mine_``side), .lent(lent_``side), .data_word(data_word_``side), \
    .held_addr(held_addr_``side), .held_valid(held_valid_``side), \
    .receivers(receivers_``side), .pending(pending_``side), \
    .certified(certified_``side), .refused(refused_``side), .verdict(verdict_``side), \
    .checking(checking_``side), .checked(checked_``side), .chosen(chosen_``side), \
    .turn_starts(turn_starts_``side), .finished(finished_``side), \
    .read_done(read_done_``side), .load_checker(load_checker_``side), \
    .word_class(word_class_``side), .checker_flops(checker_``side), \
    .walk_span(walk_span_``side), .walk_base(walk_base_``side), \
    .walk_read_at(walk_read_at_``side), .walk_reads(walk_reads_``side));

  `COPY(a)
  `COPY(b)

  // engine 0's walk, and the words from its base it has read past, as a rotated mask
  wire walk_0_a = checking_a && !checked_a, walk_0_b = checking_b && !checked_b;
  wire [1023:0] below_span = (1024'd1 << walk_span_a) - 1'd1;
  wire [1023:0] walked = {below_span[511:0], below_span[511:0]} << walk_base_a;

  // engine 0's program is the same in both (powerup.sv's premise); engine 1's words are
  // free in each
  sram_pair program_0 (
    .clk(clk), .first(!cleared),
    .ports_a({port_0_a.men, port_0_a.wen, port_0_a.ren, port_0_a.addr == port_0_b.addr,
              port_0_a.din == port_0_b.din, port_0_a.bm == port_0_b.bm}),
    .ports_b({port_0_b.men, port_0_b.wen, port_0_b.ren, port_0_a.addr == port_0_b.addr,
              port_0_a.din == port_0_b.din, port_0_a.bm == port_0_b.bm}),
    .dout_a(dout_0_a), .dout_b(dout_0_b));
  data_pair data (
    .clk(clk), .first(!cleared), .region(region), .probe(probe),
    .a(port_data_a), .b(port_data_b),
    .dout_a(dout_data_a), .dout_b(dout_data_b), .held_a(held_a), .held_b(held_b));
  always @* if (cleared && !warm) assume (held_a == held_b);
  always @* assume (region[probe]);

  // Pins.read's window, and the pin an index picks
  function [31:0] window(input [4:0] base, input [4:0] count);
    reg [15:0] mask;
    reg [63:0] twice;
    begin
      mask = count >= 16 ? 16'hffff : (16'd1 << count) - 16'd1;
      twice = {16'd0, mask, 16'd0, mask} << base;
      window = twice[63:32];
    end
  endfunction
  function [31:0] pin(input [4:0] index);
    pin = 32'd1 << index;
  endfunction

  // the word in engine 0's instruction register, and the pins it reads
  wire [2:0] opcode = instruction_a[15:13];
  wire waits_on_pin = opcode == 1 && instruction_a[6:5] <= 1;
  wire jumps_on_pin = opcode == 0 && (instruction_a[12:9] == 4 || instruction_a[12:9] == 5);
  wire ins_pins = opcode == 2 && instruction_a[7:5] == 0;
  wire movs_pins = opcode == 4 && instruction_a[2:0] == 0;
  wire arms = opcode == 7 && instruction_a[3:0] == 7;

  always @* if (cleared) begin
    // Engine 0 reads only pins in listens: each word it runs, and its capture pin as it
    // arms, while armed, and while it watches a single-edge premise.
    if (waits_on_pin) assume (((32'd1 << instruction_a[4:0]) & ~listens) == 0);
    if (jumps_on_pin) assume ((pin(config_0.jmp_pin) & ~listens) == 0);
    if (ins_pins) assume ((window(config_0.in_base, instruction_a[4:0]) & ~listens) == 0);
    // a one-bit in under a line code reads its pin as Pins.pin picks it
    if (ins_pins && config_0.line_code && instruction_a[4:0] == 1)
      assume ((pin(config_0.in_base) & ~listens) == 0);
    if (movs_pins) assume ((window(config_0.in_base, config_0.in_count) & ~listens) == 0);
    if (capture_armed_a || arms || holding_a)
      assume ((pin(config_0.capture_pin) & ~listens) == 0);
    // Engine 1 is not heard there: it drives no pad direction and no wire level among
    // them, which the frame lemma gives when its footprint misses them.
`ifndef HEARD
    assume (((pin_out_1_a | pin_out_1_b) & WIRES & listens) == 0);
`endif
`ifndef PAD_HEARD
    assume (((pin_dir_1_a | pin_dir_1_b) & listens) == 0);
`endif
    // Engine 0's data pointer stays in its region, and engine 1's host writes none of it.
`ifndef OUTSIDE
    assume (region[data_addr_a]);
`endif
`ifndef REGION_WRITTEN
    if (host_1_a.data_valid) assume (!region[host_1_a.data_addr]);
    if (host_1_b.data_valid) assume (!region[host_1_b.data_addr]);
`endif
    // Data writes land only while both engines are halted and the checker walks no other
    // engine, so the host writes engine 0's only while engine 1 is halted and not walked.
`ifndef LOAD_ANYTIME
    if (host_0.data_valid)
      assume (halted_1_a && halted_1_b && !(checking_a && checked_a)
              && !(checking_b && checked_b));
`endif
    // No data write lands in the cycle engine 0 starts or the next, while its pointer
    // waits for the word at 0.
`ifndef START_WRITE
    if (host_0.start || started_a) assume (!port_data_a.wen && !port_data_b.wen);
`endif
    // Neither engine routes its pushes to the other, a channel by design.
`ifndef ROUTED
    assume (!config_0.route && !config_1_a.route && !config_1_b.route);
`endif
    // No start of every engine at once, which waits for engine 1 to halt.
`ifndef START_ALL
    assume (!start_all);
`endif
    // The receivers' words land from their base up, so a base above engine 0's region
    // keeps every word of a frame, of any length, out of it. Engine 0's own receivers land
    // their words in both copies alike, anywhere.
`ifndef FRAME_IN_REGION
    if (owner) assume ((region >> frame.base) == 0);
`endif
    // A host load takes the data memory's port, so engine 1's would put off a word engine
    // 0's receiver has waiting.
`ifndef LOAD_PENDING
    if (!owner && pending_a) assume (!host_1_a.data_valid && !host_1_b.data_valid);
`endif
    // Engine 0's certificate lies in its region: every word its walk reads, and every word
    // from its base up to the furthest it has read.
`ifndef CERT_OUTSIDE
    if (walk_0_a) begin
      if (walk_reads_a) assume (region[walk_read_at_a]);
      assume ((walked[1023:512] & ~region) == 0);
    end
`endif
    // Engine 0's config changes only while it is halted, as the host port writes it.
    if (!status_a.halted) assume (config_0 == last_config_0);
  end

  // the pads engine 1 reaches in either copy
  wire [31:0] touched_1 = pin_out_1_a | pin_out_1_b | pin_dir_1_a | pin_dir_1_b;
  wire [19:0] drives_1 = touched_1[19:0];

  // the claim: engine 0's pins, the pads engine 1 leaves alone, and what the host reads
  always @* if (cleared) begin
    assert (pin_out_0_a == pin_out_0_b);
    assert (pin_dir_0_a == pin_dir_0_b);
    assert (((pin_out_a ^ pin_out_b) & ~drives_1) == 0);
    assert (((pin_dir_a ^ pin_dir_b) & ~drives_1) == 0);
    assert (status_a == status_b);
    assert (certified_a == certified_b && refused_a == refused_b);
    assert (verdict_a == verdict_b);
  end

`ifndef NO_INVARIANT
  // the invariant beside fifo_pair
  fifo_pair rx (.check(cleared), .a(rx_a), .b(rx_b));
  fifo_pair tx (.check(cleared), .a(tx_a), .b(tx_b));
  always @* begin
    assert (cleared || clear);
    if (cleared) begin
      assert (state_a == state_b && started_a == started_b);
      // engine 0's receivers, whose status pins it reads, agree
      if (!owner) assert (receivers_a == receivers_b);
      assert (((pins_sampled_a ^ pins_sampled_b) & listens) == 0);
      assert (opcode_onehot_a == 8'd1 << opcode);
      assert (wait_select_a == 32'd1 << instruction_a[4:0]);
      // engine 0's program port, the checker's while lent
      assert (port_0_a == port_0_b);
      assert (held_a == held_b);
      // each write into the region lands in both alike
      assert ((port_data_a.wen && region[port_data_a.addr])
              == (port_data_b.wen && region[port_data_b.addr]));
      if (port_data_a.wen && region[port_data_a.addr])
        assert (port_data_a.addr == port_data_b.addr && port_data_a.din == port_data_b.din
                && port_data_a.bm == port_data_b.bm);
      // the word engine 0 streams agrees while it runs pulling data, as a write takes its
      // turn only where it keeps its word and skips the read, and as it starts once read
      if (!status_a.halted && config_0.autopull_data) begin
        assert (data_word_a == data_word_b);
        // and whether it keeps a word, and where, so a write takes its turn in both alike
        assert (held_valid_a == held_valid_b);
        if (held_valid_a) assert (held_addr_a == held_addr_b);
      end
      // an engine that pulls no data leaves its turn to a write and reads no word
      if (started_a && config_0.autopull_data) begin
        assert (data_mine_a == data_mine_b);
        if (data_mine_a) assert (data_word_a == data_word_b);
      end
      // The checker runs engine 0's walks alike in both, engine 1's as each copy has them:
      // a walk runs in its engine's turn, and none at a turn's start.
      if (checking_a) assert (checked_a == chosen_a);
      if (checking_b) assert (checked_b == chosen_b);
      if (turn_starts_a) assert (!checking_a && !checking_b);
      assert (walk_0_a == walk_0_b);
      if (finished_a && !checked_a || finished_b && !checked_b)
        assert (finished_a && finished_b && !checked_a && !checked_b);
      // the checker's flops alike while neither copy has walked engine 1 since engine 0's
      // check, its words and rows from its write of them (load_checker_pair)
      if (!checked_a && !checked_b) begin
        assert (checker_a == checker_b);
        if (load_checker_a.sm > 3) assert (word_class_a == word_class_b);
      end
      // the word a walk of engine 0 takes, read in its turn
      if (walk_0_a && read_done_a) assert (data_word_a == data_word_b);
    end
    if (warm) assert (dout_0_a == dout_0_b);
  end
  load_checker_pair walk (
    .check(cleared && !checked_a && !checked_b), .a(load_checker_a), .b(load_checker_b));
`endif

  // Engine 0 moves a pin while engine 1 drives differently in the copies, and ten cycles
  // into a run; reads pins while engine 1 drives other pads differently; pulls a data word
  // while engine 1 runs in one copy alone; and runs on after a data write landed in one
  // copy alone.
  reg [31:0] last_pin_out;
  reg [8:0] last_data_addr;
  reg written_apart = 0;
  always @(posedge clk) begin
    last_pin_out <= pin_out_0_a;
    last_data_addr <= data_addr_a;
    if (port_data_a.wen != port_data_b.wen) written_apart <= 1;
  end
  always @* if (warm) begin
    cover (pin_out_0_a != last_pin_out && pin_out_1_a != pin_out_1_b);
    cover (pin_out_0_a != last_pin_out && pin_out_1_a != pin_out_1_b && status_a.now == 10);
    cover (ins_pins && !status_a.halted && pin_dir_1_a != pin_dir_1_b);
    cover (!status_a.halted && data_addr_a == last_data_addr + 9'd1 && halted_1_a != halted_1_b);
    cover (written_apart && pin_out_0_a != last_pin_out && pin_dir_1_a != pin_dir_1_b);
  end
endmodule
