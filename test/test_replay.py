# SPDX-License-Identifier: Apache-2.0
# Replays the pin traces in test/traces, recorded from the OCaml simulation of the top
# by test/pin_trace.ml, and compares every output bit on every cycle.
#
# Alignment: cycle 0 of a trace is the first rising edge after rst_n is released. rst_n
# is held low for RESET_CYCLES clocks first, which clears every register that has a
# clear, so the comparison starts at cycle 0 and nothing is masked: an X on an output
# is a mismatch. Inputs change on the falling edge and outputs are sampled on the next
# falling edge, half a cycle after the rising edge they belong to.

from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge

RESET_CYCLES = 5
OUTPUTS = ["uo_out", "uio_out", "uio_oe"]
TRACES = sorted(Path(__file__).parent.glob("traces/*.trace"))


def read_trace(path):
    for line in path.read_text().splitlines():
        if line.startswith("#"):
            continue
        count, *pins = line.split()
        yield int(count), [int(p, 16) for p in pins]


def first_difference(name, expected, actual):
    want = format(expected, "08b")
    for bit in range(8):
        if want[7 - bit] != actual[7 - bit]:
            return f"{name}[{bit}] is {actual[7 - bit]}, expected {want[7 - bit]}"


async def replay(dut, path):
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())
    dut.ena.value = 1
    dut.ui_in.value = 0b100
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    for _ in range(RESET_CYCLES):
        await FallingEdge(dut.clk)
    dut.rst_n.value = 1
    cycle = 0
    for count, (ui_in, uio_in, *expected) in read_trace(path):
        dut.ui_in.value = ui_in
        dut.uio_in.value = uio_in
        for _ in range(count):
            await FallingEdge(dut.clk)
            for name, want in zip(OUTPUTS, expected):
                got = str(getattr(dut, name).value)
                if got != format(want, "08b"):
                    difference = first_difference(name, want, got)
                    assert False, f"{path.name} cycle {cycle}: {difference}"
            cycle += 1
    dut._log.info(f"{path.name}: {cycle} cycles")


def make_test(path):
    async def test(dut):
        await replay(dut, path)

    test.__name__ = test.__qualname__ = f"replay_{path.stem}"
    return cocotb.test()(test)


for trace in TRACES:
    globals()[f"replay_{trace.stem}"] = make_test(trace)
