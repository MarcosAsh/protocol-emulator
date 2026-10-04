# SPDX-License-Identifier: Apache-2.0
# Replays test/traces (from test/pin_trace.ml) and compares every output bit every cycle.
# Cycle 0 is the first rising edge after RESET_CYCLES of reset, which clears every
# register with a clear; nothing is masked, so an X is a mismatch.
# Unwritten storage is X here but zero in OCaml: test/pin_scenarios.ml avoids the one
# known case, an rx read that empties the fifo. Inputs change on the falling edge;
# outputs are sampled on the next falling edge.
# REPLAY_TRACES gives other globs under test/; REPLAY_RECORD a folder where each trace is
# written again with the outputs the netlist drove, an x or z as 0, for demo/decode.py.
# A trace that differs still runs to its end and is written, then fails.

import os
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge

RESET_CYCLES = 5
OUTPUTS = ["uo_out", "uio_out", "uio_oe"]
HERE = Path(__file__).parent
TRACES = sorted(
    trace
    for pattern in os.environ.get("REPLAY_TRACES", "traces/*.trace").split()
    for trace in HERE.glob(pattern)
)
RECORD = os.environ.get("REPLAY_RECORD")


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


def record(path, cycles):
    """The trace's header, then one line per run of cycles with the same pins."""
    lines = [line for line in path.read_text().splitlines() if line.startswith("#")]
    lines.insert(1, "# replayed by test/test_replay.py: the outputs are the netlist's")
    runs = []
    for pins in cycles:
        if runs and runs[-1][1] == pins:
            runs[-1][0] += 1
        else:
            runs.append([1, pins])
    lines += [f"{count} " + " ".join(f"{p:02x}" for p in pins) for count, pins in runs]
    folder = HERE / RECORD
    folder.mkdir(parents=True, exist_ok=True)
    (folder / path.name).write_text("\n".join(lines) + "\n")


async def replay(dut, path):
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())
    dut.ena.value = 1
    dut.ui_in.value = 0b100
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    for _ in range(RESET_CYCLES):
        await FallingEdge(dut.clk)
    dut.rst_n.value = 1
    cycles = []
    difference = None
    for count, (ui_in, uio_in, *expected) in read_trace(path):
        dut.ui_in.value = ui_in
        dut.uio_in.value = uio_in
        for _ in range(count):
            await FallingEdge(dut.clk)
            driven = []
            for name, want in zip(OUTPUTS, expected):
                got = str(getattr(dut, name).value)
                if difference is None and got != format(want, "08b"):
                    difference = f"cycle {len(cycles)}: {first_difference(name, want, got)}"
                driven.append(int("".join(b if b in "01" else "0" for b in got), 2))
            cycles.append((ui_in, uio_in, *driven))
    if RECORD:
        record(path, cycles)
    dut._log.info(f"{path.name}: {len(cycles)} cycles")
    assert difference is None, f"{path.name} {difference}"


def make_test(path):
    async def test(dut):
        await replay(dut, path)

    test.__name__ = test.__qualname__ = f"replay_{path.stem}"
    return cocotb.test()(test)


for trace in TRACES:
    globals()[f"replay_{trace.stem}"] = make_test(trace)
