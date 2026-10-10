#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# Both roles on one chip: python/demo_both_roles.py on Pico A while analyser B captures the
# bench's I2C bus, IO2 and IO3, where one case runs beside the EEPROM; then Pico A's log
# and sigrok's decode. The other cases run on wires no pin shows, so the log is their
# evidence. Needs Pico B idle on the bus (MicroPython), the SDA and SCL pull-ups, and a
# chip reset first, as faults hold until reset. Each run is kept in EVIDENCE.
# Usage: PICO=id:<serial of Pico A> demo/both_roles.sh
set -e
ms=4000
decode="-P i2c:sda=D6:scl=D7 -A i2c=address-read:address-write:data-read:data-write"
evidence=${EVIDENCE:-$HOME/.local/share/protocol-emulator/board-evidence/$(date +%F)/both_roles}
mkdir -p "$evidence"
mpremote connect "$PICO" cp python/protocol_emulator.py python/pico_board.py python/bench.py \
    python/both_roles_firmware.py python/demo_both_roles.py :
mpremote connect "$PICO" exec "import os
try:
    os.remove('outside.log')
except OSError:
    pass"
ANALYSER=B demo/capture.sh "$evidence/both_roles.sr" "$ms" \
    mpremote connect "$PICO" run --no-follow python/demo_both_roles.py
# the run ends inside the capture, and a second more lets the Pico write its log
sleep 1
mpremote connect "$PICO" cat :outside.log | tee "$evidence/both_roles.log" \
    || echo "no log: the run was still going" >&2
# shellcheck disable=SC2086
sigrok-cli -i "$evidence/both_roles.sr" $decode | tee "$evidence/both_roles.decode"
git rev-parse HEAD > "$evidence/commit"
