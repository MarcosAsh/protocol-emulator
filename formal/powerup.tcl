# The chip's flops as ports for powerup.sv's invariant: each host fifo and the edge
# stamps' as one port named for it (flops.tcl); the load checker's state and the flops it
# keeps without a clear as one port, load_checker; every other flop as one port, state,
# whose width goes to powerup.sv as STATE_BITS.

source flops.tcl
yosys cd tt_um_marcosash_protocol_emulator

foreach {fifo port} {engine_0.rx rx_0 engine_0.tx tx_0 engine_1.rx rx_1 engine_1.tx tx_1} {
  gather_fifo core.top.engines.$fifo $port
}
set stamps [gather_fifo core.top.engines.edge_stamps stamps 4 full]

# in the order of load_checker_t in pairs.sv, first field last
set fields {}
foreach wire {sm source k field word acc entry failed_next$* failed_target$* row$*} {
  lappend fields {*}[wires w:core.top.engines.load_checker.$wire]
}
gather load_checker $fields

# Both_edges' falling flops as one port, falling, whose width goes to powerup.sv as
# FALLING_BITS: the clear reaches them at the first falling edge, not the first edge
set falling [wires {t:$dff r:CLK_POLARITY=1'0 %i %co:+[Q] w:* %i}]
set falling_bits [gather falling $falling]
# and the clear, which holds from the first edge to the second, and the copy a cycle late
# that the falling flops take, set from the first edge on
gather reset_done [wires w:core.top.reset_done]
gather clear_late [wires w:core.top.both_edges.clear_late]

yosys select -set ports o:*
set flops [list w:* w:core.top.engines.engine_?.rx.* w:core.top.engines.engine_?.tx.* %u]
foreach field [concat $stamps $fields $falling] { lappend flops w:[lindex $field 0] %u }
yosys expose -dff {*}$flops %d
set bits [gather state [wires {o:* @ports %d}]]

yosys cd ..
yosys read -define STATE_BITS=$bits -define FALLING_BITS=$falling_bits
