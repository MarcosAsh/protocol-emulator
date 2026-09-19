# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

HALF = 4
REG_CONTROL = 0x00
REG_STATUS = 0x01
REG_TX = 0x07
REG_PROGRAM_ADDR = 0x09
REG_PROGRAM = 0x0A
REG_CONFIG = 0x10

# Program_config.default, in field order
CONFIG = [0, 5, 0, 0, 5, 1, 5, 1, 0, 0, 1, 1, 1, 0, 16, 0, 16]

# uart tx at 16 cycles per bit, assembled from test/firmware.ml
PROGRAM = [0xa090,0xa001,0x20e0,0xe004,0xa027,0x80e6,0xa000,0xc0ca,0x20c0,0x6001,0x0408,0x20c0,0xa001,0x2040,0x0002]


class Host:
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

    async def frame(self, data):
        self.cs_n = 0
        await self.wait(HALF)
        replies = [await self.byte(b) for b in data]
        await self.wait(HALF)
        self.cs_n = 1
        await self.wait(3)
        return replies

    async def write(self, reg, words):
        data = [0x80 | reg]
        for w in words:
            data += [w >> 8, w & 0xFF]
        await self.frame(data)

    async def read(self, reg):
        hi, lo = (await self.frame([reg, 0, 0]))[1:]
        return (hi << 8) | lo


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


@cocotb.test()
async def test_uart_over_spi(dut):
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

    host = Host(dut)
    for n, value in enumerate(CONFIG):
        await host.write(REG_CONFIG + n, [value])
    await host.write(REG_PROGRAM_ADDR, [0])
    await host.write(REG_PROGRAM, PROGRAM)
    await host.write(REG_TX, [0x55, 0xA3])
    await host.write(REG_CONTROL, [1])

    levels = []
    for _ in range(400):
        await ClockCycles(dut.clk, 1)
        levels.append((int(dut.uo_out.value) >> 1) & 1)
    assert decode_uart(levels, 16) == [0x55, 0xA3], levels
    assert await host.read(REG_STATUS) == 0
