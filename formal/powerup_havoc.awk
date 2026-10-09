# The host fifos' words and read buffers, which have no reset, take any value while the
# fifo is cleared, a free one per edge, as anystate.awk lets them at the netlist's first
# edge. Reads the RTL, awk -f powerup_havoc.awk rtl.v; the havoc task proves powerup on
# the copy. Fails when it finds no fifo memory to scramble.

$1 == "module" { fifo = $2 == "host_fifo" }

# reg [w:0] signal_multiport_mem[0:d];
fifo && $1 == "reg" && $3 ~ /^signal_multiport_mem\[0:[0-9]+\];$/ {
  print
  width = substr($2, 2, index($2, ":") - 2) + 1
  depth = substr($3, index($3, ":") + 1) + 1
  printf "    (* anyseq *) wire [%d:0] havoc_words;\n", width * depth - 1
  printf "    (* anyseq *) wire [%d:0] havoc_written, havoc_read;\n", width - 1
  print "    (* anyseq *) wire havoc_collision;"
  next
}

fifo && $2 == "<=" && $1 == "data_before_collision" { sub(/<= /, "<= clear ? havoc_written : ") }
fifo && $2 == "<=" && $1 == "ram_rbw_data" { sub(/<= /, "<= clear ? havoc_read : ") }
fifo && $2 == "<=" && $1 == "collision" { sub(/<= /, "<= clear ? havoc_collision : ") }

# the write's if, held back a line to see whether the memory is what it writes
fifo && held != "" && $1 ~ /^signal_multiport_mem\[/ && $2 == "<=" {
  indent = substr(held, 1, match(held, /[^ ]/) - 1)
  print indent "if (clear) begin"
  for (n = 0; n < depth; n++)
    printf "%s    signal_multiport_mem[%d] <= havoc_words[%d:%d];\n", indent, n, (n + 1) * width - 1,
      n * width
  print indent "end else"
  scrambled = 1
}

{
  if (held != "") print held
  held = ""
  if (fifo && $1 == "if") { held = $0; next }
  print
}

END {
  if (held != "") print held
  if (!scrambled) {
    print "powerup_havoc.awk: no fifo memory to scramble" > "/dev/stderr"
    exit 1
  }
}
