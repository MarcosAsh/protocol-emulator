# SPDX-License-Identifier: Apache-2.0
# Pico A's half of demo/usb_fs_chip.py: holds the USB port detached (GP8, header 15) while
# the laptop loads the chip for LOAD_MS, arms the chip's USB receiver on D+ = pad 12
# (uio[0]), lets the port attach so the laptop enumerates it at full speed, and rearms
# after each packet for SECONDS. Prints each frame status and USB flags seen, in hex, with
# how many packets had them, then "done".
# Usage: demo/usb_fs_chip.py, which copies protocol_emulator.py and pico_board.py over

import time

from machine import Pin
from pico_board import PicoSpi
from protocol_emulator import FRAME_STATUS, USB_STATUS, Host

SECONDS = 6
LOAD_MS = 10_000
DP = 12
BASE = 0x100


def main():
    detach = Pin(8, Pin.OUT, value=1)
    print("ready")
    time.sleep_ms(LOAD_MS)
    host = Host(PicoSpi().transfer)
    host.arm_usb(DP, BASE)
    detach(0)
    end = time.ticks_add(time.ticks_ms(), SECONDS * 1000)
    seen = {}
    while time.ticks_diff(end, time.ticks_ms()) > 0:
        status = host.read(FRAME_STATUS)[0]
        if status & (1 << 10):
            flags = host.read(USB_STATUS)[0]
            host.arm_usb(DP, BASE)
            seen[status, flags] = seen.get((status, flags), 0) + 1
    detach(1)
    for (status, flags), count in seen.items():
        print(f"{status:04x} {flags:x} {count}")
    print("done")
    Pin(8, Pin.IN)


main()
