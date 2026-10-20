# A teeth mutant: a flop with no reset that holds its power-up value, ORed into the net
# named by -v net. From all flops 0 it never changes the net, so netlist_equiv still
# proves the copy equal to the RTL; from any state it does. Every statement in a netlist
# ends in a semicolon, so records split there. Fails when no cell drives the net.

function splice(s, from, to,    i) {
  i = index(s, from)
  return substr(s, 1, i - 1) to substr(s, i + length(from))
}

BEGIN { RS = ";" }

{
  record = $0
  if (!declared && record ~ /^\n+ *wire /) {
    record = "\n wire stuck_in;\n wire stuck_q;\n wire stuck_high;" record
    declared = 1
  }
  if (!cut && (index(record, ".X(" net ")") || index(record, ".Y(" net ")"))) {
    if (index(record, ".X(" net ")")) record = splice(record, ".X(" net ")", ".X(stuck_in)")
    else record = splice(record, ".Y(" net ")", ".Y(stuck_in)")
    cut = 1
  }
  if (record ~ /\n *endmodule/) {
    sub(/\n *endmodule/, "\n sg13cmos5l_tiehi stuck_tie (.L_HI(stuck_high));" \
      "\n sg13cmos5l_dfrbpq_1 stuck (.RESET_B(stuck_high), .D(stuck_q), .Q(stuck_q), .CLK(clk));" \
      "\n sg13cmos5l_or2_1 stuck_or (.A(stuck_in), .B(stuck_q), .X(" net "));\nendmodule", record)
  }
  if (NR > 1) printf "%s;", held
  held = record
}

END {
  printf "%s", held
  if (!cut || !declared) {
    print "stuck.awk: no cell drives " net > "/dev/stderr"
    exit 1
  }
}
