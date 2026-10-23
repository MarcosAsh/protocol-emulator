# Engine 0's flops as ports for isolation.sv's invariant, on the flattened engines_top: its
# fifos as rx_0 and tx_0 (flops.tcl); every other flop of engine 0 but the ones the script
# brought out already, the data memory's turn, the checker's turn and engine 0's ask
# waiting for it, and engine 0's premises, as state_0, whose width goes to isolation.sv as
# STATE_BITS; and the frame receivers' flops as receivers, RECEIVER_BITS wide.

source flops.tcl
yosys cd engines_top

gather_fifo engines.engine_0.rx rx_0
gather_fifo engines.engine_0.tx tx_0

set flops [list w:engines.engine_0.*]
foreach wire [aliases engines.data_memory.turn] { lappend flops w:$wire %u }
# the checker's turn, the flops themselves, and engine 0's ask waiting for it
lappend flops w:engines.turn_cycle %u w:engines.chosen %u
foreach wire [aliases {engines.waiting$0}] { lappend flops w:$wire %u }
# and the premises engine 0's check was taken under, held beside the engines
foreach port {
  premises$period$valid premises$period$value premises$floor premises$single_edge
} {
  foreach wire [aliases engines.engine_0.$port] { lappend flops w:$wire %u }
}
lappend flops w:engines.engine_0.rx.* %d w:engines.engine_0.tx.* %d
foreach port {pins_sampled_0 started_0} {
  foreach wire [aliases $port] { lappend flops w:$wire %d }
}

yosys select -set ports o:*
yosys expose -dff {*}$flops
set bits [gather state_0 [wires {o:* @ports %d}]]

yosys select -set ports o:*
yosys expose -dff w:engines.frame_rx.* w:engines.usb_frame_rx.*
set receiver_bits [gather receivers [wires {o:* @ports %d}]]

yosys cd ..
yosys read -define STATE_BITS=$bits
yosys read -define RECEIVER_BITS=$receiver_bits
