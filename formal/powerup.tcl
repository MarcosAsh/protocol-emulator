# The chip's flops as ports for powerup.sv's invariant: each host fifo as one port named
# for it (flops.tcl); the load checker's state and the flops it keeps without a clear as
# one port, load_checker; every other flop as one port, state, whose width goes to
# powerup.sv as STATE_BITS.

source flops.tcl
yosys cd tt_um_marcosash_protocol_emulator

foreach {fifo port} {engine_0.rx rx_0 engine_0.tx tx_0 engine_1.rx rx_1 engine_1.tx tx_1} {
  gather_fifo core.top.engines.$fifo $port
}

# in the order of load_checker_t in pairs.sv, first field last
set fields {}
foreach wire {sm source k field word acc entry failed_next$* failed_target$* row$*} {
  lappend fields {*}[wires w:core.top.engines.load_checker.$wire]
}
gather load_checker $fields

yosys select -set ports o:*
set flops [list w:* w:core.top.engines.engine_?.rx.* w:core.top.engines.engine_?.tx.* %u]
foreach field $fields { lappend flops w:[lindex $field 0] %u }
yosys expose -dff {*}$flops %d
set bits [gather state [wires {o:* @ports %d}]]

yosys cd ..
yosys read -define STATE_BITS=$bits
