#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# Two certified engines at once: engine 1 reads the carrier's DS18B20, engine 0 is the USB
# keyboard that types the reading into the laptop. python/demo_thermometer.py on Pico A, its
# log kept in EVIDENCE. Reset the chip first, as faults hold until reset. Put the cursor
# in a text editor on the laptop; the Icepi's first USB port is attached from Pico A once
# engine 0 serves. Runs until Ctrl-C.
# Usage: PICO=id:<serial of Pico A> demo/thermometer.sh
set -e
: "${PICO:?PICO=id:<serial of Pico A>}"
evidence=${EVIDENCE:-$HOME/.local/share/protocol-emulator/board-evidence/$(date +%F)/thermometer}
mkdir -p "$evidence"
git rev-parse HEAD > "$evidence/commit"
mpremote connect "$PICO" cp python/protocol_emulator.py python/pico_board.py python/bench.py \
    python/bench_firmware.py python/demo_ds18b20.py python/usb_board.py \
    python/usb_device_firmware.py python/demo_usb.py python/demo_thermometer.py :
mpremote connect "$PICO" run python/demo_thermometer.py | tee "$evidence/thermometer.log"
