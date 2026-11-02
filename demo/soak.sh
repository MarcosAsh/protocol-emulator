#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# The overnight self-check soak (python/soak.py) on the bench carrier: Pico A (J13) drives
# the chip's host port, the Icepi boots the chip from its flash. install puts it on Pico A
# as main.py, collect copies the logs into DIR and removes main.py, test runs it here for
# MINUTES with a glitch every two minutes. Each resets the Icepi first and checks its status.
# Usage: PICO=id:<pico a> demo/soak.sh install|collect DIR|test MINUTES
set -e
cd "$(dirname "$0")/.."
pico="mpremote connect ${PICO:?PICO=id:<pico a>}"
files="python/protocol_emulator.py python/pico_board.py python/demo_self_check.py python/soak.py
    test/uart_tx_host_rate.hex test/uart_tx_host_rate_rows.hex test/self_check_wire.hex"
# the chip again, from the flash, and its status: halted, no faults
from_flash() {
    openFPGALoader -b icepi-zero -r
    sleep 2
    $pico cp python/protocol_emulator.py python/pico_board.py :
    $pico exec "import pico_board
s = pico_board.host().status()
faults = [s[k] for k in ('underflow', 'overflow', 'missed_deadline', 'decode')]
print('chip from flash:', 'PASS' if s['halted'] == 1 and not any(faults) else 'FAIL')" |
        tee /dev/stderr | grep -q "chip from flash: PASS"
}

case ${1:-} in
install)
    from_flash
    $pico cp $files :
    $pico exec "
import os
for f in ('soak.log', 'soak.1.log'):
    try:
        os.remove(f)
    except OSError:
        pass
with open('main.py', 'w') as f:
    f.write('import soak\nsoak.Soak().run()\n')
print('main.py runs the soak from the next power-up')"
    ;;
collect)
    dir=${2:?collect DIR}
    mkdir -p "$dir"
    # entering the raw repl stops the soak, and with main.py gone it stays stopped
    $pico rm :main.py
    $pico cp :soak.log "$dir/soak.log"
    $pico exec "import os; print(os.listdir())" | grep -q "soak.1.log" &&
        $pico cp :soak.1.log "$dir/soak.1.log" || true
    tail -3 "$dir/soak.log"
    ;;
test)
    minutes=${2:?test MINUTES}
    $pico cp $files :
    $pico exec "
import os
for f in ('soak.log', 'soak.1.log'):
    try:
        os.remove(f)
    except OSError:
        pass"
    from_flash
    $pico exec "import soak; soak.Soak(glitch_s=120, log_s=60).run(until_s=$((minutes * 60)))"
    $pico cat :soak.log
    ;;
*)
    echo "usage: demo/soak.sh install | collect DIR | test MINUTES" >&2
    exit 1
    ;;
esac
