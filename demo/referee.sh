#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# Try to cheat the referee on Pico A, with the stick on OUT3. play: each BOOTSEL press sends
# one frame on wire 20 a cycle early or late, and a 2 s hold prints the score and faults.
# auto: runs demo/outside.sh referee, which cheats by one and two cycles each way, eight
# times, and captures and decodes it. Reset the chip first, because faults stick until reset.
# Usage: PICO=id:<serial of Pico A> demo/referee.sh play|auto
set -e
case $1 in
play)
    mpremote connect "$PICO" cp python/protocol_emulator.py python/pico_board.py \
        python/bench.py python/bench_firmware.py python/demo_neopixel.py \
        python/demo_self_check.py python/demo_referee.py test/uart_tx_host_rate.hex \
        test/uart_tx_host_rate.cert.hex test/uart_tx_host_rate_rows.hex \
        test/self_check_wire.hex test/self_check_wire.cert.hex test/scrub.hex :
    mpremote connect "$PICO" exec "import demo_referee; demo_referee.main()"
    ;;
auto)
    exec demo/outside.sh referee
    ;;
*)
    echo "usage: PICO=id:<serial of Pico A> $0 play|auto" >&2
    exit 1
    ;;
esac
