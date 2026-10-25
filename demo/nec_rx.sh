#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# NEC infrared into the chip: Pico A loads the library's receiver and listens, Pico B's
# pico_nec_sender.py sends demo_nec's keys on IO3 while analyser B captures D6, and Pico A
# judges the words the chip pushed. Each run from BITSTREAM, as faults hold until reset.
# Usage: PICO=id:<serial of Pico A> [PICO_B_SERIAL=<serial>] demo/nec_rx.sh BITSTREAM [DIR]
set -e
bitstream=$1
out=${2:-nec_rx}
pico_b=id:${PICO_B_SERIAL:-e66548545740ad29}
mkdir -p "$out"
openFPGALoader -b icepi-zero "$bitstream" > "$out/load.txt" 2>&1
mpremote connect "$PICO" cp python/protocol_emulator.py python/pico_board.py python/bench.py \
    python/bench_firmware.py python/demo_nec.py python/demo_nec_rx.py :
mpremote connect "$pico_b" cp python/pico_nec_sender.py :
mpremote connect "$PICO" run --no-follow python/demo_nec_rx.py
# Pico A's START_MS, so the receiver listens before the first leader
sleep 2
ANALYSER=B demo/capture.sh "$out/nec_rx.sr" 3000 \
    mpremote connect "$pico_b" run --no-follow python/pico_nec_sender.py
# demo_nec_rx.LISTEN_MS from its start
sleep 7
mpremote connect "$PICO" cat :outside.log > "$out/nec_rx.log"
sigrok-cli -i "$out/nec_rx.sr" -P ir_nec:ir=D6 -A ir_nec=addr:addr-inv:cmd:cmd-inv:repeat-code \
    > "$out/nec_rx.decode"
(cd "$out" && sha256sum nec_rx.sr nec_rx.log nec_rx.decode > SHA256SUMS)
cat "$out/nec_rx.log"
tail -1 "$out/nec_rx.log" | tr -d "\r" | grep -qx PASS
