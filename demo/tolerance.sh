#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# The receiver's tolerance, measured: python/demo_tolerance.py on Pico A, then its log.
# Engine 1 sends to engine 0 on a wire no pin shows, so the log is the evidence, and no
# analyser is needed. Reset the chip first, as faults hold until reset. Each run is kept
# in EVIDENCE.
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
