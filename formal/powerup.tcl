# The chip's flops as ports for powerup.sv's invariant, on the flattened chip with its
# fifos' memories mapped to flops: each host fifo's fields as one port named for it, in
# the order of fifo_t there, first field last; every other flop as one port, state, whose
# width goes to powerup.sv as STATE_BITS.

yosys cd tt_um_marcosash_protocol_emulator

# each wire the selection holds, as {name width}
proc wires {selection} {
  set found {}
  foreach line [split [yosys tee -q -s result.string dump {*}$selection] "\n"] {
    if {[regexp {^\s*wire (?:width (\d+) )?.*\\(\S+)$} $line -> width name]} {
      lappend found [list $name [expr {$width eq "" ? 1 : $width}]]
    }
  }
  return $found
}

# a new output port holding the wires, the first at bit 0; returns its width
proc gather {port wires} {
  set bits 0
  foreach wire $wires {
    lassign $wire name width
    lappend parts [list $bits $width $name]
    incr bits $width
  }
  yosys add -output $port $bits
  foreach part $parts {
    lassign $part low width name
    yosys connect -set $port\[[expr {$low + $width - 1}]:$low\] \\$name
  }
  return $bits
}

foreach {fifo port} {engine_0.rx rx_0 engine_0.tx tx_0 engine_1.rx rx_1 engine_1.tx tx_1} {
  set path core.top.engines.$fifo
  for {set n 0} {$n < 8} {incr n} {
    yosys rename $path.signal_multiport_mem\[$n\] $path.word_$n
  }
  set fields {}
  foreach wire {
    USED USED_PLUS_1 USED_MINUS_1 READ_ADDRESS WRITE_ADDRESS used_is_one used_gt_one
    not_empty nearly_full full_0 collision signal_reg ram_rbw_data data_before_collision
    word_0 word_1 word_2 word_3 word_4 word_5 word_6 word_7
  } {
    lappend fields {*}[wires w:$path.$wire]
  }
  gather $port $fields
}

yosys select -set ports o:*
yosys expose -dff w:* w:core.top.engines.engine_?.rx.* w:core.top.engines.engine_?.tx.* %u %d
set bits [gather state [wires {o:* @ports %d}]]

yosys cd ..
yosys read -define STATE_BITS=$bits
