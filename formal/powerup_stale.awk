# Teeth mutant: revert the fix for an empty rx fifo's stale head, so rx_head is the fifo's
# head again. Reads the RTL twice, awk -f powerup_stale.awk rtl.v rtl.v. The first pass
# finds the head behind the fix's mux, the second puts it back. Fails if there is no fix.

NR == FNR {
  if ($1 == "assign" && $2 == "rx_head_0") head = $NF
  next
}

$1 == "assign" && $2 == "rx_head" && $4 == "rx_head_0;" && head {
  sub(/rx_head_0;/, head)
  cut = 1
}

{ print }

END {
  if (!cut) {
    print "powerup_stale.awk: no fix to revert" > "/dev/stderr"
    exit 1
  }
}
