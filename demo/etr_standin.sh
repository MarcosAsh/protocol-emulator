#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# python/demo_board.py on Pico A in place of the ETR board's RP2350B, through the ttboard
# stand-in python/etr_standin.py: the host port at 1/16, 1/12 and 1/8 of the chip's clock,
# then a reselect. Reset the chip first. Prints a line a check, then PASS or FAIL.
# Usage: PICO=id:<serial of Pico A> [CLOCK_HZ=48000000] demo/etr_standin.sh
set -e
: "${PICO:?PICO=id:<serial of Pico A>}"
mpremote connect "$PICO" exec "import os
try:
    os.mkdir('ttboard')
except OSError:
    pass
open('ttboard/__init__.py', 'w').close()"
mpremote connect "$PICO" cp python/etr_standin.py :ttboard/demoboard.py + \
    cp python/etr_standin.py :ttboard/mode.py + \
    cp python/etr_standin.py python/protocol_emulator.py python/demo_board.py \
    python/demo_board_check.py :
mpremote connect "$PICO" exec "import etr_standin; etr_standin.main(${CLOCK_HZ:-48000000})"
