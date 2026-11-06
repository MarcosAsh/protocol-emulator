# Turns the chip's flops into ports for powerup.sv's invariant. Each host fifo and the edge
# stamps become one port named for them (flops.tcl). The load checker's state and the flops
# it keeps without a clear become one port, load_checker. Every other flop goes in one
# port, state, whose width goes to powerup.sv as STATE_BITS. The engines' start inputs,
# three of their flops and the load checker's lending also come out, but the flops stay
# in state.

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

# the classes the load checker registers from its word, as one port, word_class (width
# goes to powerup.sv as WORD_CLASS_BITS). They follow the word, so they agree once it does.
set word_class [wires w:core.top.engines.load_checker.word_class*]
set word_class_bits [gather word_class $word_class]

# Both_edges' falling flops as one port, falling (width goes to powerup.sv as
# FALLING_BITS). The clear reaches them at the first falling edge, not the first edge
set falling [wires {t:$dff r:CLK_POLARITY=1'0 %i %co:+[Q] w:* %i}]
set falling_bits [gather falling $falling]
# and the clear, which holds from the first edge to the second, and the flop a cycle behind
# it whose inverse clears the falling flops
gather reset_done [wires w:core.top.reset_done]
gather reset_late [wires w:core.top.reset_late]

# each engine's start input, and its halted, start and refill flops, engine 0's first
foreach {port name} {start start halted halted started start_0 refill refill} {
  gather $port [concat [wires w:core.top.engines.engine_0.$name] \
    [wires w:core.top.engines.engine_1.$name]]
}
# and whether the load checker holds each engine's program port, engine 0's first
gather lent [concat [wires w:core.top.engines.lent\$0] [wires w:core.top.engines.lent\$1]]

yosys select -set ports o:*
set flops [list w:* w:core.top.engines.engine_?.rx.* w:core.top.engines.engine_?.tx.* %u]
foreach field [concat $stamps $fields $word_class $falling] { lappend flops w:[lindex $field 0] %u }
yosys expose -dff {*}$flops %d
set bits [gather state [wires {o:* @ports %d}]]

yosys cd ..
yosys read -define STATE_BITS=$bits -define FALLING_BITS=$falling_bits \
  -define WORD_CLASS_BITS=$word_class_bits
