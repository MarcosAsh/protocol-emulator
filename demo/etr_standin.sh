#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# Runs python/demo_board.py on Pico A as if it were the ETR board's RP2350B, using the
# ttboard stand-in python/etr_standin.py. Drives the host port at clock / 16, / 12 and / 8,
# then reselects. Reset the chip first. Prints one line per check, then PASS or FAIL.
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
