#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# Runs COMMAND, then captures the fx2lafw analyser for MS milliseconds, again until it sends
# every sample. It often stops early here, so the last try is kept, whole up to where it
# stopped. COMMAND should return at once and start its traffic after a pause.
# With two analysers, ANALYSER=A or B picks one by USB port, ANALYSER_A_PORT and
# ANALYSER_B_PORT as /sys/bus/usb/devices names, the carrier's 3-4 and 3-3.1.3.3 unless set.
# DEVICE picks it instead, e.g. fx2lafw:conn=1.7 as `sigrok-cli --scan` prints.
# TRIES caps the attempts, 8 unless set. Samples go out raw and are packed after, as srzip's
# compression in sigrok-cli's USB loop makes the analyser stop early.
# Usage: [ANALYSER=A|B] demo/capture.sh OUT.sr MS [COMMAND...]
#   ANALYSER=B demo/capture.sh pico.sr 5000 mpremote connect id:e66548545740ad29 run --no-follow demo/pico_uart.py
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
A) port=${ANALYSER_A_PORT:-3-4} ;;
B) port=${ANALYSER_B_PORT:-3-3.1.3.3} ;;
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
    # read each time, as the analyser's address changes when it takes its firmware
    if [ -z "$device" ] && [ -n "$port" ]; then
        DEVICE=fx2lafw:conn=$(cat "/sys/bus/usb/devices/$port/busnum").$(cat "/sys/bus/usb/devices/$port/devnum")
    fi
    # not tee /dev/stderr, which truncates a file that stderr goes to
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
