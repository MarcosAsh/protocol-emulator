#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# The bench carrier's self-test: loads icepi/carrier_check.v into the Icepi's SRAM, runs
# demo/carrier_check.py on both Picos, then reboots the Icepi from its flash, which holds
# the chip, and reads the chip's status through Pico A. Both Picos on MicroPython, and
# env.sh sourced for the FPGA tools. The log, captures, commit and bitstream hash go in
# EVIDENCE. Flags go on to carrier_check.py: --analysers, --no-button.
# Usage: PICO=id:<serial of Pico A> [PICO_B_SERIAL=<serial>] [REV=v1.3] demo/carrier_check.sh [FLAGS]
set -e
: "${PICO:?PICO=id:<serial of Pico A>}"
rev=${REV:-v1.3}
evidence=${EVIDENCE:-$HOME/.local/share/protocol-emulator/board-evidence/$(date +%F)/carrier}
mkdir -p "$evidence"
make -C icepi REV="$rev" check-prog
git rev-parse HEAD > "$evidence/commit"
sha256sum "icepi/build/$rev-carrier-check.bit" > "$evidence/bitstream.sha256"
{
    python3 demo/carrier_check.py --evidence "$evidence" "$@"
    echo $? > "$evidence/status"
} 2>&1 | tee "$evidence/carrier_check.log"
# the chip again, from the flash, and its status: halted, no faults
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
