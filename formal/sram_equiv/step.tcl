# The flop program memory the lemmas are proved on is IHP's behavioural model of the
# 512x16 macro, step for step: from the same state, any contents and any dout, and the
# same inputs, both show the same dout and step to the same state. So they agree for all
# time from any equal start. Writes step.aig for ABC; env: FLOPS, MACRO, MODEL, CORE.
#
# Premise: the model is the macro's function. Its FUNCTIONAL branch is read; the other
# only adds timing checks. Trusted: yosys's frontend, proc, memory_map, aigmap; ABC.

yosys -import

# One side as a function of its state, each word of the array named mem_i.
proc side {name files array} {
  design -reset
  read_verilog -DFUNCTIONAL {*}$files
  script ../sram_equiv/side.ys
  yosys cd memory_top
  for {set i 0} {$i < 512} {incr i} {
    yosys rename "$array\[$i\]" mem_$i
  }
  yosys cd ..
  script ../sram_equiv/evert.ys
  design -stash $name
}

side flops [list $::env(FLOPS)] program_memory.signal_multiport_mem
side macro [list $::env(MACRO) $::env(MODEL) $::env(CORE)] \
  sram_macro.sram.i_SRAM_1P_behavioral_bm_bist.memory
design -reset
script ../sram_equiv/miter.ys
