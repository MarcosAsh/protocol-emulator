# SPDX-License-Identifier: Apache-2.0
"""The board-blame meter against an open-drain bus whose pull-up charges the line: a pad
reads high a fixed R C ln(1 / (1 - threshold)) after the chip lets go of it."""

import math

import cocotb
from cocotb.triggers import ClockCycles, First, Timer

from test import AsyncHost, Pins, assembled, reset
import board_blame
from board_blame import SCL, SDA, i2c_word
from protocol_emulator import CONTROL, PROGRAM, PROGRAM_ADDR, RX, SELECT, STATUS, TX, config_writes

CLOCK_HZ = 50_000_000
THRESHOLD = 0.5
BUS_PF = 20
FIRST_IO = 12  # pin 12 is uio[0]
WORDS = [i2c_word(0xA0, start=True), i2c_word(0x5A, stop=True)]


def rise_ns(ohms, pf=BUS_PF):
    return ohms * pf * 1e-3 * -math.log(1 - THRESHOLD)


class Bus:
    """uio[bit] reads 0 while the chip pulls it low and 1 once it has been let go for
    [rise_ns[bit]]; nothing else drives it."""

    def __init__(self, dut, rise_ns):
        self.dut = dut
        self.rise_ns = rise_ns
        self.level = 0
        self.released_at = {}
        dut.uio_in.value = 0

    def update(self):
        oe, out = int(self.dut.uio_oe.value), int(self.dut.uio_out.value)
        for bit, delay in self.rise_ns.items():
            if oe >> bit & 1:
                self.released_at.pop(bit, None)
                self.set(bit, out >> bit & 1)
            elif bit not in self.released_at:
                self.released_at[bit] = object()
                cocotb.start_soon(self.rise(bit, delay, self.released_at[bit]))

    async def rise(self, bit, delay, token):
        if delay:
            await Timer(round(delay * 1000), unit="ps")
        if self.released_at.get(bit) is token:
            self.set(bit, 1)

    def set(self, bit, level):
        self.level = (self.level & ~(1 << bit)) | (level << bit)
        self.dut.uio_in.value = self.level

    async def run(self):
        while True:
            self.update()
            await First(self.dut.uio_oe.value_change, self.dut.uio_out.value_change)


async def load(host, engine, config, words):
    await host.write(SELECT, [engine])
    for reg, word in config_writes(config):
        await host.write(reg, [word])
    await host.write(PROGRAM_ADDR, [0])
    await host.write(PROGRAM, words)


async def rx_level(host):
    return ((await host.read(STATUS))[0] >> 10) & 15


async def measure(dut, scl_ns):
    """The meter's words for WORDS, read once the master has pushed a word per byte."""
    await reset(dut)
    bus = Bus(dut, {SCL - FIRST_IO: scl_ns, SDA - FIRST_IO: rise_ns(2200)})
    cocotb.start_soon(bus.run())
    host = AsyncHost(Pins(dut).transfer)

    await load(host, 0, board_blame.MASTER_CONFIG, assembled("i2c_master_marked"))
    await load(host, 1, board_blame.METER_CONFIG, assembled("scl_rise"))
    await host.write(SELECT, [0])
    await host.write(CONTROL, [1])
    await host.write(SELECT, [1])
    await host.write(CONTROL, [1])
    await host.write(SELECT, [0])
    await host.write(TX, WORDS)
    for _ in range(100):
        if await rx_level(host) == len(WORDS):
            break
        await ClockCycles(dut.clk, 200)
    faults = [(await host.read(STATUS))[0] & 0x3C]

    await host.write(SELECT, [1])
    stamps = await host.read(RX, await rx_level(host))
    faults.append((await host.read(STATUS))[0] & 0x3C)
    assert faults == [0, 0], f"faults {faults}"
    with open("i2c_master_marked.asm") as f:
        names = board_blame.releases(f.read())
    return names, board_blame.release_pcs(WORDS, names), stamps


def verdicts(dut, names, pcs, stamps, pull_up):
    out = []
    for pc, cycles in zip(pcs, stamps):
        v = board_blame.verdict(cycles, clock_hz=CLOCK_HZ, threshold=THRESHOLD, pull_up=pull_up)
        dut._log.info(board_blame.describe(pc, names[pc], v))
        out.append(v)
    return out


async def check_rise(dut, ohms):
    scl_ns = rise_ns(ohms)
    names, pcs, stamps = await measure(dut, scl_ns)
    assert (len(pcs), len(stamps)) == (19, 8), (len(pcs), len(stamps))
    vs = verdicts(dut, names, pcs, stamps, ohms)
    for v in vs:
        assert v["rose"] and v["low_ns"] <= scl_ns < v["high_ns"], (scl_ns, v)
        assert abs(v["bus_pf"] - BUS_PF) / BUS_PF < 0.1, v
    return vs


@cocotb.test()
async def test_zero_load(dut):
    """A line that rises at once reads ZERO_LOAD: the chip's own part of every word."""
    _, _, stamps = await measure(dut, 0)
    assert stamps == [board_blame.ZERO_LOAD] * 8, stamps


@cocotb.test()
async def test_strong_pull_up_passes(dut):
    vs = await check_rise(dut, 2200)
    assert not any(v["board"] for v in vs)


@cocotb.test()
async def test_weak_pull_up_blames_the_board(dut):
    """47 k on 20 pF: about 650 ns to half the supply, 800 ns 30-70 %, over fast mode's
    300 ns and under standard mode's 1000 ns."""
    vs = await check_rise(dut, 47_000)
    assert all(v["board"] for v in vs)
    assert not any(board_blame.verdict(v["cycles"], clock_hz=CLOCK_HZ, mode="standard")["board"] for v in vs)


@cocotb.test()
async def test_line_that_never_rises_in_time(dut):
    """47 k on 100 pF takes 3.3 us, longer than the 1.2 us high time: only the stop, which
    leaves SCL released, lets the pad rise, and the first release's word says so."""
    names, pcs, stamps = await measure(dut, rise_ns(47_000, pf=100))
    assert len(stamps) == 1, stamps
    (v,) = verdicts(dut, names, pcs, stamps, 47_000)
    assert not v["rose"] and v["board"]
