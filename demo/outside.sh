#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# One outside chip act of BRINGUP.md: runs its script on Pico A while its analyser
# captures, then prints the Pico's log and sigrok's decode, and FAIL last if the capture
# lacks the demo's traffic (demo/traffic.py), whatever the Pico said. Reset the chip before every
# act, CAN included, as faults hold until reset. Analyser A has the host port, OUT0, CAN
# and SWD, B the flash, the stick, 1-Wire and I2C: see demo/capture.sh for picking one.
# The capture, the Pico's log and the decode are kept as <name>.sr, .log and .decode in
# CAPTURES, the current directory unless set.
# Usage: PICO=id:<serial of Pico A> demo/outside.sh <act>, one of
#   flash eeprom eeprom_stretch ds18b20 neopixel start_hold can can_node swd referee
set -e
act=$1
captures=${CAPTURES:-.}
files=
arm=
case $act in
flash)
    ms=4000
    decode="-P spi:clk=D0:mosi=D1:miso=D2:cs=D3,spiflash:chip=winbond_w25q80dv -A spiflash"
    analyser=B
    ;;
eeprom)
    ms=3000
    decode="-P i2c:sda=D6:scl=D7,eeprom24xx:chip=onsemi_cat24c256 -A eeprom24xx"
    analyser=B
    ;;
eeprom_stretch)
    ms=3000
    decode="-P i2c:sda=D6:scl=D7,eeprom24xx:chip=onsemi_cat24c256 -A eeprom24xx"
    analyser=B
    files=python/demo_eeprom.py
    ;;
ds18b20)
    ms=4000
    decode="-P onewire_link:owr=D5,onewire_network -A onewire_network"
    analyser=B
    ;;
neopixel)
    ms=2000
    decode="-P rgb_led_ws281x:din=D4 -A rgb_led_ws281x=rgb:reset"
    analyser=B
    ;;
start_hold)
    ms=3000
    decode="-P i2c:sda=D6:scl=D7 -A i2c=start:repeat-start"
    analyser=B
    files=python/demo_neopixel.py
    ;;
can)
    ms=2000
    decode="-P can:can_rx=D5:nominal_bitrate=500000 -A can=id:dlc:data:crc-sequence:ack-slot:warnings"
    analyser=A
    arm="import demo_can, pico_board; demo_can.arm(pico_board.PicoSpi().transfer)"
    ;;
can_node)
    ms=3000
    decode="-P can:can_rx=D5:nominal_bitrate=500000 -A can=id:dlc:data:crc-sequence:ack-slot:warnings"
    analyser=A
    files=python/demo_can.py
    arm="import demo_can_node, pico_board; demo_can_node.arm(pico_board.PicoSpi().transfer)"
    ;;
swd)
    ms=3000
    decode="-P swd:swclk=D6:swdio=D7 -A swd"
    analyser=A
    ;;
referee)
    ms=4000
    decode="-P rgb_led_ws281x:din=D4 -A rgb_led_ws281x=rgb:reset"
    analyser=B
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
# a run arms itself, but sigrok's CAN decoder takes the dominant line a reset chip leaves at
# the start of a capture for a frame
[ -z "$arm" ] || mpremote connect "$PICO" exec "$arm"
mkdir -p "$captures"
ANALYSER=$analyser demo/capture.sh "$captures/$act.sr" "$ms" mpremote connect "$PICO" run --no-follow "python/demo_$act.py"
# the act ends inside the capture, and a second more lets the Pico write its log
sleep 1
if mpremote connect "$PICO" cat :outside.log > "$captures/$act.log"; then
    cat "$captures/$act.log"
else
    echo "no log: the demo was still running" >&2
fi
# shellcheck disable=SC2086
sigrok-cli -i "$captures/$act.sr" $decode > "$captures/$act.decode"
cat "$captures/$act.decode"
python3 demo/traffic.py "$act" "$captures"
