#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# Runs COMMAND, then captures the fx2lafw analyser for MS milliseconds, again until the
# analyser sends every sample: on this bench it often stops early, and the last try is
# kept, which is still whole up to where it stopped. COMMAND should return
# at once and start its traffic after a pause, and the analyser is left alone meanwhile.
# With two analysers plugged in, ANALYSER=A or B picks one by the USB port it is on,
# ANALYSER_A_PORT and ANALYSER_B_PORT as /sys/bus/usb/devices names it (3-1.2); without
# them DEVICE does, DEVICE=fx2lafw:conn=1.7, the bus and address `sigrok-cli --scan` prints.
# Usage: [ANALYSER=A|B] demo/capture.sh OUT.sr MS [COMMAND...]
#   demo/capture.sh pico.sr 5000 mpremote connect id:e66548545717552e run --no-follow demo/pico_uart.py
set -e
out=$1
ms=$2
shift 2
case ${ANALYSER:-} in
A) port=${ANALYSER_A_PORT:-} ;;
B) port=${ANALYSER_B_PORT:-} ;;
'') port= ;;
*)
    echo "ANALYSER is A or B, not $ANALYSER" >&2
    exit 1
    ;;
esac
if [ -n "${ANALYSER:-}" ] && [ -z "$port" ]; then
    echo "ANALYSER_${ANALYSER}_PORT is unset: DEVICE picks the analyser" >&2
fi
for attempt in 1 2 3 4 5 6 7 8; do
    [ $# -eq 0 ] || "$@"
    # read each time, as the analyser's address changes when it takes its firmware
    if [ -n "$port" ]; then
        DEVICE=fx2lafw:conn=$(cat "/sys/bus/usb/devices/$port/busnum").$(cat "/sys/bus/usb/devices/$port/devnum")
    fi
    # not tee /dev/stderr, which truncates a file that stderr goes to
    said=$(sigrok-cli -d "${DEVICE:-fx2lafw}" -c samplerate="${RATE:-24M}" --time "$ms" -o "$out" 2>&1) || true
    [ -z "$said" ] || echo "$said" >&2
    if echo "$said" | grep -q "only sent"; then
        echo "attempt $attempt stopped early, again" >&2
        sleep "${PAUSE:-5}"
    else
        exit 0
    fi
done
echo "$out is short: every attempt stopped early" >&2
exit 1
