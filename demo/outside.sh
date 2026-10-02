#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# One outside chip act of BRINGUP.md: runs its script on Pico A while the analyser
# captures, then prints the Pico's log and sigrok's decode. Reset the chip first, as faults
# hold until reset, but not for can, which runs on the engine demo_can.arm() left running.
# Usage: PICO=id:<serial of Pico A> demo/outside.sh flash|eeprom|ds18b20|neopixel|can
set -e
act=$1
case $act in
flash)
    ms=4000
    decode="-P spi:clk=D5:mosi=D4:miso=D6:cs=D7,spiflash:chip=winbond_w25q80dv -A spiflash"
    ;;
eeprom)
    ms=3000
    decode="-P i2c:sda=D6:scl=D7,eeprom24xx:chip=onsemi_cat24c256 -A eeprom24xx"
    ;;
ds18b20)
    ms=4000
    decode="-P onewire_link:owr=D6,onewire_network -A onewire_network"
    ;;
neopixel)
    ms=2000
    decode="-P rgb_led_ws281x:din=D4 -A rgb_led_ws281x=rgb:reset"
    ;;
can)
    ms=2000
    decode="-P can:can_rx=D6:nominal_bitrate=500000 -A can=id:dlc:data:crc-sequence:ack-slot:warnings"
    ;;
*)
    echo "usage: PICO=id:<serial> $0 flash|eeprom|ds18b20|neopixel|can" >&2
    exit 1
    ;;
esac
mpremote connect "$PICO" cp python/protocol_emulator.py python/pico_board.py python/bench.py \
    python/bench_firmware.py "python/demo_$act.py" :
mpremote connect "$PICO" exec "import os
try:
    os.remove('outside.log')
except OSError:
    pass"
demo/capture.sh "$act.sr" "$ms" mpremote connect "$PICO" run --no-follow "python/demo_$act.py"
# the act ends inside the capture, and a second more lets the Pico write its log
sleep 1
mpremote connect "$PICO" cat :outside.log || echo "no log: the act was still running" >&2
# shellcheck disable=SC2086
sigrok-cli -i "$act.sr" $decode
