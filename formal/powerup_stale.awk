# A teeth mutant: the fix for an empty rx fifo's stale head reverted, rx_head the fifo's
# head again. The RTL is read twice, awk -f powerup_stale.awk rtl.v rtl.v: the first pass
# finds the head behind the fix's mux, the second puts it back. Fails when there is no fix.

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
