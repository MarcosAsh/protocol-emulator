# Teeth mutant: the engines' pin register (the one pin_out_0 reads) loses its clear. Reads
# the RTL twice, awk -f powerup_unreset.awk rtl.v rtl.v. The first pass finds the register
# and its module, the second drops the if and else of its reset branch, holding a line
# back so the if can go. Fails if there is no such branch.

$1 == "module" { module = $2 }

NR == FNR {
  if ($1 == "assign" && $2 == "pin_out_0") {
    register = substr($4, 1, length($4) - 1)
    home = module
  }
  next
}

!cut && module == home && $1 == register && $2 == "<=" && held && line ~ /^ *if \(/ {
  held = 0
  cut = 1
  next
}

cut == 1 && $1 == "else" {
  cut = 2
  next
}

{
  if (held) print line
  line = $0
  held = 1
}

END {
  if (held) print line
  if (cut != 2) {
    print "powerup_unreset.awk: no reset branch on the pin register" > "/dev/stderr"
    exit 1
  }
}
