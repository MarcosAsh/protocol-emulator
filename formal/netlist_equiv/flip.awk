# A teeth mutant: the cell driving the net named by -v net turns into its inverse, a
# buffer into the inverter of the same drive and an inverter into the buffer. Every
# statement in a netlist ends in a semicolon, so records split there. Fails when no
# buffer or inverter drives the net, since the copy would then be no mutant.

function splice(s, from, to,    i) {
  i = index(s, from)
  return substr(s, 1, i - 1) to substr(s, i + length(from))
}

BEGIN { RS = ";" }

{
  record = $0
  if (!flipped && index(record, ".X(" net ")") && sub(/ sg13cmos5l_buf_/, " sg13cmos5l_inv_", record)) {
    record = splice(record, ".X(" net ")", ".Y(" net ")")
    flipped = 1
  } else if (!flipped && index(record, ".Y(" net ")") && sub(/ sg13cmos5l_inv_/, " sg13cmos5l_buf_", record)) {
    record = splice(record, ".Y(" net ")", ".X(" net ")")
    flipped = 1
  }
  if (NR > 1) printf "%s;", held
  held = record
}

END {
  printf "%s", held
  if (!flipped) {
    print "flip.awk: no buffer or inverter drives " net > "/dev/stderr"
    exit 1
  }
}
