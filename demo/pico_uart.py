# SPDX-License-Identifier: Apache-2.0
# The comparison for the overlay: a UART bit-banged from MicroPython on GP0, each bit
# written once ticks_us passes its deadline from the start bit, so it never drifts and
# only jitters. Not PIO, which would be as exact as the chip.
# Usage: mpremote connect id:<serial> run --no-follow demo/pico_uart.py

import time

from machine import Pin

BAUD = 9600
FRAMES = 1000
BYTE = 0x55


def send(tx, levels, deadlines):
    tx(0)
    start = time.ticks_us()
    for i in range(1, len(levels)):
        while time.ticks_diff(time.ticks_us(), start) < deadlines[i]:
            pass
        tx(levels[i])


def main():
    tx = Pin(0, Pin.OUT, value=1)
    levels = [0] + [(BYTE >> i) & 1 for i in range(8)] + [1, 1]
    deadlines = [round(k * 1_000_000 / BAUD) for k in range(len(levels))]
    time.sleep_ms(800)
    for _ in range(FRAMES):
        send(tx, levels, deadlines)
        time.sleep_us(300)


main()
