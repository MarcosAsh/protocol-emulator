# Engine 0's flops as ports for isolation.sv's invariant, on the flattened engines_top: its
# fifos as rx_0 and tx_0 (flops.tcl); every other flop of engine 0 but the ones the script
# brought out already, the data memory's turn, the checker's turn and engine 0's ask
# waiting for it, engine 0's premises, certificate and verdict, as state_0, whose width
# goes to isolation.sv as STATE_BITS; the frame receivers' flops as receivers,
# RECEIVER_BITS wide; the load checker as powerup.tcl has it, load_checker and word_class,
# and its other flops as checker_flops, CHECKER_BITS wide; and the wires isolation.sv names.

source flops.tcl
yosys cd engines_top

# in the order of load_checker_t in pairs.sv, first field last
set fields {}
foreach wire {sm source k field word acc entry failed_next$* failed_target$* row$*} {
  lappend fields {*}[wires w:engines.load_checker.$wire]
}
gather load_checker $fields
set word_class [wires w:engines.load_checker.word_class*]
set word_class_bits [gather word_class $word_class]
yosys select -set ports o:*
set checker [list w:engines.load_checker.*]
foreach field [concat $fields $word_class] { lappend checker w:[lindex $field 0] %d }
yosys expose -dff {*}$checker
set checker_bits [gather checker_flops [wires {o:* @ports %d}]]

gather_fifo engines.engine_0.rx rx_0
gather_fifo engines.engine_0.tx tx_0

set flops [list w:engines.engine_0.*]
foreach wire [aliases engines.data_memory.turn] { lappend flops w:$wire %u }
# the checker's turn, the flops themselves, and engine 0's ask waiting for it
lappend flops w:engines.turn_cycle %u w:engines.chosen %u
foreach wire [aliases {engines.waiting$0}] { lappend flops w:$wire %u }
# engine 0's certificate, refusal and verdict, kept beside the engines
foreach reg {certified$0 refused$0 verdict$0$accepted verdict$0$reject_pc verdict$0$reason} {
  foreach wire [concat engines.$reg [aliases engines.$reg]] { lappend flops w:$wire %u }
}
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

foreach {port wire} {
  checking engines.checking checked engines.checked chosen engines.chosen
  turn_starts engines.turn_starts finished engines.load_checker.finished
  read_done engines.load_checker.read_done walk_span engines.load_checker.span
  walk_base engines.load_checker.setup$base_0 walk_reads engines.load_checker.read_valid
  walk_read_at engines.load_checker.read_at
} {
  gather $port [wires w:$wire]
}

yosys cd ..
yosys read -define STATE_BITS=$bits
yosys read -define RECEIVER_BITS=$receiver_bits
yosys read -define WORD_CLASS_BITS=$word_class_bits
yosys read -define CHECKER_BITS=$checker_bits
