# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

import sys

sys.path.insert(0, "../python")
from protocol_emulator import CONTROL, DATA, DATA_ADDR, DEFAULT_CONFIG, PROGRAM_ADDR, PROGRAM as PROGRAM_REG, STATUS, TX, Host, config_writes

HALF = 4


def assembled(name):
    """The words `make firmware` assembles from the .asm of the same name."""
    with open(f"{name}.hex") as f:
        return [int(line, 16) for line in f]


PROGRAM = assembled("uart_tx")


class Pins:
    def __init__(self, dut):
        self.dut = dut
        self.sck = 0
        self.mosi = 0
        self.cs_n = 1

    def drive(self):
        self.dut.ui_in.value = (self.cs_n << 2) | (self.mosi << 1) | self.sck

    async def wait(self, n):
        self.drive()
        await ClockCycles(self.dut.clk, n)

    async def byte(self, out):
        acc = 0
        for b in range(7, -1, -1):
            self.mosi = (out >> b) & 1
            await self.wait(HALF)
            # MISO alone: the other outputs may not have been driven yet
            bit = 1 if str(self.dut.uo_out.value)[-1] == "1" else 0
            self.sck = 1
            await self.wait(HALF)
            self.sck = 0
            acc = (acc << 1) | bit
        return acc

    async def transfer(self, data):
        self.cs_n = 0
        await self.wait(HALF)
        replies = [await self.byte(b) for b in data]
        await self.wait(HALF)
        self.cs_n = 1
        await self.wait(3)
        return replies


class AsyncHost(Host):
    """The library is synchronous; under cocotb every call becomes an await."""

    async def write(self, reg, words):
        data = [0x80 | reg]
        for w in words:
            data += [(w >> 8) & 0xFF, w & 0xFF]
        await self.transfer(data)

    async def read(self, reg, count=1):
        reply = (await self.transfer([reg] + [0] * (2 * count)))[1:]
        return [(reply[i] << 8) | reply[i + 1] for i in range(0, 2 * count, 2)]


def decode_uart(levels, period):
    frames = []
    i = 0
    while i + 10 * period <= len(levels):
        if levels[i] == 0 and (i == 0 or levels[i - 1] == 1):
            byte = 0
            for b in range(8):
                byte |= levels[i + (b + 1) * period + period // 2] << b
            frames.append(byte)
            i += 10 * period
        else:
            i += 1
    return frames


async def reset(dut):
    clock = Clock(dut.clk, 20, unit="ns")
    cocotb.start_soon(clock.start())
    dut.ena.value = 1
    dut.ui_in.value = 0b100
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)
    assert int(dut.uio_oe.value) == 0


@cocotb.test()
async def test_uart_over_spi(dut):
    await reset(dut)

    host = AsyncHost(Pins(dut).transfer)
    for reg, word in config_writes(DEFAULT_CONFIG):
        await host.write(reg, [word])
    await host.write(PROGRAM_ADDR, [0])
    await host.write(PROGRAM_REG, PROGRAM)
    await host.write(TX, [0x55, 0xA3])
    await host.write(CONTROL, [1])

    levels = []
    for _ in range(400):
        await ClockCycles(dut.clk, 1)
        levels.append((int(dut.uo_out.value) >> 1) & 1)
    assert decode_uart(levels, 16) == [0x55, 0xA3], levels
    assert (await host.read(STATUS))[0] == 0


@cocotb.test()
async def test_fractional_period(dut):
    """115200 baud at 48 MHz: 416 and 43691/65536 cycles a bit, as the OCaml model gives.

    The start bit is a whole period; the fraction carries a cycle into two bits in three.
    """
    await reset(dut)

    host = AsyncHost(Pins(dut).transfer)
    config = dict(DEFAULT_CONFIG, period_fraction=43691)
    for reg, word in config_writes(config):
        await host.write(reg, [word])
    await host.write(PROGRAM_ADDR, [0])
    await host.write(PROGRAM_REG, assembled("uart_tx_host_rate"))
    await host.write(TX, [416, 0x55])
    await host.write(CONTROL, [1])

    edges = []
    previous = 0
    for cycle in range(12 * 417):
        await ClockCycles(dut.clk, 1)
        level = (int(dut.uo_out.value) >> 1) & 1
        if level != previous:
            edges.append(cycle)
        previous = level
    # the line going idle, then the start bit and the eight data bits of 0x55
    lengths = [b - a for a, b in zip(edges[1:], edges[2:])]
    assert lengths == [416, 416, 417, 417, 416, 417, 417, 416, 417], lengths
    assert (await host.read(STATUS))[0] == 0


@cocotb.test()
async def test_data_memory(dut):
    """The host fills the data memory and the program streams it out with autopull."""
    await reset(dut)

    host = AsyncHost(Pins(dut).transfer)
    config = dict(DEFAULT_CONFIG, out_base=12, out_count=8, autopull=1, autopull_data=1)
    for reg, word in config_writes(config):
        await host.write(reg, [word])
    await host.write(PROGRAM_ADDR, [0])
    await host.write(PROGRAM_REG, assembled("data_stream"))
    await host.write(DATA_ADDR, [0])
    await host.write(DATA, [0x2211, 0x4433, 0x6655, 0x8877])
    assert (await host.read(DATA_ADDR))[0] == 4, "the address counts the words written"
    await host.write(CONTROL, [1])

    # a byte every six cycles; past the four words written the memory holds nothing
    shown = []
    for _ in range(100):
        if len(shown) == 8:
            break
        await ClockCycles(dut.clk, 1)
        byte = int(dut.uio_out.value)
        if not shown or shown[-1] != byte:
            shown.append(byte)
    assert shown == [0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88], shown
    assert (await host.read(STATUS))[0] & 0x3D == 0, "running, no fault"


