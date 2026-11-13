# SPDX-License-Identifier: Apache-2.0
"""Runs a remote lab job on the RTL at 48 MHz, the way Pico A runs python/demo_lab.py.
LAB_FIRMWARE is generate.exe lab's firmware.json. LAB_OUT receives lab_a.sr and lab_b.sr,
each probe's pin on the channel its analyser samples it on, and lab.log (the script's log).
demo/lab.py reads them back as it does a bench run's. Same reset and sampling as
test_outside, without its part models."""

import json
import math
import os
import sys

import cocotb
from cocotb.clock import Clock
from cocotb.task import bridge, resume
from cocotb.triggers import ClockCycles
from cocotb.utils import get_sim_time

from test import Pins
import demo_lab

sys.path.insert(0, "../demo")
import sigrok  # noqa: E402

# 48 MHz, what the Icepi's PLL produces
CLOCK_PS = 20834
RATE = int(float(os.environ.get("LAB_RATE", 24e6)))
MS = 48_000
# OUTn is uo_out[n + 1]
FIRST_OUTPUT = 5


@cocotb.test()
async def test_lab(dut):
    with open(os.environ["LAB_FIRMWARE"]) as f:
        firmware = json.load(f)
    out = os.environ["LAB_OUT"]
    cocotb.start_soon(Clock(dut.clk, CLOCK_PS, unit="ps").start())
    dut.ena.value = 1
    dut.ui_in.value = 0b100
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)

    # (pin, analyser, channel), OUT0 on A's D4 when firmware.json has no probes
    probes = [(p["pin"], p["analyser"], p["channel"])
              for p in firmware.get("probes", [{"pin": 5, "analyser": "A", "channel": 4}])]

    def level(pin):
        text = str(dut.uo_out.value)
        return 0 if text[len(text) - 2 - (pin - FIRST_OUTPUT)] == "0" else 1

    edges = {pin: [(0, level(pin))] for pin, _, _ in probes}

    async def watch():
        while True:
            await dut.uo_out.value_change
            for pin, changes in edges.items():
                if level(pin) != changes[-1][1]:
                    changes.append((get_sim_time("ps"), level(pin)))

    cocotb.start_soon(watch())
    pins, lines = Pins(dut), []

    @resume
    async def transfer(data):
        return await pins.transfer(data)

    @resume
    async def pause_ms(n):
        await ClockCycles(dut.clk, n * MS)

    def log(text=""):
        cocotb.log.info(text)
        lines.append(text)

    try:
        ok = await bridge(lambda: demo_lab.run(transfer, pause_ms, firmware, log))()
    except Exception as e:
        log("stopped: %s" % e)
        ok = False
    log("PASS" if ok else "FAIL")
    await ClockCycles(dut.clk, 100)
    os.makedirs(out, exist_ok=True)
    period = 10**12 / RATE
    count = int(get_sim_time("ps") // period)
    for analyser in sorted({a for _, a, _ in probes}):
        samples = bytearray(count)
        for pin, a, channel in probes:
            if a != analyser:
                continue
            changes = edges[pin]
            ends = [at for at, _ in changes[1:]] + [count * period]
            for (at, value), end in zip(changes, ends):
                if value:
                    first, last = (min(count, math.ceil(t / period)) for t in (at, end))
                    for i in range(first, last):
                        samples[i] |= 1 << channel
        sigrok.write(os.path.join(out, "lab_%s.sr" % analyser.lower()), RATE, bytes(samples))
    with open(os.path.join(out, "lab.log"), "w") as f:
        f.write("\n".join(lines) + "\n")
    assert ok
