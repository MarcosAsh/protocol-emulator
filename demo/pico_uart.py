# SPDX-License-Identifier: Apache-2.0
# The comparison for the overlay: a UART bit-banged from MicroPython on Pico B's GP2, each
# bit written once ticks_us passes its deadline from the start bit, so it never drifts and
# only jitters. Not PIO, which would be as exact as the chip. GP2 is the carrier's SDA,
# analyser B's D6, which the chip leaves alone from reset: capture with ANALYSER=B and
# compare with --against-channel D6.
# Usage: mpremote connect id:<serial of Pico B> run --no-follow demo/pico_uart.py

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
    tx = Pin(2, Pin.OUT, value=1)
    levels = [0] + [(BYTE >> i) & 1 for i in range(8)] + [1, 1]
    deadlines = [round(k * 1_000_000 / BAUD) for k in range(len(levels))]
    time.sleep_ms(800)
    for _ in range(FRAMES):
        send(tx, levels, deadlines)
        time.sleep_us(300)
    # SDA again, for the chip and the EEPROM
    Pin(2, Pin.IN)


main()
