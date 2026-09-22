# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

import sys

sys.path.insert(0, "../python")
from protocol_emulator import CONFIG, CONFIG_FIELDS, CONTROL, COUNTS, DATA, DATA_ADDR, DEFAULT_CONFIG, PC, PROGRAM_ADDR, PROGRAM as PROGRAM_REG, STATUS, TX, X, Host

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
    for n, name in enumerate(CONFIG_FIELDS):
        await host.write(CONFIG + n, [DEFAULT_CONFIG.get(name, 0)])
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
    """115200 baud from 48 MHz is 416 2/3 cycles a bit: 416 and a fraction of 43691/65536.

    The start bit is a whole period; after it the fraction carries a cycle into two bits
    in three, the lengths the OCaml model gives.
    """
    await reset(dut)

    host = AsyncHost(Pins(dut).transfer)
    config = dict(DEFAULT_CONFIG, period_fraction=43691)
    for n, name in enumerate(CONFIG_FIELDS):
        await host.write(CONFIG + n, [config.get(name, 0)])
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
async def test_debugger(dut):
    """Run to a breakpoint, look at the registers, step once, run to it again, then clear
    it and run to the halt at the end, all over SPI."""
    await reset(dut)

    host = AsyncHost(Pins(dut).transfer)
    config = dict(DEFAULT_CONFIG, break_enable=1, break_pc=2)
    for n, name in enumerate(CONFIG_FIELDS):
        await host.write(CONFIG + n, [config.get(name, 0)])
    await host.write(PROGRAM_ADDR, [0])
    await host.write(PROGRAM_REG, assembled("debug_loop"))
    await host.write(CONTROL, [1])

    async def stopped():
        status = (await host.read(STATUS))[0]
        return status & 1, (await host.read(PC))[0], (await host.read(X))[0]

    out0 = lambda: (int(dut.uo_out.value) >> 1) & 1
    assert await stopped() == (1, 2, 3), "at the breakpoint before the first pass"
    assert out0() == 1
    await host.write(CONTROL, [32])
    assert await stopped() == (1, 3, 3), "one step on, past the breakpoint"
    assert out0() == 0
    await host.write(CONTROL, [16])
    assert await stopped() == (1, 2, 2), "round the loop to the breakpoint again"
    assert (await host.read(COUNTS))[0] == 16 << 8, "osr full, isr empty"
    await host.write(CONFIG + CONFIG_FIELDS.index("break_enable"), [0])
    await host.write(CONTROL, [16])
    assert await stopped() == (1, 5, 0xFFFF), "past the halt, the counter run out"
    assert (await host.read(STATUS))[0] & 0x3E == 0, "no fault and no irq"


@cocotb.test()
async def test_data_memory(dut):
    """The host fills the data memory and the program streams it out with autopull."""
    await reset(dut)

    host = AsyncHost(Pins(dut).transfer)
    config = dict(DEFAULT_CONFIG, out_base=12, out_count=8, autopull=1, autopull_data=1)
    for n, name in enumerate(CONFIG_FIELDS):
        await host.write(CONFIG + n, [config.get(name, 0)])
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
    for n, name in enumerate(CONFIG_FIELDS):
        await host.write(CONFIG + n, [config.get(name, 0)])
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
