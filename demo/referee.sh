#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# Cheat the referee on Pico A with the stick on OUT3. play: each press of BOOTSEL sends one
# frame on wire 20 a cycle late or early, until a 2 s hold prints the score and faults. auto:
# demo/outside.sh referee, a cycle and two either way eight times, captured and decoded.
# Reset the chip first, as faults hold until reset.
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
