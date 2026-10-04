#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# One outside chip act of BRINGUP.md: runs its script on Pico A while the analyser
# captures, then prints the Pico's log and sigrok's decode. Reset the chip first, as faults
# hold until reset, but not for can or can_node, which run on the engine their arm() left
# running.
# Usage: PICO=id:<serial of Pico A> demo/outside.sh <act>, one of
#   flash eeprom eeprom_stretch ds18b20 neopixel start_hold can can_node swd referee
set -e
act=$1
files=
case $act in
flash)
    ms=4000
    decode="-P spi:clk=D5:mosi=D4:miso=D6:cs=D7,spiflash:chip=winbond_w25q80dv -A spiflash"
    ;;
eeprom)
    ms=3000
    decode="-P i2c:sda=D6:scl=D7,eeprom24xx:chip=onsemi_cat24c256 -A eeprom24xx"
    ;;
eeprom_stretch)
    ms=3000
    decode="-P i2c:sda=D6:scl=D7,eeprom24xx:chip=onsemi_cat24c256 -A eeprom24xx"
    files=python/demo_eeprom.py
    ;;
ds18b20)
    ms=4000
    decode="-P onewire_link:owr=D6,onewire_network -A onewire_network"
    ;;
neopixel)
    ms=2000
    decode="-P rgb_led_ws281x:din=D4 -A rgb_led_ws281x=rgb:reset"
    ;;
start_hold)
    ms=3000
    decode="-P i2c:sda=D6:scl=D7 -A i2c=start:repeat-start"
    files=python/demo_neopixel.py
    ;;
can)
    ms=2000
    decode="-P can:can_rx=D6:nominal_bitrate=500000 -A can=id:dlc:data:crc-sequence:ack-slot:warnings"
    ;;
can_node)
    ms=3000
    decode="-P can:can_rx=D6:nominal_bitrate=500000 -A can=id:dlc:data:crc-sequence:ack-slot:warnings"
    files=python/demo_can.py
    ;;
swd)
    ms=3000
    decode="-P swd:swclk=D6:swdio=D7 -A swd"
    ;;
referee)
    ms=4000
    decode="-P rgb_led_ws281x:din=D4 -A rgb_led_ws281x=rgb:reset"
    files="python/demo_neopixel.py python/demo_self_check.py test/uart_tx_host_rate.hex
        test/uart_tx_host_rate_rows.hex test/self_check_wire.hex test/scrub.hex"
    ;;
*)
    echo "usage: PICO=id:<serial> $0 flash|eeprom|eeprom_stretch|ds18b20|neopixel|start_hold|can|can_node|swd|referee" >&2
    exit 1
    ;;
esac
# shellcheck disable=SC2086
mpremote connect "$PICO" cp python/protocol_emulator.py python/pico_board.py python/bench.py \
    python/bench_firmware.py "python/demo_$act.py" $files :
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
