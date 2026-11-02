# SPDX-License-Identifier: Apache-2.0
# Pico B as the receiver of what the chip says (MicroPython): every edge on GP1, which is
# OUT0 through 1k, timestamped in microseconds for LISTEN_MS, then written as listen.edges
# for the host to read with what it learned.

import array
import time

from machine import Pin

LISTEN_MS = 6000
MOST = 8000


def listen(ms=LISTEN_MS):
    pin = Pin(1, Pin.IN)
    stamps = array.array("i", [0] * MOST)
    count = [0]

    def edge(_):
        n = count[0]
        if n < MOST:
            stamps[n] = time.ticks_us()
            count[0] = n + 1

    start = time.ticks_us()
    first = pin.value()
    pin.irq(edge, Pin.IRQ_RISING | Pin.IRQ_FALLING, hard=True)
    time.sleep_ms(ms)
    pin.irq(None)
    n = count[0]
    edges = [time.ticks_diff(stamps[i], start) for i in range(n)]
    with open("listen.edges", "w") as f:
        f.write("rate 1000000\nlength %d\npin OUT0 %d %s\n" % (
            (edges[-1] + 1) if edges else 1, first, " ".join(str(e) for e in edges)))
    print("%d edges on OUT0" % n)


if __name__ == "__main__":
    listen()
