#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# Both roles on one chip: python/demo_both_roles.py on Pico A, then its log. Every case
# runs on wires no pin shows, so the log is the evidence, and no analyser is needed. Reset
# the chip first, as faults hold until reset. Each run is kept in EVIDENCE.
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
