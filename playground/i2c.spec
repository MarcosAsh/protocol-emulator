# pico-examples pio/i2c (issue #796) at the 100 kHz pio_i2c.c sets on a 125 MHz clock,
# against UM10204 table 10, Standard-mode. scl is the side-set pin, sda the set pin; a
# slave may stretch scl. The exec lines are the START, RSTART and STOP sequences
# pio_i2c.c sends through out exec.
program i2c
pin sda=set0:dir,out0:dir,in0,jmp
pin scl=side0:dir,in1
init sda=1
init scl=1
autopull
autopush
irq-wait-halts
entry entry_point
no-stretch sda
exec x=2,scl=1,sda=1: set pindirs, 0 side 1 [7] | set pindirs, 0 side 0 [7] | mov isr, null
exec x=2,scl=0: set pindirs, 0 side 0 [7] | set pindirs, 0 side 1 [7] | set pindirs, 1 side 1 [7]
exec x=4,scl=0: set pindirs, 1 side 0 [7] | set pindirs, 1 side 1 [7] | set pindirs, 0 side 1 [7] | set pindirs, 0 side 0 [7] | mov isr, null
sys-hz 125e6
clkdiv 39.0625
rule t_low: scl- -> scl+ >= 4.7us
rule t_high: scl+ -> scl- >= 4.0us
rule t_hd_sta: sda- -> scl- >= 4.0us
rule t_su_sta: scl+ -> sda- >= 4.7us
rule t_su_sto: scl+ -> sda+ >= 4.0us
rule t_su_dat: sda -> scl+ >= 250ns
