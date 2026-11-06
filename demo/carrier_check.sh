#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# Self-test for the bench carrier. Loads icepi/carrier_check.v into the Icepi's SRAM, runs
# demo/carrier_check.py on both Picos, reboots the Icepi from flash (which holds the chip)
# and reads the chip's status through Pico A. Both Picos need MicroPython and env.sh must be
# sourced. The log, captures, commit and bitstream hash go in EVIDENCE. Flags are passed on
# to carrier_check.py: --analysers, --no-button.
# Usage: PICO=id:<serial of Pico A> [PICO_B_SERIAL=<serial>] [REV=v1.3] demo/carrier_check.sh [FLAGS]
set -e
: "${PICO:?PICO=id:<serial of Pico A>}"
rev=${REV:-v1.3}
evidence=${EVIDENCE:-$HOME/.local/share/protocol-emulator/board-evidence/$(date +%F)/carrier}
mkdir -p "$evidence"
make -C icepi REV="$rev" check-prog
git rev-parse HEAD > "$evidence/commit"
sha256sum "icepi/build/$rev-carrier-check.bit" > "$evidence/bitstream.sha256"
# no set -e here: a failing check must not skip saving its status
{
    status=0
    python3 demo/carrier_check.py --evidence "$evidence" "$@" || status=$?
    echo "$status" > "$evidence/status"
} 2>&1 | tee "$evidence/carrier_check.log"
# back to the chip in flash; its status should be halted with no faults
openFPGALoader -b icepi-zero -r
sleep 2
mpremote connect "$PICO" cp python/protocol_emulator.py python/pico_board.py :
mpremote connect "$PICO" exec "import pico_board
s = pico_board.host().status()
print(s)
faults = [s[k] for k in ('underflow', 'overflow', 'missed_deadline', 'decode')]
print('chip from flash:', 'PASS' if s['halted'] == 1 and not any(faults) else 'FAIL')" \
    | tee -a "$evidence/carrier_check.log"
exit "$(cat "$evidence/status")"
