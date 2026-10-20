# The miter of miter.ys from the Icepi's configured state: the netlist's flops at their
# REGSET values and its RAMs at INITVAL, as the bitstream loads them, against the RTL from
# all 0 (its initial values dropped). The PLL holds LOCK low, so rst_n too, until the
# first edge of CLKOS has passed, and the trigger counts from the second cycle.

function cell(type, name, a, b, y) {
  printf "  cell %s %s\n", type, name
  printf "    parameter \\A_SIGNED 0\n    parameter \\B_SIGNED 0\n"
  printf "    parameter \\A_WIDTH 1\n    parameter \\B_WIDTH 1\n    parameter \\Y_WIDTH 1\n"
  printf "    connect \\A %s\n    connect \\B %s\n    connect \\Y %s\n  end\n", a, b, y
}

# the RTL's initial values go; an attribute line waits for the wire or cell it is on
/^ *attribute / {
  held = held $0 "\n"
  next
}

$1 == "wire" && $NF ~ /^\\gold\./ {
  gsub(/ *attribute \\init [^\n]*\n/, "", held)
}

$1 == "wire" && $NF == "\\in_pll.LOCK" {
  sub(/\\in_pll\.LOCK$/, "\\lock_free")
  printf "%s%s\n  wire \\in_pll.LOCK\n", held, $0
  held = ""
  found++
  next
}

$1 == "wire" && $NF == "\\trigger" {
  printf "%s%s\n  wire \\trigger_any\n", held, $0
  held = ""
  found++
  next
}

$1 == "connect" && $2 == "\\Y" && $3 == "\\trigger" {
  $3 = "\\trigger_any"
  $0 = "    " $0
  found++
}

$0 == "end" {
  print "  wire \\started"
  print "  cell $dff \\started_ff"
  print "    parameter \\WIDTH 1\n    parameter \\CLK_POLARITY 1"
  print "    connect \\CLK \\in_pll.CLKOS\n    connect \\D 1'1\n    connect \\Q \\started\n  end"
  cell("$and", "\\lock_held", "\\lock_free", "\\started", "\\in_pll.LOCK")
  cell("$and", "\\trigger_late", "\\trigger_any", "\\started", "\\trigger")
}

{
  printf "%s%s\n", held, $0
  held = ""
}

END {
  if (found != 3) {
    print "configured.awk: no miter of miter.ys" > "/dev/stderr"
    exit 1
  }
}
