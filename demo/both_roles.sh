#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# Runs python/demo_both_roles.py (both roles on one chip) on Pico A and prints its log.
# Every case uses wires that never reach a pin, so the log is the only evidence and no
# analyser is needed. Reset the chip first, because faults stick until reset. The run is
# saved in EVIDENCE.
# Usage: PICO=id:<serial of Pico A> demo/both_roles.sh
set -e
evidence=${EVIDENCE:-$HOME/.local/share/protocol-emulator/board-evidence/$(date +%F)/both_roles}
mkdir -p "$evidence"
mpremote connect "$PICO" cp python/protocol_emulator.py python/pico_board.py python/bench.py \
    python/both_roles_firmware.py python/demo_both_roles.py :
mpremote connect "$PICO" exec "import os
try:
    os.remove('outside.log')
except OSError:
    pass"
mpremote connect "$PICO" run python/demo_both_roles.py
mpremote connect "$PICO" cat :outside.log | tee "$evidence/both_roles.log"
git rev-parse HEAD > "$evidence/commit"
