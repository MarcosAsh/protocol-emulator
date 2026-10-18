# SPDX-License-Identifier: Apache-2.0
# Two certified engines at once (MicroPython, Pico A): engine 1 runs the library 1-Wire master
# on the carrier's DS18B20 (IO4), engine 0 the USB keyboard (IO0, IO1) that types what Pico A
# read, "21.4 C" and a return, into whatever has focus on the laptop. Pico A only carries the
# reading from one engine's fifo to the other's; the engines share no wire. USB as demo_usb.
# Untested on a board; test/test_thermometer.py runs `run` on the RTL.

import time

import bench
import bench_firmware
import demo_ds18b20
import demo_usb
import usb_board

ticks_diff = getattr(time, "ticks_diff", lambda a, b: a - b)

# a reading every PERIOD_MS once the laptop has configured the chip, taken in two steps that
# leave USB served meanwhile: CONVERT T, then CONVERT_MS later (750 ms at 12 bits) the read
PERIOD_MS = 4000
CONVERT_MS = 800
# read slots tried to see the conversion done in one round, before USB gets its turn
POLLS = 20

# HID usage ids: digits 1 to 9 then 0, and the rest of "21.4 C" and its return
KEYS = {c: 0x1E + i for i, c in enumerate("1234567890")}
KEYS.update({"\n": 0x28, " ": 0x2C, "-": 0x2D, ".": 0x37, "C": 0x06})
SHIFT = 0x02


def text(raw):
    """A reading as typed: the 1/16 C counts rounded to a tenth, so 0x0156 is 21.4 C."""
    tenths = (abs(raw) * 10 + 8) // 16
    return "%s%d.%d C\n" % ("-" if raw < 0 and tenths else "", tenths // 10, tenths % 10)


def reports(line):
    """Each character pressed and released, with shift held for a capital."""
    queue = []
    for c in line:
        shift = SHIFT if c == "C" else 0
        queue += [[1, shift, KEYS[c], 0, 0, 0, 0, 0], [1, 0, 0, 0, 0, 0, 0, 0]]
    return queue


class Thermometer:
    """Engine 1 on the DS18B20, a step a round of demo_usb.serve. Idle until the laptop has
    bound the keyboard and the last line is typed, then CONVERT T, then the scratchpad, and
    the line goes on `queue`. Engine 0 is selected again before every step returns."""

    def __init__(self, host, board, queue, ms, say=print, period_ms=PERIOD_MS, convert_ms=CONVERT_MS):
        self.host, self.board, self.queue, self.ms, self.say = host, board, queue, ms, say
        self.period_ms, self.convert_ms = period_ms, convert_ms
        self.wire = demo_ds18b20.Wire(host)
        self.converting, self.at = False, None

    def start(self):
        """Engine 1 loaded and running the library 1-Wire master, which takes its unit
        first. Both engines are stopped by this, so before engine 0 serves."""
        bench.load(self.host, bench_firmware.ONE_WIRE, engine=1)
        self.host.start()
        self.host.push([demo_ds18b20.UNIT])
        self.host.select(0)

    def step(self):
        board = self.board
        if not (board.configured and board.described):
            self.at = None
            return
        now = self.ms()
        if self.at is None:
            self.at = now
        if ticks_diff(now, self.at) < 0 or self.queue or board.pending_report is not None:
            return
        self.host.select(1)
        try:
            if self.converting:
                self.read(now)
            else:
                self.convert(now)
        finally:
            self.host.select(0)

    def convert(self, now):
        wire = self.wire
        if not wire.reset():
            self.say("no presence pulse: check DQ, the 4.7 k pull-up and 3.3 V on VDD")
            self.at = now + self.period_ms
            return
        wire.write([demo_ds18b20.SKIP_ROM, demo_ds18b20.CONVERT_T])
        self.converting, self.at = True, now + self.convert_ms

    def read(self, now):
        wire, host = self.wire, self.host
        # a converting DS18B20 holds read slots low, and lets them go once it is done
        for _ in range(POLLS):
            if wire.read(1)[0]:
                break
        else:
            self.at = now + 50
            return
        self.converting = False
        wire.reset()
        wire.write([demo_ds18b20.SKIP_ROM, demo_ds18b20.READ_SCRATCHPAD])
        pad = wire.read(9)
        raw = demo_ds18b20.temperature(pad)
        found = bench.faults(host)
        self.at = now + self.period_ms
        if found:
            self.say("engine 1 faults 0x%x: reset the chip" % found)
        elif demo_ds18b20.crc8(pad) or raw == demo_ds18b20.POWER_ON:
            self.say("scratchpad %s: CRC bad or still the power-on value" % bench.hexs(pad))
        else:
            line = text(raw)
            self.say("read %d/16 C, typing %s" % (raw, line.strip()))
            self.queue.extend(reports(line))


def run(say=print):
    """On the Icepi Zero, from the host Pico. Reset the chip first, as faults hold until
    reset, and the Icepi's first USB port is attached from here once engine 0 serves."""
    host, bus_reset, attach, replug = demo_usb.pico_a()
    board, queue = usb_board.Board(demo_usb.DESCRIPTORS), []
    thermometer = Thermometer(host, board, queue, time.ticks_ms, say)
    thermometer.start()
    demo_usb.serve(host, board, queue, bus_reset, say=say, attach=attach, replug=replug,
                   tick=thermometer.step)


if __name__ == "__main__":
    run()
