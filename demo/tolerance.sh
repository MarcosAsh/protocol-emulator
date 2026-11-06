#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# Measures the receiver's tolerance: runs python/demo_tolerance.py on Pico A and prints its
# log. Engine 1 sends to engine 0 on a wire that never reaches a pin, so the log is the only
# evidence and no analyser is needed. Reset the chip first, because faults stick until
# reset. The run is saved in EVIDENCE.
# Usage: PICO=id:<serial of Pico A> demo/tolerance.sh
set -e
evidence=${EVIDENCE:-$HOME/.local/share/protocol-emulator/board-evidence/$(date +%F)/tolerance}
mkdir -p "$evidence"
mpremote connect "$PICO" cp python/protocol_emulator.py python/pico_board.py python/bench.py \
    python/tolerance_firmware.py python/demo_tolerance.py :
mpremote connect "$PICO" exec "import os
try:
    os.remove('outside.log')
except OSError:
    pass"
mpremote connect "$PICO" run python/demo_tolerance.py
mpremote connect "$PICO" cat :outside.log | tee "$evidence/tolerance.log"
git rev-parse HEAD > "$evidence/commit"
