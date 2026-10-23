# One clock, and every pin but clk read by one two-flop synchroniser, on the flattened
# design rtl.ys or gate.ys leaves; the frame pad and the pad after it, D-, each picked
# among the pads by a flop's mux, by one on each edge, each Both_edges' falling pair a
# falling flop in the RTL and a rising one behind an inverter in the netlist. So a late pad edge can unsettle only the first
# stage, which nothing but the second reads, and it settles to a value the pad held
# steady would give: one the proofs' free pins already take. rst_n's release, read the
# same way, only moves by a cycle.
#
# Premises: a flop settles within a clock period; rst_n stays low for two edges, as its
# assertion reaches the cleared flops' D mid-cycle, which can also garble a macro write in
# flight, so reset only at power-on. A failed check is the last named in the log.

yosys -import

techmap
splitnets -ports -format __

# a check: the selection holds count cells and wires
proc require {what count selection} {
  log "sync: $what"
  select -assert-count $count {*}$selection
}

proc name {name selection} {
  select -set $name {*}$selection
}

log "sync: no combinational loop or undriven net"
check -assert

# flops, latches, macros and any cell not a gate
name seq {t:* t:$_*_ %d t:$_*DFF* %u t:$_DLATCH* %u t:$_SR_* %u}
require "no latch" 0 {t:$_DLATCH* t:$_SR_* %u}
proc falling_pair {instance} {
  return "w:core.top.$instance.signal_reg w:core.top.$instance.signal_reg_1 %u \
    %ci6:+\[Q\] @seq %i"
}
name falling_frame [falling_pair both_edges]
name falling_dm [falling_pair both_edges_1]
require "the frame pad's falling pair is two flops" 2 {@falling_frame}
require "D-'s falling pair is two flops" 2 {@falling_dm}
name falling {@falling_frame @falling_dm %u}
require "and the two pairs are four" 4 {@falling}
require "every other flop takes the rising edge, with at most an asynchronous reset" 0 \
  {t:$_*DFF* t:$_DFF_P_ %d t:$_DFF_P??_ %d @falling %d}
require "the pins are clk, ena, rst_n, ui_in and uio_in" 19 {i:*}

name clock_cone {t:$_DFF_P* %ci:+[C] t:RM_* %ci:+[A_CLK] %u @seq %d %cie*}
require "one pin reaches the clock pins" 1 {@clock_cone i:* %i}
require "the clock is clk" 1 {@clock_cone w:clk %i}
require "no flop or macro drives a clock" 0 {@clock_cone %ci @seq %i}
name falling_inverters {@falling %ci*:+[C,Y,A] t:$_NOT_ %i}
require "the pairs fall: a falling flop, or a rising one behind an inverter" 4 \
  {@falling t:$_DFF_N* %i @falling_inverters %co*:+[Y,A,C] @falling %i %u}
require "no gate but a buffer on the clock, or the falling pairs' inverters" 0 \
  {@clock_cone t:* %i t:$_BUF_ %d @falling_inverters %d}
require "the inverters clock nothing else" 0 \
  {@falling_inverters %co*:+[Y,A,C] @seq %i @falling %d}
require "every flop clocked" 0 {t:$_DFF_P* t:$_DFF_N* %u w:clk %coe* %co:+[C] %d}
require "clk reaches nothing but clock pins" 0 {w:clk %coe* %co:-[C,A_CLK] @seq %i w:clk %coe* o:* %i %u}
require "the macro test clocks are tied off" 0 \
  {t:RM_* %ci:+[A_BIST_CLK] t:RM_* %d %cie* i:* %i t:RM_* %ci:+[A_BIST_CLK] t:RM_* %d %cie* %ci @seq %i %u}

require "ena reaches nothing" 0 {w:ena %coe* %co @seq %i w:ena %coe* o:* %i %u}

# rst_n clears two flops at once and lets them go one edge apart; the second is the
# clear everything else takes on a clock edge
name reset_cone {w:rst_n %coe*}
name reset_flops {@reset_cone %co @seq %i}
require "rst_n reaches two flops" 2 {@reset_flops}
require "rst_n reaches their reset pins alone" 0 {@reset_cone %co:-[R] @seq %i @reset_cone o:* %i %u}
require "their reset pins see rst_n alone" 1 {@reset_flops %ci:+[R] @reset_flops %d %cie* i:* %i}
name reset_d {@reset_flops %ci:+[D] @reset_flops %d %cie*}
require "no pin reaches their D" 0 {@reset_d i:* %i}
name reset_first {@reset_d %ci @seq %i}
require "their D pins see one of the two" 1 {@reset_first @reset_flops %i}
require "and nothing else" 1 {@reset_first}
require "the first has a constant D" 0 {@reset_first %ci:+[D] @reset_first %d %cie* %ci @seq %i}
name reset_first_q {@reset_first %co:+[Q] @reset_first %d %coe*}
require "the first reaches the second alone" 1 \
  {@reset_first_q %co @seq %i @reset_flops @reset_first %d %i}
require "and only its D" 0 \
  {@reset_first_q %co @seq %i @reset_flops @reset_first %d %d @reset_first_q %co:-[D] @seq %i %u}
# other flops may take the second as an asynchronous reset too, which lets them go on the
# edge the clear does
name reset_second {@reset_flops @reset_first %d}
name other_reset {t:$_DFF_P* %ci:+[R] @seq %d @reset_cone %d %cie*}
require "no pin reaches another flop by its asynchronous reset" 0 {@other_reset i:* %i}
require "nor any flop but the second" 0 {@other_reset %ci @seq %i @reset_second %d}

# the two picks' first flops, which every pad they pick from reaches
name frame_first {w:ui_in_3_ %coe* %co @seq %i w:uio_in_0_ %coe* %co @seq %i %i}
require "the frame and D- picks reach four first flops" 4 {@frame_first}
require "the frame pick's one on the falling edge" 1 {@frame_first @falling_frame %i}
require "D-'s one on the falling edge" 1 {@frame_first @falling_dm %i}
require "and two on the rising edge" 2 {@frame_first @falling %d}
name frame_q {@frame_first %co:+[Q] @frame_first %d %coe*}
require "the picks' first stages reach no output" 0 {@frame_q o:* %i}
require "each reaches one flop" 4 {@frame_q %co @seq %i}
require "their D alone" 0 {@frame_q %co:-[D] @seq %i}
require "and not themselves" 0 {@frame_q %co @frame_first %i}

foreach pad [list {*}[lmap i {0 1 2 3 4 5 6 7} {string cat ui_in_ $i _}] \
               {*}[lmap i {0 1 2 3 4 5 6 7} {string cat uio_in_ $i _}]] {
  name cone "w:$pad %coe*"
  require "$pad reaches no output" 0 {@cone o:* %i}
  name first {@cone %co @seq %i @frame_first %d}
  require "$pad reaches one flop" 1 {@first}
  require "$pad reaches its D alone" 0 {@cone %co:-[D] @seq %i}
  require "no other pin enters its D" 1 {@first %ci:+[D] @first %d %cie* i:* %i}
  name q {@first %co:+[Q] @first %d %coe*}
  require "$pad first stage reaches no output" 0 {@q o:* %i}
  require "$pad first stage reaches one flop" 1 {@q %co @seq %i}
  require "its D alone" 0 {@q %co:-[D] @seq %i}
  require "and not itself" 0 {@q %co @first %i}
}
log "sync: all pass"
