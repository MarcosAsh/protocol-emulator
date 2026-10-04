# SPDX-License-Identifier: Apache-2.0
"""python/demo_board.py and demo_board_check.py on the RTL, run blocking in a thread as the
demo board's RP2 runs them, over test/python/ttboard_fake.py's PIO interpreter. The chip's
clock is the testbench's 50 MHz, which the PWM is asked for."""

import sys

import cocotb
from cocotb.task import bridge, resume
from cocotb.triggers import Timer
from cocotb.utils import get_sim_time

from test import reset
import protocol_emulator as pe

sys.path.insert(0, "python")
import ttboard_fake  # noqa: E402

CLOCK_HZ = 50_000_000


def bits(signal):
    """A port's value with X and Z read as 0: outputs not yet driven."""
    return int("".join("1" if c == "1" else "0" for c in str(signal.value)), 2)


class Rtl:
    def __init__(self, dut):
        self.dut, self.carry = dut, 0
        self.run_blocking = resume(self._run)

    def run(self, board, ticks, stop=None):
        assert board.clock_hz in (0, CLOCK_HZ), board.clock_hz
        self.run_blocking(board, ticks, stop)

    async def _run(self, board, ticks, stop):
        for wait in board.events(ticks, stop):
            if wait:
                ps, self.carry = divmod(self.carry + wait * 10**12, board.sys_hz)
                if ps:
                    await Timer(ps, "ps")

    def drive(self, ui, rst_n):
        self.dut.ui_in.value = ui
        self.dut.rst_n.value = rst_n

    def pads(self):
        return bits(self.dut.uo_out), bits(self.dut.uio_out)


async def watch_out0(dut, edges):
    """(ns, level) of each change on uo[1]."""
    while True:
        await dut.uo_out.value_change
        level = bits(dut.uo_out) >> 1 & 1
        if level != edges[-1][1]:
            edges.append((get_sim_time("ns"), level))


def uart_bytes(edges, bit_ns):
    """Frames from the line's edges, each bit read mid-period from its start bit."""
    def level(at):
        return [lv for t, lv in edges if t <= at][-1]

    found, at = [], 0
    for t, lv in edges[1:]:
        if lv == 0 and t >= at:
            found.append(sum(level(t + (1.5 + i) * bit_ns) << i for i in range(8)))
            at = t + 9.5 * bit_ns
    return found


@cocotb.test()
async def test_bringup_check(dut):
    """The check passes, and the frames its PIO read are the ones on the pad."""
    await reset(dut)
    board = ttboard_fake.Board(Rtl(dut))
    loaded = board.install()
    edges = [(0, 0)]
    watcher = cocotb.start_soon(watch_out0(dut, edges))
    said = []
    try:
        ok = await bridge(loaded.demo_board_check.run)(
            clock_hz=CLOCK_HZ, window_ms=1, say=said.append)
    finally:
        watcher.cancel()
        board.uninstall()
    dut._log.info("\n".join(said))
    assert ok, said
    period = (CLOCK_HZ + 57_600) // 115_200
    assert period == 434
    assert uart_bytes(edges, period * 20) == loaded.demo_board_check.BYTES, edges


@cocotb.test()
async def test_fastest_sck(dut):
    """SCK at the limit, a twelfth of the clock, on the RP2040 board's pin map: a full
    program load and every read back intact."""
    await reset(dut)
    board = ttboard_fake.Board(Rtl(dut), kind="tt06")
    loaded = board.install()

    def traffic():
        spi = loaded.demo_board.DemoBoardSpi(clock_hz=CLOCK_HZ, sck_hz=CLOCK_HZ // 12)
        host = pe.Host(spi.transfer)
        words = [(i * 0x9E37) & 0xFFFF for i in range(512)]
        host.load(words)
        got = [host.read(pe.PROGRAM_ADDR)[0], host.read(pe.STATUS)[0]]
        for word in (0x1A5, 0x05A, 0x1FF):
            host.write(pe.PROGRAM_ADDR, [word])
            got += host.read(pe.PROGRAM_ADDR)
        return got

    try:
        got = await bridge(traffic)()
    finally:
        board.uninstall()
    assert got == [0, 1, 0x1A5, 0x05A, 0x1FF], got
