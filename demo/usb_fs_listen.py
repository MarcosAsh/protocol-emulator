# SPDX-License-Identifier: Apache-2.0
# Pico B's half of demo/usb_fs_check.py: icepi/usb_fs_check.v's packets arrive on GP1
# (header 8) at 1 Mbaud and go to the laptop in hex, a line at a time, for SECONDS.
# Usage: mpremote connect id:<serial of Pico B> run demo/usb_fs_listen.py

import time

from machine import UART, Pin

SECONDS = 12


def main():
    uart = UART(0, 1_000_000, rx=Pin(1), tx=Pin(0), rxbuf=16384)
    print("listening")
    end = time.ticks_add(time.ticks_ms(), SECONDS * 1000)
    while time.ticks_diff(end, time.ticks_ms()) > 0:
        data = uart.read()
        if data:
            print(data.hex())
        else:
            time.sleep_ms(5)
    print("done")


main()
