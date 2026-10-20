# A teeth mutant: the capture register stamped a cycle early, so the capture is two cycles
# old at mov t, capture. The RTL is read twice, awk -f capture_early.awk engine.v engine.v:
# the first pass finds the register behind capture, the second moves its stamp.

NR == FNR {
  if ($1 == "assign" && $2 == "capture_0") {
    held = $NF
    sub(/;$/, "", held)
  }
  next
}

held && $1 == held && $2 == "<=" && $3 == "now_0;" {
  sub(/now_0;/, "now_0 - 1'd1;")
  cut = 1
}

{ print }

END {
  if (!cut) {
    print "capture_early.awk: no capture register to move" > "/dev/stderr"
    exit 1
  }
}
