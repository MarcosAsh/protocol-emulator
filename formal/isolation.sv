// Engine 0 cannot tell what engine 1 or engine 1's host does. Two copies of the two-engine
// chip share the clear, the pads and all of engine 0's inputs; engine 1's are free in each.
// From the first clear on, engine 0's pins and what the host reads of it agree, by induction
// on engine 0's flops (isolation.tcl). The data memory's turns are proved to hide engine 1's
// reads; the assumptions below close the other channels, and a tooth drops each.

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
  logic [4:0] pull_threshold, crc_width;
  logic [15:0] crc_poly, crc_init;
  logic crc_reflect;
  logic [4:0] stuff_threshold;
  logic stuff_level;
  logic [8:0] wrap_bottom, wrap_top;
  logic [15:0] period_fraction;
  logic autopull_data, manchester;
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
} host_t;

// the load checker's settings, the chip's and not an engine's
typedef struct packed {
  logic [8:0] base;
  logic loaded_valid;
  logic [15:0] loaded_value;
  logic single_edge;
} check_setup_t;

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

// One copy, its macros pulled out, and what the miter reads of it.
module isolation_copy (
  input clk, clear,
  input [19:0] pads,
  input config_t config_0, config_1,
  input host_t host_0, host_1,
  input check_setup_t check_setup,
  input [15:0] dout_0, dout_1, dout_data,
  output port_t port_0, port_1, port_data,
  output [27:0] pin_out_0, pin_dir_0, pin_out_1, pin_dir_1,
  output [19:0] pin_out, pin_dir,
  output status_t status,
  output halted_1,
  output [15:0] instruction,
  output [7:0] opcode_onehot,
  output [27:0] wait_select,
  output capture_armed,
  output [8:0] data_addr,
  output [`STATE_BITS - 1:0] state,
  output fifo_t rx, tx,
  output [27:0] pins_sampled,
  output started, data_mine, lent,
  output [15:0] data_word
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
    .hosts$config$manchester_``n(c.manchester),
`define HOST(n, h) \
    .hosts$start_``n(h.start), .hosts$stop_``n(h.stop), .hosts$flush_``n(h.flush), \
    .hosts$rx_pop_``n(h.rx_pop), .hosts$clear_irq_``n(h.clear_irq), \
    .hosts$tx$valid_``n(h.tx_valid), .hosts$tx$value_``n(h.tx_value), \
    .hosts$program_write$valid_``n(h.program_valid), \
    .hosts$program_write$addr_``n(h.program_addr), \
    .hosts$program_write$data_``n(h.program_data), \
    .hosts$data_write$valid_``n(h.data_valid), .hosts$data_write$addr_``n(h.data_addr), \
    .hosts$data_write$data_``n(h.data_data), \
    .hosts$check_``n(h.check), .hosts$config_written_``n(h.config_written),
`define PORT(prefix, p) \
    .prefix``_men(p.men), .prefix``_wen(p.wen), .prefix``_ren(p.ren), \
    .prefix``_addr(p.addr), .prefix``_din(p.din), .prefix``_bm(p.bm),

  engines_top chip (
    .clock(clk), .clear(clear), .pads(pads),
    .check_setup$base(check_setup.base), .check_setup$loaded$valid(check_setup.loaded_valid),
    .check_setup$loaded$value(check_setup.loaded_value),
    .check_setup$single_edge(check_setup.single_edge),
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
    .engines$data_addr_0(data_addr),
    .state_0(state), .rx_0(rx), .tx_0(tx), .pins_sampled_0(pins_sampled),
    .started_0(started), .data_mine_0(data_mine), .lent_0(lent),
    .data_word_0(data_word));
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
  localparam [27:0] WIRES = 28'hff00000;

  // what both copies share
  (* anyseq *) wire reset;
  (* anyseq *) wire [19:0] pads;
  (* anyseq *) config_t config_0;
  (* anyseq *) host_t host_0;
  // the pins engine 0 reads, engine 0's data words, and one of them
  (* anyconst *) wire [27:0] listens;
  (* anyconst *) wire [511:0] region;
  (* anyconst *) wire [8:0] probe;
  // and what each has of its own
  (* anyseq *) config_t config_1_a, config_1_b;
  (* anyseq *) host_t host_1_a, host_1_b;
  // shared by both copies, as the host port holds it; the checker may run on either engine
  (* anyseq *) check_setup_t check_setup;
  (* anyseq *) wire [15:0] dout_1_a, dout_1_b;

  // both copies clear at the first edge, and together whenever reset comes again
  reg clear = 1, cleared = 0, warm = 0;
  always @(posedge clk) begin
    clear <= reset;
    cleared <= 1;
    warm <= cleared;
  end

  // the checker held engine 0's ports last cycle, in either copy
  reg was_lent = 0;
  always @(posedge clk) was_lent <= lent_a || lent_b;

  wire [15:0] dout_0_a, dout_0_b, dout_data_a, dout_data_b, held_a, held_b;
  port_t port_0_a, port_0_b, port_1_a, port_1_b, port_data_a, port_data_b;
  wire [27:0] pin_out_0_a, pin_dir_0_a, pin_out_1_a, pin_dir_1_a;
  wire [27:0] pin_out_0_b, pin_dir_0_b, pin_out_1_b, pin_dir_1_b;
  wire [19:0] pin_out_a, pin_dir_a, pin_out_b, pin_dir_b;
  status_t status_a, status_b;
  wire halted_1_a, halted_1_b, capture_armed_a, capture_armed_b;
  wire [15:0] instruction_a, instruction_b, data_word_a, data_word_b;
  wire [7:0] opcode_onehot_a, opcode_onehot_b;
  wire [27:0] wait_select_a, wait_select_b, pins_sampled_a, pins_sampled_b;
  wire [8:0] data_addr_a, data_addr_b;
  wire [`STATE_BITS - 1:0] state_a, state_b;
  fifo_t rx_a, tx_a, rx_b, tx_b;
  wire started_a, started_b, data_mine_a, data_mine_b, lent_a, lent_b;

`define COPY(side) \
  isolation_copy side ( \
    .clk(clk), .clear(clear), .pads(pads), \
    .config_0(config_0), .config_1(config_1_``side), .host_0(host_0), .host_1(host_1_``side), \
    .check_setup(check_setup), \
    .dout_0(dout_0_``side), .dout_1(dout_1_``side), .dout_data(dout_data_``side), \
    .port_0(port_0_``side), .port_1(port_1_``side), .port_data(port_data_``side), \
    .pin_out_0(pin_out_0_``side), .pin_dir_0(pin_dir_0_``side), \
    .pin_out_1(pin_out_1_``side), .pin_dir_1(pin_dir_1_``side), \
    .pin_out(pin_out_``side), .pin_dir(pin_dir_``side), .status(status_``side), \
    .halted_1(halted_1_``side), .instruction(instruction_``side), \
    .opcode_onehot(opcode_onehot_``side), .wait_select(wait_select_``side), \
    .capture_armed(capture_armed_``side), .data_addr(data_addr_``side), \
    .state(state_``side), .rx(rx_``side), .tx(tx_``side), \
    .pins_sampled(pins_sampled_``side), .started(started_``side), \
    .data_mine(data_mine_``side), .lent(lent_``side), .data_word(data_word_``side));

  `COPY(a)
  `COPY(b)

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

  // Pins.read's window, and the pin an index picks, the last for any past it
  function [27:0] window(input [4:0] base, input [4:0] count);
    reg [15:0] mask;
    reg [55:0] twice;
    begin
      mask = count >= 16 ? 16'hffff : (16'd1 << count) - 16'd1;
      twice = {12'd0, mask, 12'd0, mask} << (base >= 28 ? base - 5'd28 : base);
      window = twice[55:28];
    end
  endfunction
  function [27:0] pin(input [4:0] index);
    pin = index >= 27 ? 28'h8000000 : 28'd1 << index;
  endfunction

  // the word in engine 0's instruction register, and the pins it reads
  wire [2:0] opcode = instruction_a[15:13];
  wire waits_on_pin = opcode == 1 && instruction_a[6:5] <= 1;
  wire jumps_on_pin = opcode == 0 && (instruction_a[12:9] == 4 || instruction_a[12:9] == 5);
  wire ins_pins = opcode == 2 && instruction_a[7:5] == 0;
  wire movs_pins = opcode == 4 && instruction_a[2:0] == 0;

  always @* if (cleared) begin
    // Engine 0 reads only pins in listens: each word it runs, and its capture pin while
    // armed.
    if (waits_on_pin) assume (((28'd1 << instruction_a[4:0]) & ~listens) == 0);
    if (jumps_on_pin) assume ((pin(config_0.jmp_pin) & ~listens) == 0);
    if (ins_pins) assume ((window(config_0.in_base, instruction_a[4:0]) & ~listens) == 0);
    if (movs_pins) assume ((window(config_0.in_base, config_0.in_count) & ~listens) == 0);
    if (capture_armed_a) assume ((pin(config_0.capture_pin) & ~listens) == 0);
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
    // Data writes land only while both engines are halted, so the host writes engine 0's
    // only while engine 1 is.
`ifndef LOAD_ANYTIME
    if (host_0.data_valid) assume (halted_1_a && halted_1_b);
`endif
    // No data write lands in the cycle engine 0 starts or the next, while its pointer
    // waits for the word at 0.
`ifndef START_WRITE
    if (host_0.start || started_a) assume (!port_data_a.wen && !port_data_b.wen);
`endif
  end

  // the pads engine 1 reaches in either copy
  wire [27:0] touched_1 = pin_out_1_a | pin_out_1_b | pin_dir_1_a | pin_dir_1_b;
  wire [19:0] drives_1 = touched_1[19:0];

  // the claim: engine 0's pins, the pads engine 1 leaves alone, and what the host reads
  always @* if (cleared) begin
    assert (pin_out_0_a == pin_out_0_b);
    assert (pin_dir_0_a == pin_dir_0_b);
    assert (((pin_out_a ^ pin_out_b) & ~drives_1) == 0);
    assert (((pin_dir_a ^ pin_dir_b) & ~drives_1) == 0);
    assert (status_a == status_b);
  end

`ifndef NO_INVARIANT
  // the invariant beside fifo_pair
  fifo_pair rx (.check(cleared), .a(rx_a), .b(rx_b));
  fifo_pair tx (.check(cleared), .a(tx_a), .b(tx_b));
  always @* begin
    assert (cleared || clear);
    if (cleared) begin
      assert (state_a == state_b && started_a == started_b);
      assert (((pins_sampled_a ^ pins_sampled_b) & listens) == 0);
      assert (opcode_onehot_a == 8'd1 << opcode);
      assert (wait_select_a == 28'd1 << instruction_a[4:0]);
      if (!lent_a && !lent_b) assert (port_0_a == port_0_b);
      assert (held_a == held_b);
      // each write into the region lands in both alike
      assert ((port_data_a.wen && region[port_data_a.addr])
              == (port_data_b.wen && region[port_data_b.addr]));
      if (port_data_a.wen && region[port_data_a.addr])
        assert (port_data_a.addr == port_data_b.addr && port_data_a.din == port_data_b.din
                && port_data_a.bm == port_data_b.bm);
      // the word engine 0 streams agrees while it runs, and as it starts once read
      if (!status_a.halted) assert (data_word_a == data_word_b);
      if (started_a) begin
        assert (data_mine_a == data_mine_b);
        if (data_mine_a) assert (data_word_a == data_word_b);
      end
    end
    if (warm && !was_lent) assert (dout_0_a == dout_0_b);
  end
`endif

  // Engine 0 moves a pin while engine 1 drives differently in the copies, and ten cycles
  // into a run; reads pins while engine 1 drives other pads differently; pulls a data word
  // while engine 1 runs in one copy alone; and runs on after a data write landed in one
  // copy alone.
  reg [27:0] last_pin_out;
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
