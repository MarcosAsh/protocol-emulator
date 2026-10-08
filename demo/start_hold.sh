#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# The start hold act: Pico B masters the EEPROM bus through pico-examples' pio_i2c (pio) or
# its I2C block (hw), the chip stamps every START, Pico A judges the stamps against
# Standard-mode's 4.0 us. Before it, demo/pico_b.sh puts the master on Pico B, then
# pio_check's static bound on i2c.pio and, with PICO_B set to Pico B's tty, the clocks
# Pico B reports; after it, the analyser's own reading.
# Usage: PICO=id:<serial of Pico A> [PICO_B=/dev/ttyACM0] demo/start_hold.sh pio|hw
set -e
case $1 in
pio | hw) demo/pico_b.sh "start_hold_$1" ;;
esac
case $1 in
pio)
    echo "Pico B: start_hold_pio.uf2, pio_i2c as shipped"
    echo "static, pio_check on pico-examples' i2c.pio, 125 MHz over 39.0625:"
    dune build --root . pio/bin/pio_check.exe
    _build/default/pio/bin/pio_check.exe pio/test/pico_examples/i2c.pio -program i2c \
        -pin sda=set0:dir,out0:dir,in0,jmp -pin scl=side0:dir,in1 -init sda=1 -init scl=1 \
        -autopull -autopush -irq-wait-halts -entry entry_point -no-stretch sda \
        -exec "x=2,scl=1,sda=1: set pindirs, 0 side 1 [7] | set pindirs, 0 side 0 [7] | mov isr, null" \
        -exec "x=2,scl=0: set pindirs, 0 side 0 [7] | set pindirs, 0 side 1 [7] | set pindirs, 1 side 1 [7]" \
        -exec "x=4,scl=0: set pindirs, 1 side 0 [7] | set pindirs, 1 side 1 [7] | set pindirs, 0 side 1 [7] | set pindirs, 0 side 0 [7] | mov isr, null" \
        -sys-hz 125e6 -clkdiv 39.0625 -rule "t_hd_sta: sda- -> scl- >= 4.0us" | grep "^t_hd_sta"
    ;;
hw)
    echo "Pico B: start_hold_hw.uf2, the RP2040's I2C block"
    echo "static: none, it is not a PIO program"
    ;;
*)
    echo "usage: PICO=id:<serial of Pico A> [PICO_B=<tty>] $0 pio|hw" >&2
    exit 1
    ;;
esac
if [ -n "$PICO_B" ]; then
    stty -F "$PICO_B" raw -echo
    timeout 3 grep -a -m 1 "sys" "$PICO_B" || echo "Pico B printed nothing in 3 s" >&2
fi
# the decode lists every START, so runs of them are counted
out=$(mktemp)
trap 'rm -f "$out"' EXIT
status=0
demo/outside.sh start_hold > "$out" || status=$?
uniq -c "$out" | sed 's/^ *1 //'
[ "$status" -eq 0 ] || exit "$status"
python3 demo/start_hold.py "${CAPTURES:-.}/start_hold.sr"
