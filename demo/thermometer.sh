#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# A finger thermometer on Pico A: the chip reads the DS18B20 with one engine and shows how
# far it is above the first reading on the NeoPixel stick with the other. Reset the chip
# first, because faults stick until reset.
# Usage: PICO=id:<serial of Pico A> demo/thermometer.sh [SECONDS]
set -e
firmware=$(mktemp -d)
python3 demo/pico_firmware.py "$firmware/bench_firmware.py" python/demo_ds18b20.py \
    python/demo_neopixel.py
mpremote connect "$PICO" cp python/protocol_emulator.py python/pico_board.py python/bench.py \
    "$firmware/bench_firmware.py" python/demo_ds18b20.py python/demo_neopixel.py \
    python/demo_thermometer.py :
rm -r "$firmware"
mpremote connect "$PICO" exec "import demo_thermometer; demo_thermometer.main(${1:-60})"
