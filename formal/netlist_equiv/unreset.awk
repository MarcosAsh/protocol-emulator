# Teeth mutant: the first flop whose RESET_B is the net the rst_n buffer drives loses its
# reset (the pin is tied high). That flop is one of the reset synchroniser's two, so the
# copy only differs from the RTL around a reset, which it enters a cycle late or leaves a
# cycle early, and ABC has to find a trace of many cycles. Reads the netlist twice,
# awk -f unreset.awk n.v n.v. The first pass finds the buffer, the second edits. Every
# statement in a netlist ends in a semicolon, so records split there. Fails if no flop
# takes its reset from a buffer on rst_n, because the copy would not be a mutant.

function splice(s, from, to,    i) {
  i = index(s, from)
  return substr(s, 1, i - 1) to substr(s, i + length(from))
}

BEGIN { RS = ";" }

NR == FNR {
  if (net == "" && index($0, ".A(rst_n)") && match($0, /\.X\([^)]*\)/))
    net = substr($0, RSTART + 3, RLENGTH - 4)
  next
}

{
  record = $0
  if (net != "" && !cut && index(record, ".RESET_B(" net ")")) {
    record = splice(record, ".RESET_B(" net ")", ".RESET_B(1'b1)")
    cut = 1
  }
  if (FNR > 1) printf "%s;", held
  held = record
}

END {
  printf "%s", held
  if (!cut) {
    print "unreset.awk: no flop takes its reset from a buffer on rst_n" > "/dev/stderr"
    exit 1
  }
}
