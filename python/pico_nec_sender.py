# SPDX-License-Identifier: Apache-2.0
# A NEC remote for the chip's receiver (MicroPython, Pico B): GP2 pulled low for a mark,
# open drain against the carrier's pull-up on IO3, as an IR receiver module's output. demo_nec's
# keys, a frame or repeat code every 108 ms, from a PIO machine at 1 MHz so each mark and
# space is its length to the microsecond.

import rp2
import time
from machine import Pin

# demo_nec's, which imports more than Pico B needs
KEYS = [(0x04, 0x08, 2), (0x00, 0x45, 0), (0xFF, 0x00, 0)]
PERIOD_MS = 108
# 562.5 us, a mark and a space rounded each way so a bit keeps its 1125 or 2250 us
MARK, ZERO, ONE = 563, 562, 1687
LEADER, LEADER_SPACE, REPEAT_SPACE = 9000, 4500, 2250
PERIOD_US = PERIOD_MS * 1000
# pull, out and out before the count's first loop, and the loop's last pass
OVERHEAD = 4


@rp2.asm_pio(set_init=rp2.PIO.IN_LOW, out_init=rp2.PIO.IN_LOW, out_shiftdir=rp2.PIO.SHIFT_RIGHT)
def segments():
    # the pin's value low, so a mark is its direction alone
    set(pins, 0)  # noqa: F821
    wrap_target()  # noqa: F821
    pull(block)  # noqa: F821
    out(pindirs, 1)  # noqa: F821
    out(x, 31)  # noqa: F821
    label("count")  # noqa: F821
    jmp(x_dec, "count")  # noqa: F821
    wrap()  # noqa: F821


def word(mark, us):
    return int(mark) | ((us - OVERHEAD) << 1)


def frame(address, command):
    out = [(True, LEADER), (False, LEADER_SPACE)]
    for byte in (address, ~address & 0xFF, command, ~command & 0xFF):
        for k in range(8):
            out += [(True, MARK), (False, ONE if byte >> k & 1 else ZERO)]
    return out + [(True, MARK)]


def repeat():
    return [(True, LEADER), (False, REPEAT_SPACE), (True, MARK)]


def send(keys=KEYS):
    sm = rp2.StateMachine(0, segments, freq=1_000_000, set_base=Pin(2), out_base=Pin(2))
    sm.active(1)
    for address, command, repeats in keys:
        for segs in [frame(address, command)] + [repeat()] * repeats:
            start = time.ticks_us()
            for mark, us in segs:
                sm.put(word(mark, us))
            # the rest of the 108 ms released, from the frame's start
            left = PERIOD_US - sum(us for _, us in segs)
            sm.put(word(False, left))
            while time.ticks_diff(time.ticks_us(), start) < PERIOD_US - 20_000:
                time.sleep_ms(1)
    time.sleep_ms(PERIOD_MS)
    sm.active(0)
    Pin(2, Pin.IN)
    print("sent", keys)


if __name__ == "__main__":
    # demo/capture.sh starts the analyser after mpremote returns, as bench.START_MS
    time.sleep_ms(1000)
    send()
