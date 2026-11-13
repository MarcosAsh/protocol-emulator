# awk -f direct.awk CHIP: a module direct with the chip's engines' ports, each wired
# straight to the same port of one engines instance, as engines_top should be
/^module engines \(/ { on = 1; print "module direct ("; next }
!on { next }
/^\);/ { print; next }
/^    (input|output) / {
  decls = decls $0 "\n"
  name = $NF
  sub(/;$/, "", name)
  conns = conns (conns == "" ? "" : ",\n") "    ." name "(" name ")"
  next
}
decls == "" { print; next }
{
  printf "%s  engines engines (\n%s);\nendmodule\n", decls, conns
  exit
}
