# SPDX-License-Identifier: Apache-2.0
"""A remote lab job on the RTL at 48 MHz, as Pico A runs python/demo_lab.py on the bench:
LAB_FIRMWARE is generate.exe lab's firmware.json, and LAB_OUT gets lab.sr, OUT0 on D4 as
analyser A samples it, and lab.log, the script's log, the names demo/lab.py reads back
from a bench run. test_outside's reset and sampling, without its part models."""

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

# 48 MHz, as the Icepi's PLL makes it
CLOCK_PS = 20834
RATE = int(float(os.environ.get("LAB_RATE", 24e6)))
MS = 48_000
# OUT0 is uo_out[1]; analyser A has it on D4
CHANNEL = 4


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

    def out0():
        text = str(dut.uo_out.value)
        return 0 if text[len(text) - 2] == "0" else 1

    edges = [(0, out0())]

    async def watch():
        while True:
            await dut.uo_out.value_change
            if out0() != edges[-1][1]:
                edges.append((get_sim_time("ps"), out0()))

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
    ends = [at for at, _ in edges[1:]] + [count * period]
    samples = b"".join(
        bytes([level << CHANNEL]) * (min(count, math.ceil(end / period)) - min(count, math.ceil(at / period)))
        for (at, level), end in zip(edges, ends)
    )
    sigrok.write(os.path.join(out, "lab.sr"), RATE, samples)
    with open(os.path.join(out, "lab.log"), "w") as f:
        f.write("\n".join(lines) + "\n")
    assert ok
