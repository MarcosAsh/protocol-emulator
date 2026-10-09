# A teeth mutant: the underflow fault, the register fault$underflow reads, holds only the
# cycle after its condition, so it is no longer sticky. The RTL is read twice, awk -f
# fail_safe_unsticky.awk rtl.v rtl.v: the first pass finds the register and its module, the
# second loads it with its condition every cycle, a line held back so the if can go. Fails
# when the register is not set that way.

$1 == "module" { module = $2 }

NR == FNR {
  if ($1 == "assign" && $2 == "fault$underflow") {
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
    print "fail_safe_unsticky.awk: no sticky underflow register" > "/dev/stderr"
    exit 1
  }
}
