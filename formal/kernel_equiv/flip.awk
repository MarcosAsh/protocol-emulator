# Tooth: invert the first input of the and gate that drives the first output. Fails if that
# output is an input or a constant, because the copy would not be a mutant.

NR == 1 { inputs = $3; target = -1 }
NR == inputs + 2 { target = $1 - $1 % 2 }
target > 1 && $1 == target && NF == 3 && !flipped { $2 = $2 - $2 % 2 + 1 - $2 % 2; flipped = 1 }
{ print }
END {
  if (!flipped) {
    print "flip.awk: no and gate drives the first output" > "/dev/stderr"
    exit 1
  }
}
