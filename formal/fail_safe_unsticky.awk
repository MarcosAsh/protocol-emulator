# Teeth mutant: the fault flop (the register an engine's faulted reads) only holds for the
# cycle after its condition, so it is no longer sticky. Reads the RTL twice, awk -f
# fail_safe_unsticky.awk rtl.v rtl.v. The first pass finds the register and its module. The
# second loads it with its condition every cycle, holding a line back so the if can go.
# Fails if the register isn't set that way.

$1 == "module" { module = $2 }

NR == FNR {
  if ($1 == "assign" && $2 == "faulted") {
    register = substr($4, 1, length($4) - 1)
    home = module
  }
  next
}

!cut && module == home && $1 == register && $2 == "<=" && $3 == "vdd;" && held \
  && line ~ /^ *if \(.*\)$/ {
  condition = line
  sub(/^ *if \(/, "", condition)
  sub(/\)$/, "", condition)
  sub(/vdd;/, condition ";")
  held = 0
  cut = 1
}

{
  if (held) print line
  line = $0
  held = 1
}

END {
  if (held) print line
  if (!cut) {
    print "fail_safe_unsticky.awk: no sticky fault flop" > "/dev/stderr"
    exit 1
  }
}
