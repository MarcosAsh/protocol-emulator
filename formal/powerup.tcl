# The chip's flops as ports for powerup.sv's invariant: each host fifo as one port named
# for it (flops.tcl); every other flop as one port, state, whose width goes to powerup.sv
# as STATE_BITS.

source flops.tcl
yosys cd tt_um_marcosash_protocol_emulator

foreach {fifo port} {engine_0.rx rx_0 engine_0.tx tx_0 engine_1.rx rx_1 engine_1.tx tx_1} {
  gather_fifo core.top.engines.$fifo $port
}

yosys select -set ports o:*
yosys expose -dff w:* w:core.top.engines.engine_?.rx.* w:core.top.engines.engine_?.tx.* %u %d
set bits [gather state [wires {o:* @ports %d}]]

yosys cd ..
yosys read -define STATE_BITS=$bits
