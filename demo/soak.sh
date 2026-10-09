#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# The overnight self-check soak (python/soak.py) on Pico A, with the Icepi booting from its
# flash. install puts it on Pico A as main.py, so it starts on power with no laptop;
# collect copies the logs off into DIR and takes main.py away again; test runs it here
# for MINUTES with a glitch every two minutes, the Icepi reset to its flash first.
# Usage: PICO=id:<pico a> demo/soak.sh install|collect DIR|test MINUTES
set -e
cd "$(dirname "$0")/.."
pico="mpremote connect ${PICO:?PICO=id:<pico a>}"
files="python/protocol_emulator.py python/pico_board.py python/demo_self_check.py python/soak.py
    test/uart_tx_host_rate.hex test/uart_tx_host_rate_rows.hex test/self_check_wire.hex"
case ${1:-} in
install)
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
    openFPGALoader -b icepi-zero -r
    $pico exec "import soak; soak.Soak(glitch_s=120, log_s=60).run(until_s=$((minutes * 60)))"
    $pico cat :soak.log
    ;;
*)
    echo "usage: demo/soak.sh install | collect DIR | test MINUTES" >&2
    exit 1
    ;;
esac
