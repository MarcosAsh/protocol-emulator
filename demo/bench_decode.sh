#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# One protocol on the bench: Pico A plays a trace's host frames into the chip while the
# analyser A captures for MS milliseconds, then sigrok's decoders judge the capture against
# the trace. Needs a trace at the bench's 48 MHz whose pins the analyser has: uart_tx, can
# and ws2812 as wired, others with --probe and whatever their peer is. The capture lands in
# demo/captures/<trace>.sr.
# Usage: PICO=id:<serial of Pico A> demo/bench_decode.sh TRACE [--probe PIN=Dn...]
#   PICO=id:e66548545717552e demo/bench_decode.sh test/traces/sigrok/can.trace
set -e
echo "press the Icepi's reset button first: the trace starts from reset" >&2
trace=$1
shift
name=$(basename "$trace" .trace)
captures=demo/captures
frames=$(mktemp -d)
trap 'rm -rf "$frames"' EXIT
python3 demo/decode.py --host-frames "$frames/frames.py" "$trace"
mpremote connect "$PICO" cp python/protocol_emulator.py python/pico_board.py "$frames/frames.py" :
mkdir -p "$captures"
ANALYSER=A demo/capture.sh "$captures/$name.sr" "${MS:-2000}" mpremote connect "$PICO" run --no-follow demo/pico_replay.py
python3 demo/decode.py --capture "$captures/$name.sr" "$@" "$trace"
