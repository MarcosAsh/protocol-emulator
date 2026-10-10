#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# The standard settings on the bench's parts, python/demo_rates.py on Pico A, each demo
# captured and decoded as demo/outside.sh does its own:
#   i2c   the EEPROM in Standard-mode then Fast-mode, analyser B on IO2 and IO3
#   spi   the flash in modes 0 to 3, analyser B, decoded once in each mode
#   uart  OUT0 at each common rate to Pico B's UART0 and analyser A
# Needs Pico B in MicroPython (demo/pico_b.sh micropython), the I2C pull-ups for i2c, and
# a chip reset before each demo, as faults hold until reset. Each run is kept in EVIDENCE.
# Usage: PICO=id:<A> [PICO_B=id:<B>] demo/rates.sh i2c|spi|uart
set -e
demo=$1
evidence=${EVIDENCE:-$HOME/.local/share/protocol-emulator/board-evidence/$(date +%F)/rates}
mkdir -p "$evidence"
mpremote connect "$PICO" cp python/protocol_emulator.py python/pico_board.py python/bench.py \
    python/bench_firmware.py python/both_roles_firmware.py python/demo_eeprom.py \
    python/demo_flash.py python/demo_rates.py :
clear_log() {
    mpremote connect "$PICO" exec "import os
try:
    os.remove('outside.log')
except OSError:
    pass"
}
run() {
    # $1 the capture's name, $2 its ms, $3 the analyser, $4 demo_rates.main's arguments
    clear_log
    ANALYSER=$3 demo/capture.sh "$evidence/$1.sr" "$2" \
        mpremote connect "$PICO" exec --no-follow "import demo_rates; demo_rates.main($4)"
    sleep 1
    mpremote connect "$PICO" cat :outside.log | tee "$evidence/$1.log" \
        || echo "no log: the run was still going" >&2
}
case $demo in
i2c)
    run i2c 6000 B "'i2c'"
    sigrok-cli -i "$evidence/i2c.sr" -P i2c:sda=D6:scl=D7,eeprom24xx:chip=onsemi_cat24c256 \
        -A eeprom24xx | tee "$evidence/i2c.decode"
    ;;
spi)
    run spi 3000 B "'spi'"
    for mode in 0 1 2 3; do
        echo "mode $mode:"
        sigrok-cli -i "$evidence/spi.sr" \
            -P spi:clk=D0:mosi=D1:miso=D2:cs=D3:cpol=$((mode >> 1)):cpha=$((mode & 1)) \
            -A spi=mosi-transfer
    done | tee "$evidence/spi.decode"
    ;;
uart)
    : "${PICO_B:?PICO_B=id:<serial of Pico B>}"
    for baud in 9600 19200 38400 57600 115200 230400; do
        # Pico B listens three seconds, from before the capture starts its sender
        mpremote connect "$PICO_B" exec "from machine import Pin, UART
import time
port = UART(0, baudrate=$baud, tx=Pin(0), rx=Pin(1))
port.read()
got = b''
start = time.ticks_ms()
while time.ticks_diff(time.ticks_ms(), start) < 3000:
    got += port.read() or b''
    time.sleep_ms(5)
print(' '.join('%02x' % b for b in got))" > "$evidence/uart_$baud.pico_b" &
        listener=$!
        sleep 0.5
        run "uart_$baud" 2500 A "'uart', $baud"
        wait $listener
        echo "Pico B at $baud: $(cat "$evidence/uart_$baud.pico_b")"
        sigrok-cli -i "$evidence/uart_$baud.sr" -P uart:rx=D4:baudrate=$baud -A uart=rx-data \
            | tee "$evidence/uart_$baud.decode"
    done
    ;;
*)
    echo "usage: PICO=id:<A> [PICO_B=id:<B>] $0 i2c|spi|uart" >&2
    exit 1
    ;;
esac
git rev-parse HEAD > "$evidence/commit"
