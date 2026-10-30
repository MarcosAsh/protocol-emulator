#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# A protocol from a recording, on the board. Pico B replays a transmitter the chip was never
# told about onto IO3 (and IO2 for a clocked bus); the chip's own edge loggers record it,
# analyser B watching as referee; generate.exe learn reads the protocol from the chip's
# recording and writes firmware the kernel accepts for a message never sent; the chip sends
# it on OUT0 (OUT5 and OUT4 for a clocked bus), analyser A or B captures it, sigrok decodes
# it and Pico B, listening on OUT0, reads it back. Faults hold until reset, so the bitstream
# is loaded first.
# Usage: PICO=id:<Pico A> BIT=<bitstream> demo/learn_board.sh OUT line|clocked
#            [RECORDING.edges... [--scale S] [--until SECONDS]]
set -eu
out=$1
kind=$2
shift 2
pico_b=id:${PICO_B_SERIAL:-e66548545740ad29}
gen=${GENERATE:-_build/default/bin/generate.exe}
rate=${RATE:-4M}
mkdir -p "$out/prep"
openFPGALoader -b icepi-zero "$BIT" > "$out/load.txt" 2>&1
sha256sum "$BIT" > "$out/bitstream.sha256"
if [ "$kind" = clocked ]; then
    python3 demo/learn_prepare.py clocked "$out/prep/replay.json" > "$out/prep/replay.txt"
    lines="IO3 IO2"
    probes="IO3=D6 IO2=D7"
else
    python3 demo/learn_prepare.py replay "$out/prep/replay.json" "$@" > "$out/prep/replay.txt"
    lines=IO3
    probes="IO3=D6"
fi
seconds=$(sed 's/.*, \([0-9.]*\) s/\1/' "$out/prep/replay.txt")
# Pico B starts 3 s after its mpremote returns, a second after Pico A's
record_ms=$(python3 -c "print(int(($seconds + 6.5) * 1000))")
capture_ms=$(python3 -c "print(int(($seconds + 4.5) * 1000))")
python3 demo/learn_prepare.py logger "$out/prep" "$gen" $lines --ms "$record_ms" 2> "$out/logger.txt"
mpremote connect "$PICO" cp python/protocol_emulator.py python/pico_board.py python/bench.py \
    python/learn_record.py python/learn_send.py "$out/prep/record.json" : > /dev/null
mpremote connect "$pico_b" cp python/learn_replay.py python/learn_listen.py \
    "$out/prep/replay.json" : > /dev/null
started=$(date +%s)
mpremote connect "$PICO" run --no-follow python/learn_record.py
ANALYSER=B RATE=$rate demo/capture.sh "$out/recorded.sr" "$capture_ms" \
    mpremote connect "$pico_b" run --no-follow python/learn_replay.py
left=$(python3 -c "print(max(0, $record_ms / 1000 + 3 - ($(date +%s) - $started)))")
sleep "$left"
mpremote connect "$PICO" cat :record.log > "$out/record.log" || true
cat "$out/record.log"
mpremote connect "$PICO" cat :record.edges > "$out/chip.edges"
python3 demo/learn_prepare.py edges "$out/recorded.sr" $probes > "$out/analyser_recorded.edges"
if [ "$kind" = clocked ]; then
    pins="-clocked OUT5,OUT4"
    analyser=B
    spoken="IO2=D0 IO3=D1"
    decode="-P spi:clk=D0:mosi=D1:cpol=1:cpha=1 -A spi=mosi-data"
else
    pins="-pin OUT0"
    analyser=A
    spoken="OUT0=D4"
    decode=${DECODE:-}
fi
"$gen" learn "$out/chip.edges" -out "$out/learned" $pins > "$out/learn.txt" 2>&1 || true
cat "$out/learn.txt" | grep -v " s  kind " || true
"$gen" learn "$out/analyser_recorded.edges" > "$out/referee_learn.txt" 2>&1 || true
# a UART's decode at the baud learned, as nobody said what it was
baud=$(sed -n 's/^uart, \([0-9]*\)\.[0-9]* baud.*/\1/p' "$out/learn.txt")
decode=$(echo "$decode" | sed "s/BAUD/${baud:-0}/")
[ -f "$out/learned/send.json" ] || { echo "nothing learned to send"; exit 1; }
# a fresh load, as faults from the recording would hold
openFPGALoader -b icepi-zero "$BIT" > "$out/load_speak.txt" 2>&1
mpremote connect "$PICO" cp "$out/learned/send.json" : > /dev/null
# the firmware running, so its idle levels are set, before the analyser samples
mpremote connect "$PICO" exec "import learn_send, pico_board; learn_send.start(pico_board.PicoSpi().transfer)"
[ "$kind" = clocked ] || mpremote connect "$pico_b" run --no-follow python/learn_listen.py
ANALYSER=$analyser RATE=$rate demo/capture.sh "$out/spoken.sr" 6000 \
    mpremote connect "$PICO" run --no-follow python/learn_send.py
sleep 3
mpremote connect "$PICO" cat :outside.log > "$out/send.log"
cat "$out/send.log"
python3 demo/learn_prepare.py edges "$out/spoken.sr" $spoken > "$out/spoken.edges"
"$gen" learn "$out/chip.edges" -decode "$out/spoken.edges" > "$out/spoken.frames" 2>&1 || true
if [ "$kind" != clocked ]; then
    mpremote connect "$pico_b" cat :listen.edges > "$out/listen.edges"
    "$gen" learn "$out/chip.edges" -decode "$out/listen.edges" > "$out/listen.frames" 2>&1 || true
fi
[ -z "$decode" ] || sigrok-cli -i "$out/spoken.sr" $decode > "$out/spoken.decode" 2>&1 || true
(cd "$out" && sha256sum chip.edges record.log recorded.sr analyser_recorded.edges learn.txt \
    learned/firmware.asm learned/send.json spoken.sr spoken.edges spoken.frames send.log \
    $( [ -f listen.edges ] && echo listen.edges listen.frames ) \
    $( [ -f spoken.decode ] && echo spoken.decode ) > SHA256SUMS)
echo "spoken frames:"; cat "$out/spoken.frames"
[ ! -f "$out/listen.frames" ] || { echo "Pico B read:"; cat "$out/listen.frames"; }
[ ! -f "$out/spoken.decode" ] || { echo "sigrok:"; cat "$out/spoken.decode"; }
