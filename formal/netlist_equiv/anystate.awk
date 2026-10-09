# A miter of fine.ys from any state: every flop starts free, an input of its own in the
# first cycle. The reset input -v reset is asserted then (-v high=1 if active high) and
# free after; the trigger counts from the second cycle. With -v fifos=1 the host fifos'
# words and read buffers, which have no reset, load a free value at the first edge, one
# per name on both sides (powerup's havoc task proves the RTL with them free); finding
# none fails. Asynchronous resets act in their cycle, as in aig.ys. Read the file twice,
# awk -f anystate.awk m.il m.il: the first pass finds the flops and their nets' names.

# side.name [bit], or for the netlist's one-bit nets side.name[bit], as name|bit
function key(sig, side,    name, bit) {
  name = substr(sig, length(side) + 3)
  bit = 0
  if (match(name, / \[[0-9]+\]$/)) {
    bit = substr(name, RSTART + 2, RLENGTH - 3)
    name = substr(name, 1, RSTART - 1)
  } else if (side == "gate" && match(name, /\[[0-9]+\]$/)) {
    bit = substr(name, RSTART + 1, RLENGTH - 2)
    name = substr(name, 1, RSTART - 1)
  }
  return name "|" bit
}

function fifo(k) { return k ~ FIFO }

BEGIN {
  FIFO = "\\.(rx|tx)\\.(signal_multiport_mem\\[[0-9]+\\]|ram_rbw_data|data_before_collision|collision)\\|"
}

NR == FNR {
  if ($1 == "wire") {
    for (f = 2; f < NF; f++)
      if (($f == "input" || $f == "output") && $(f + 1) > ports) ports = $(f + 1)
  } else if ($1 == "cell") {
    cell = $3
    if ($2 ~ /^\$_DFF_/) {
      if ($2 !~ /^\$_DFF_P(_|[PN][01]_)$/) {
        print "anystate.awk: flop type " $2 " not handled" > "/dev/stderr"
        exit 1
      }
      index_of[cell] = ++ffs
      type[ffs] = $2
    }
  } else if ($1 == "end") {
    cell = ""
  } else if ($1 == "connect" && cell in index_of && $2 == "\\Q") {
    q[index_of[cell]] = substr($0, index($0, "\\Q ") + 3)
  } else if ($1 == "connect" && cell == "" && NF == 3) {
    alias[$2] = alias[$2] " " $3
    alias[$3] = alias[$3] " " $2
  }
  next
}

FNR == 1 {
  for (k = 1; k <= ffs; k++) {
    side = index(q[k], "\\gold.") == 1 ? "gold" : index(q[k], "\\gate.") == 1 ? "gate" : ""
    if (side == "") continue
    count = split(alias[q[k]], names, " ")
    names[0] = q[k]
    for (m = 0; m <= count; m++) {
      if (!fifos || index(names[m], "\\" side ".") != 1 || !fifo(key(names[m], side))) continue
      name = key(names[m], side)
      if (!(name in havoc)) havoc[name] = ++havocs
      loads[k] = havoc[name]
      seen[name] = seen[name] " " side
      break
    }
  }
  for (name in seen) if (seen[name] ~ /gold/ && seen[name] ~ /gate/) shared++
  printf "anystate.awk: %d flops, %d fifo flop bits on both sides\n", ffs, shared > "/dev/stderr"
  if (fifos && !shared) exit 1
}

/^module / {
  print
  for (k = 1; k <= ffs; k++) {
    printf "  wire input %d \\anystate.start_%d\n", ++ports, k
    printf "  wire \\anystate.held_%d\n  wire \\anystate.from_%d\n", k, k
    printf "  wire \\anystate.next_%d\n  wire \\anystate.cleared_%d\n", k, k
  }
  for (k = 1; k <= havocs; k++) printf "  wire input %d \\anystate.load_%d\n", ++ports, k
  print "  wire \\anystate.first\n  wire \\anystate.reset\n  wire \\anystate.differ"
  next
}

/^end$/ {
  print "  cell $initstate \\anystate.initstate\n    connect \\Y \\anystate.first\n  end"
  printf "  cell %s \\anystate.reset_mux\n    connect \\A \\%s\n", high ? "$_OR_" : "$_ANDNOT_", reset
  print "    connect \\B \\anystate.first\n    connect \\Y \\anystate.reset\n  end"
  print "  cell $_ANDNOT_ \\anystate.masked\n    connect \\A \\anystate.differ"
  print "    connect \\B \\anystate.first\n    connect \\Y \\trigger\n  end"
  print
  next
}

$1 == "wire" { print; next }

{
  for (f = 2; f <= NF; f++) if ($f == "\\" reset) $f = "\\anystate.reset"
  sub(/\\trigger$/, "\\anystate.differ")
}

$1 == "cell" && $3 in index_of {
  n = index_of[$3]
  sub(/\$_DFF_P[PN][01]_/, "$_DFF_P_")
  print
  next
}

n && $1 == "connect" && $2 == "\\R" { arst[n] = substr($0, index($0, "\\R ") + 3); next }
n && $1 == "connect" && $2 == "\\D" { d[n] = substr($0, index($0, "\\D ") + 3); next }
n && $1 == "connect" && $2 == "\\Q" { next }

# Y = S ? B : A
function mux(name, a, b, s, y) {
  printf "  cell $_MUX_ \\anystate.%s_mux_%d\n    connect \\A %s\n    connect \\B %s\n", name, n, a, b
  printf "    connect \\S %s\n    connect \\Y %s\n  end\n", s, y
}

n && $1 == "end" {
  printf "    connect \\D \\anystate.next_%d\n    connect \\Q \\anystate.held_%d\n  end\n", n, n
  from = "\\anystate.from_" n
  mux("start", "\\anystate.held_" n, "\\anystate.start_" n, "\\anystate.first", from)
  next_value = d[n]
  if (type[n] == "$_DFF_P_") {
    printf "  connect %s %s\n", q[n], from
  } else {
    # the reset wins over the start value and the next value alike
    value = substr(type[n], 9, 1) == "1" ? "1'1" : "1'0"
    low = substr(type[n], 8, 1) == "N"
    mux("reset_q", low ? value : from, low ? from : value, arst[n], q[n])
    next_value = "\\anystate.cleared_" n
    mux("reset_d", low ? value : d[n], low ? d[n] : value, arst[n], next_value)
  }
  if (n in loads)
    mux("load", next_value, "\\anystate.load_" loads[n], "\\anystate.first", "\\anystate.next_" n)
  else
    printf "  connect \\anystate.next_%d %s\n", n, next_value
  n = 0
  next
}

{ print }
