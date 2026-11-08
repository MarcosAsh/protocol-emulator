#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# One outside-chip demo. Runs the demo's script on Pico A while its analyser
# captures, then prints the Pico's log and sigrok's decode. The last line is FAIL if the
# capture lacks the demo's traffic (demo/traffic.py), whatever the Pico said. Reset the chip
# before every demo, because faults stick until reset. Analyser A sees the host port, OUT0,
# CAN and SWD; B sees the flash, the stick, 1-Wire and I2C (see demo/capture.sh). The capture,
# log and decode are saved as <name>.sr, .log and .decode in CAPTURES (default: here).
# Usage: PICO=id:<serial of Pico A> demo/outside.sh <demo>, one of
#   flash eeprom eeprom_stretch ds18b20 neopixel start_hold can can_node swd referee
#   pio_ws2812 pio_uart_tx pio_spi, or any protocol whose python/demo_<demo>.py has an
#   "# outside:" line
set -e
name=$1
captures=${CAPTURES:-.}
files=
arm=
case $name in
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
    # the last score arrives just after 4 s
    ms=6000
    decode="-P rgb_led_ws281x:din=D4 -A rgb_led_ws281x=rgb:reset"
    analyser=B
    files="python/demo_neopixel.py python/demo_self_check.py test/uart_tx_host_rate.hex
        test/uart_tx_host_rate.cert.hex test/uart_tx_host_rate_rows.hex test/self_check_wire.hex
        test/self_check_wire.cert.hex test/scrub.hex"
    ;;
pio_ws2812)
    ms=2000
    decode="-P rgb_led_ws281x:din=D4 -A rgb_led_ws281x=rgb:reset"
    analyser=B
    files="python/pio_firmware.py python/pio_upstream.py"
    ;;
pio_uart_tx)
    ms=2000
    decode="-P uart:rx=D4:baudrate=115200 -A uart=rx-data"
    analyser=A
    files="python/pio_firmware.py python/pio_upstream.py"
    ;;
pio_spi)
    ms=2000
    decode="-P spi:clk=D0:mosi=D1:miso=D2:cs=D3,spiflash:chip=winbond_w25q80dv -A spiflash"
    analyser=B
    files="python/pio_firmware.py python/pio_upstream.py"
    ;;
*)
    # anything else is a protocol; its script's "# outside:" line gives the analyser, the
    # capture length and the sigrok decoders
    line=$(sed -n 's/^# outside: //p' "python/demo_$name.py" 2>/dev/null | head -1)
    if [ -z "$line" ]; then
        echo "usage: PICO=id:<serial> $0 flash|eeprom|eeprom_stretch|ds18b20|neopixel|start_hold|can|can_node|swd|referee|pio_ws2812|pio_uart_tx|pio_spi|<protocol>" >&2
        exit 1
    fi
    analyser=$(echo "$line" | sed -n 's/.*analyser=\([^ ]*\).*/\1/p')
    # match ms= as a whole word, since a decoder option can end in it (wiegand's bitwidth_ms=)
    ms=$(echo "$line" | sed -n 's/.* ms=\([0-9]*\).*/\1/p')
    decode=$(echo "$line" | sed -n 's/.*decode=//p')
    ;;
esac
# copy only the firmware this demo names: Pico A compiles all of bench_firmware.py on import,
# which is slow enough to push the traffic past the end of the capture
firmware=$(mktemp -d)
# shellcheck disable=SC2086
python3 demo/pico_firmware.py "$firmware/bench_firmware.py" "python/demo_$name.py" $files
# shellcheck disable=SC2086
mpremote connect "$PICO" cp python/protocol_emulator.py python/pico_board.py python/bench.py \
    "$firmware/bench_firmware.py" "python/demo_$name.py" $files :
rm -r "$firmware"
mpremote connect "$PICO" exec "import os
try:
    os.remove('outside.log')
except OSError:
    pass"
# sigrok's CAN decoder reads the dominant line a reset chip leaves at the start as a frame
[ -z "$arm" ] || mpremote connect "$PICO" exec "$arm"
mkdir -p "$captures"
ANALYSER=$analyser demo/capture.sh "$captures/$name.sr" "$ms" mpremote connect "$PICO" run --no-follow "python/demo_$name.py"
# the demo ends inside the capture; wait a second more so the Pico can write its log
sleep 1
if mpremote connect "$PICO" cat :outside.log > "$captures/$name.log"; then
    cat "$captures/$name.log"
else
    echo "no log: the demo was still running" >&2
fi
# shellcheck disable=SC2086
sigrok-cli -i "$captures/$name.sr" $decode > "$captures/$name.decode"
cat "$captures/$name.decode"
verdict=$(python3 demo/traffic.py "$name" "$captures")
echo "$verdict"
# protocols made with generate new-protocol get their bench time in demo/speed.tsv
# (the Pico's log ends its lines in CRLF)
if [ -f "$captures/$name.log" ] && [ "$(tail -n 1 "$captures/$name.log" | tr -d '\r')" = PASS ] &&
    ! echo "$verdict" | grep -qx FAIL; then
    python3 demo/speed.py mark "$name" bench --if-started || true
fi