WRAPPED_LOOP = assembled("wrapped_loop")


@cocotb.test()
async def test_wrapped_loop(dut):
    await reset(dut)

    host = AsyncHost(Pins(dut).transfer)
    config = dict(DEFAULT_CONFIG, in_base=5, wrap_bottom=3, wrap_top=4)
    for reg, word in config_writes(config):
        await host.write(reg, [word])
    await host.write(PROGRAM_ADDR, [0])
    await host.write(PROGRAM_REG, WRAPPED_LOOP)
    await host.write(CONTROL, [1])

    await ClockCycles(dut.clk, 20)
    levels = []
    for _ in range(40):
        await ClockCycles(dut.clk, 1)
        levels.append((int(dut.uo_out.value) >> 1) & 1)
    assert levels in ([0, 0, 1, 1] * 10, [0, 1, 1, 0] * 10, [1, 1, 0, 0] * 10, [1, 0, 0, 1] * 10), levels
    assert (await host.read(STATUS))[0] == 0


I2C_START_WATCH = assembled("i2c_start_watch")
# The latency Predicate.compile certifies, from the core's first sample of the SDA fall to
# the verdict's issue; the pads add the two synchroniser flops and the pin register.
WATCH_LATENCY = 10
PAD_LATENCY = WATCH_LATENCY + 3


@cocotb.test()
async def test_i2c_start_watch(dut):
    """Every SDA fall while SCL is high pulses OUT0 a fixed 13 cycles later, and nothing else."""
    await reset(dut)

    host = AsyncHost(Pins(dut).transfer)
    config = dict(DEFAULT_CONFIG, jmp_pin=1)
    for reg, word in config_writes(config):
        await host.write(reg, [word])
    await host.write(PROGRAM_ADDR, [0])
    await host.write(PROGRAM_REG, I2C_START_WATCH)
    await host.write(CONTROL, [1])

    # (sda, scl, cycles): a start, a byte's worth of data changes while SCL is low, a
    # repeated start, a stop, and an SDA fall while SCL is low
    bit = [(0, 0, 12), (0, 1, 12), (1, 1, 12), (1, 0, 12)]
    waveform = [(1, 1, 30), (0, 1, 30), (0, 0, 20)] + bit * 4
    waveform += [(1, 0, 12), (1, 1, 30), (0, 1, 30), (0, 0, 20), (0, 1, 20), (1, 1, 30)]
    waveform += [(1, 0, 20), (0, 0, 20), (1, 0, 20), (1, 1, 40)]
    starts, verdicts = [], []
    cycle, sda, scl, previous = 0, 1, 1, 0
    for next_sda, next_scl, cycles in waveform:
        if sda == 1 and next_sda == 0 and next_scl == 1:
            starts.append(cycle)
        sda, scl = next_sda, next_scl
        for _ in range(cycles):
            dut.ui_in.value = 0b100 | (sda << 3) | (scl << 4)
            await ClockCycles(dut.clk, 1)
            level = (int(dut.uo_out.value) >> 1) & 1
            if level and not previous:
                verdicts.append(cycle)
            previous = level
            cycle += 1
    assert len(starts) == 2
    assert [v - s for s, v in zip(starts, verdicts)] == [PAD_LATENCY] * 2, (starts, verdicts)
    assert len(verdicts) == 2, verdicts
    assert (await host.read(STATUS))[0] & 0x3D == 0, "running, no fault"


QUIET_WATCH = assembled("quiet_watch")
# Predicate.compile's window for "pin 2 stops moving" at latency 20: the verdict issues 20
# to 24 cycles after the core samples the last edge, or 23 to 27 at the pads, if every run
# of the pin lasts 5 cycles; an edge in the last 2 cycles, 5 at the pads, goes unseen.
QUIET_WINDOW = (20 + 3, 24 + 3)
QUIET_UNSEEN = 2 + 3


@cocotb.test()
async def test_quiet_watch(dut):
    """A verdict for every run of pin 2 longer than the window, in it, and for no other."""
    await reset(dut)

    host = AsyncHost(Pins(dut).transfer)
    config = dict(DEFAULT_CONFIG, jmp_pin=2, wrap_bottom=3, wrap_top=22)
    for reg, word in config_writes(config):
        await host.write(reg, [word])
    await host.write(PROGRAM_ADDR, [0])
    await host.write(PROGRAM_REG, QUIET_WATCH)
    await host.write(CONTROL, [1])

    runs = [40, 10, 5, 30, 22, 50, 7, 26, 60, 9, 23, 28, 45, 5, 6, 33]
    changes, verdicts = [], []
    cycle, level, previous = 0, 0, 0
    for n, length in enumerate(runs):
        if n > 0:
            level ^= 1
            changes.append(cycle)
        for _ in range(length):
            dut.ui_in.value = 0b100 | (level << 5)
            await ClockCycles(dut.clk, 1)
            verdict = (int(dut.uo_out.value) >> 1) & 1
            if verdict and not previous:
                verdicts.append(cycle)
            previous = verdict
            cycle += 1
    low, high = QUIET_WINDOW
    answered = []
    for v in verdicts:
        seen = [c for c in changes if c <= v - QUIET_UNSEEN]
        if seen:
            assert low <= v - seen[-1] <= high, (v, seen[-1])
            answered.append(seen[-1])
    assert len(answered) == len(set(answered)), answered
    for c, n in zip(changes, changes[1:] + [cycle]):
        if n - c > high and c + high < cycle:
            assert c in answered, (c, verdicts)
    assert len(answered) >= 6, verdicts
    assert (await host.read(STATUS))[0] & 0x3D == 0, "running, no fault"
