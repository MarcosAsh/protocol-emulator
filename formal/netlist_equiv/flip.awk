# Teeth mutant: replace the cell driving the net named by -v net with its inverse, same
# drive and inputs: buffer <-> inverter, and <-> nand, or <-> nor, a21o <-> a21oi,
# xor <-> xnor. Every statement in a netlist ends in a semicolon, so records split there.
# Fails if no such cell drives the net, because the copy would not be a mutant.

function splice(s, from, to,    i) {
  i = index(s, from)
  return substr(s, 1, i - 1) to substr(s, i + length(from))
}

BEGIN {
  RS = ";"
  # each pair is a cell that drives X and its inverse Y
  n = split("buf and2 and3 and4 or2 or3 or4 a21o xor2", plain, " ")
  split("inv nand2 nand3 nand4 nor2 nor3 nor4 a21oi xnor2", inverted, " ")
  for (i = 1; i <= n; i++) {
    inverse[plain[i]] = inverted[i]
    output[plain[i]] = "X"
    inverse[inverted[i]] = plain[i]
    output[inverted[i]] = "Y"
  }
}

{
  record = $0
  if (!flipped && match(record, / sg13cmos5l_[a-z0-9]+_[0-9]+ /)) {
    cell = substr(record, RSTART + 12, RLENGTH - 13)
    sub(/_[0-9]+$/, "", cell)
    if (cell in inverse && index(record, "." output[cell] "(" net ")")) {
      record = splice(record, " sg13cmos5l_" cell "_", " sg13cmos5l_" inverse[cell] "_")
      record = splice(record, "." output[cell] "(" net ")", "." output[inverse[cell]] "(" net ")")
      flipped = 1
    }
  }
  if (NR > 1) printf "%s;", held
  held = record
}

END {
  printf "%s", held
  if (!flipped) {
    print "flip.awk: no cell with an inverse drives " net > "/dev/stderr"
    exit 1
  }
}
