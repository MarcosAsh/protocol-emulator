# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

import sys

sys.path.insert(0, "../python")
from protocol_emulator import CONFIG, CONFIG_FIELDS, CONTROL, DEFAULT_CONFIG, PROGRAM_ADDR, PROGRAM as PROGRAM_REG, STATUS, TX, Host

HALF = 4

# uart tx at 16 cycles per bit, assembled from test/firmware.ml
PROGRAM = [0xa090, 0xa001, 0x20e0, 0xe004, 0xa027, 0x80e6, 0xa000, 0xc0ca, 0x20c0, 0x6001,
           0x0408, 0x20c0, 0xa001, 0x2040, 0x0002]


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
            bit = int(self.dut.uo_out.value) & 1
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


# set p, 2 / mov t, now / add t, p / .wrap_target / wait t+ / mov pins, !pins / .wrap
WRAPPED_LOOP = [0xa082, 0x80e6, 0xc0ca, 0x20c0, 0x8008]


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
