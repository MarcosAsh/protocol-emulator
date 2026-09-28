# The two memories from all flops 0, for the scrambled tooth: it passes here, where only
# zero contents are asked about, and fails step.tcl. Writes zero.aig for ABC.

yosys -import

proc side {name files} {
  design -reset
  read_verilog -DFUNCTIONAL {*}$files
  script ../sram_equiv/side.ys
  design -stash $name
}

side flops [list $::env(FLOPS)]
side macro [list $::env(MACRO) $::env(MODEL) $::env(CORE)]
design -reset
design -copy-from flops -as flops memory_top
design -copy-from macro -as macro memory_top
miter -equiv -flatten flops macro miter
hierarchy -top miter
setattr -unset init
setundef -init -zero
techmap
aigmap
opt_clean -purge
write_aiger zero.aig
