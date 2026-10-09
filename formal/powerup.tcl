# The chip's flops as ports for powerup.sv's invariant: each host fifo as one port named
# for it (flops.tcl); every other flop as one port, state, whose width goes to powerup.sv
# as STATE_BITS. The engines' start inputs and three of their flops come out too, the
# flops staying in state.

source flops.tcl
yosys cd tt_um_marcosash_protocol_emulator

foreach {fifo port} {engine_0.rx rx_0 engine_0.tx tx_0 engine_1.rx rx_1 engine_1.tx tx_1} {
  gather_fifo core.top.engines.$fifo $port
}

# each engine's start input, and its halted, start and refill flops, engine 0's first
foreach {port name} {start start halted halted started start_0 refill refill} {
  gather $port [concat [wires w:core.top.engines.engine_0.$name] \
    [wires w:core.top.engines.engine_1.$name]]
}

yosys select -set ports o:*
yosys expose -dff w:* w:core.top.engines.engine_?.rx.* w:core.top.engines.engine_?.tx.* %u %d
set bits [gather state [wires {o:* @ports %d}]]

yosys cd ..
yosys read -define STATE_BITS=$bits
