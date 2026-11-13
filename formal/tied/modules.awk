# awk -f modules.awk CHIP COPY: for each module of COPY, "same" if CHIP has it word for
# word, "differs" if CHIP's is another text, "only" if CHIP has none, then its name.
FNR == 1 { file++ }
/^module / { name = $2; text = ""; on = 1 }
on { text = text $0 "\n" }
on && /^endmodule/ {
  on = 0
  if (file == 1) chip[name] = text
  else { order[++n] = name; copy[name] = text }
}
END {
  for (i = 1; i <= n; i++) {
    m = order[i]
    print (!(m in chip) ? "only" : chip[m] == copy[m] ? "same" : "differs"), m
  }
}
