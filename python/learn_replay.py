# SPDX-License-Identifier: Apache-2.0
# Pico B plays a transmitter the chip was never told about (MicroPython): replay.json's
# segments, each the lines pulled low and for how many microseconds, from a PIO machine at
# 1 MHz on GP2 (IO3) and GP3 (IO2), open drain against the carrier's pull-ups as an IR
# receiver module's output is. Segments come from public recordings (demo/learn_prepare.py).

import array
import json
import time

import rp2
from machine import Pin

# pull, out and out before the count's first pass, and the count's last pass
OVERHEAD = 4
# demo/capture.sh starts the analyser after mpremote returns, and it takes up to 3 s
START_MS = 3000
# the lines stay at the recording's idle this long after it, past the chip's recording,
# so a line that idles low is low at both of the recording's ends
HOLD_MS = 5000


@rp2.asm_pio(set_init=(rp2.PIO.IN_LOW,) * 2, out_init=(rp2.PIO.IN_LOW,) * 2,
             out_shiftdir=rp2.PIO.SHIFT_RIGHT)
def segments():
    # the pins' values low, so pulling a line low is its direction alone
    set(pins, 0)  # noqa: F821
    wrap_target()  # noqa: F821
    pull(block)  # noqa: F821
    out(pindirs, 2)  # noqa: F821
    out(x, 30)  # noqa: F821
    label("count")  # noqa: F821
    jmp(x_dec, "count")  # noqa: F821
    wrap()  # noqa: F821


def words(segs):
    return [low | ((max(us, OVERHEAD + 1) - OVERHEAD) << 2) for low, us in segs]


def send(segs):
    sm = rp2.StateMachine(0, segments, freq=1_000_000, set_base=Pin(2), out_base=Pin(2))
    sm.active(1)
    sm.put(array.array("I", words(segs)))
    # the last segment is idle, so the lines are released when it starts
    total_ms = sum(us for _, us in segs) // 1000
    time.sleep_ms(total_ms + 20)
    sm.active(0)
    Pin(2, Pin.IN)
    Pin(3, Pin.IN)


if __name__ == "__main__":
    replay = json.load(open("replay.json"))
    segs = replay["segments"]
    send([[segs[0][0], START_MS * 1000]] + segs + [[segs[-1][0], HOLD_MS * 1000], [0, 1000]])
    print("sent %d segments" % len(replay["segments"]))
