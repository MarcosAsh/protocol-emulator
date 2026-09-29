#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# Runs COMMAND, then captures the fx2lafw analyser for MS milliseconds, again until the
# analyser sends every sample: on this bench it often stops early, and the last try is
# kept, which is still whole up to where it stopped. COMMAND should return
# at once and start its traffic after a pause, and the analyser is left alone meanwhile.
# Usage: demo/capture.sh OUT.sr MS [COMMAND...]
#   demo/capture.sh pico.sr 5000 mpremote connect id:e66548545717552e run --no-follow demo/pico_uart.py
set -e
out=$1
ms=$2
shift 2
for attempt in 1 2 3 4 5 6 7 8; do
    [ $# -eq 0 ] || "$@"
    if sigrok-cli -d fx2lafw -c samplerate=${RATE:-24M} --time "$ms" -o "$out" 2>&1 \
        | tee /dev/stderr | grep -q "only sent"; then
        echo "attempt $attempt stopped early, again" >&2
        sleep "${PAUSE:-5}"
    else
        exit 0
    fi
done
echo "$out is short: every attempt stopped early" >&2
exit 1
