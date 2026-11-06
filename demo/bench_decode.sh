#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# Plays a trace's host frames into the chip from Pico A while ANALYSER (default A) captures
# for MS milliseconds, then checks the capture against the trace with sigrok's decoders.
# The trace must be at 48 MHz and its pins must be on the analyser: uart_tx, can, ws2812
# and swd are on A, the spi_mode traces on B. Anything else needs --probe and its peer.
# Usage: PICO=id:<serial of Pico A> [ANALYSER=A|B] demo/bench_decode.sh TRACE [--probe PIN=Dn...]
#   PICO=id:e66548545717552e demo/bench_decode.sh test/traces/sigrok/can.trace
set -e
echo "press the Icepi's reset button first: the trace starts from reset" >&2
trace=$1
shift
name=$(basename "$trace" .trace)
frames=$(mktemp -d)
trap 'rm -rf "$frames"' EXIT
python3 demo/decode.py --host-frames "$frames/frames.py" "$trace"
mpremote connect "$PICO" cp python/protocol_emulator.py python/pico_board.py "$frames/frames.py" :
ANALYSER=${ANALYSER:-A} demo/capture.sh "$name.sr" "${MS:-2000}" mpremote connect "$PICO" run --no-follow demo/pico_replay.py
python3 demo/decode.py --analyser "${ANALYSER:-A}" --capture "$name.sr" "$@" "$trace"
