# Turns flops into ports for the two-copy miters. Works on a flattened design whose fifo
# memories are already mapped to flops.

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

# other names for wire's flop, from the module's own connects
proc aliases {wire} {
  set found {}
  foreach line [split [yosys tee -q -s result.string dump] "\n"] {
    if {[regexp {^  connect \\(\S+) \\(\S+)$} $line -> lhs rhs]} {
      if {$lhs eq $wire} { lappend found $rhs }
      if {$rhs eq $wire} { lappend found $lhs }
    }
  }
  return $found
}

# adds an output port holding the wires (the first at bit 0) and returns its width
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

# gathers the fifo at path (words words deep) into one port, with its fields in the order
# of fifo_t in pairs.sv, first field last. full is Hardcaml's full flop, or full_0 where
# the owner has a full of its own. Returns the wires.
proc gather_fifo {path port {words 16} {full full_0}} {
  set names {}
  for {set n 0} {$n < $words} {incr n} {
    yosys rename $path.signal_multiport_mem\[$n\] $path.word_$n
    lappend names word_$n
  }
  set fields {}
  foreach wire [list \
    USED USED_PLUS_1 USED_MINUS_1 READ_ADDRESS WRITE_ADDRESS used_is_one used_gt_one \
    not_empty nearly_full $full collision signal_reg ram_rbw_data data_before_collision \
    {*}$names] {
    lappend fields {*}[wires w:$path.$wire]
  }
  gather $port $fields
  return $fields
}
