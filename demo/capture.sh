#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# Runs COMMAND, which should return at once and start its traffic after a pause, then captures
# the fx2lafw analyser for MS ms, retrying up to TRIES (default 8). ANALYSER=A|B picks one by
# USB port (ANALYSER_A_PORT, ANALYSER_B_PORT; default 3-3, 3-2), or set DEVICE.
# Usage: [ANALYSER=A|B] demo/capture.sh OUT.sr MS [COMMAND...]
set -e
out=$1
ms=$2
shift 2
device=${DEVICE:-}
raw=$out.bin
pack() {
    python3 "$(dirname "$0")/sigrok.py" "$raw" "${RATE:-24M}" "$out" && rm -f "$raw"
}
case ${ANALYSER:-} in
A) port=${ANALYSER_A_PORT:-3-3} ;;
B) port=${ANALYSER_B_PORT:-3-2} ;;
'') port= ;;
*)
    echo "ANALYSER is A or B, not $ANALYSER" >&2
    exit 1
    ;;
esac
if [ -n "${ANALYSER:-}" ] && [ -z "$port" ]; then
    echo "ANALYSER_${ANALYSER}_PORT is unset: DEVICE picks the analyser" >&2
fi
for attempt in $(seq "${TRIES:-8}"); do
    [ $# -eq 0 ] || "$@"
    # look it up every try: the address changes once the analyser loads its firmware
    if [ -z "$device" ] && [ -n "$port" ]; then
        DEVICE=fx2lafw:conn=$(cat "/sys/bus/usb/devices/$port/busnum").$(cat "/sys/bus/usb/devices/$port/devnum")
    fi
    # no tee /dev/stderr: it truncates the file when stderr is redirected to one
    said=$(sigrok-cli -d "${DEVICE:-fx2lafw}" -c samplerate="${RATE:-24M}" --time "$ms" -O binary -o "$raw" 2>&1) || true
    [ -z "$said" ] || echo "$said" >&2
    if echo "$said" | grep -q "only sent"; then
        echo "attempt $attempt stopped early, again" >&2
        sleep "${PAUSE:-5}"
    else
        pack
        exit 0
    fi
done
pack
echo "$out is short: every attempt stopped early" >&2
exit 1
