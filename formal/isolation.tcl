# Engine 0's flops as ports for isolation.sv's invariant, on the flattened engines_top: its
# fifos as rx_0 and tx_0 (flops.tcl); every other flop of engine 0 but the ones the script
# brought out already, and the data memory's turn, as state_0, whose width goes to
# isolation.sv as STATE_BITS.

source flops.tcl
yosys cd engines_top

gather_fifo engines.engine_0.rx rx_0
gather_fifo engines.engine_0.tx tx_0

set flops [list w:engines.engine_0.*]
foreach wire [aliases engines.data_memory.turn] { lappend flops w:$wire %u }
lappend flops w:engines.engine_0.rx.* %d w:engines.engine_0.tx.* %d
foreach port {pins_sampled_0 started_0} {
  foreach wire [aliases $port] { lappend flops w:$wire %d }
}

yosys select -set ports o:*
yosys expose -dff {*}$flops
set bits [gather state_0 [wires {o:* @ports %d}]]

yosys cd ..
yosys read -define STATE_BITS=$bits
