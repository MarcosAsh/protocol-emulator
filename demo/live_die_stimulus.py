# SPDX-License-Identifier: Apache-2.0
# The live die's run: loads uart_tx over SPI, has the chip check it against its
# certificate, starts it, then feeds it "Jane St!" while it sends. Writes the pins at every falling edge to $LIVE_DIE_PINS, so the RTL and gate-level
# runs can be compared cycle by cycle. demo/live_die.py runs it on both.

import json
import os

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, FallingEdge

from protocol_emulator import (
    CHECK_STATUS,
    CONTROL,
    DEFAULT_CONFIG,
    PROGRAM,
    PROGRAM_ADDR,
    PROGRAM_WORDS,
    REJECT_PC,
    REJECT_REASON,
    STATUS,
    TX,
    Host,
    certify_writes,
    config_writes,
)

MESSAGE = b"Jane St!"
# SCK = clock / 8, the fastest the host port takes
HALF = 4
BIT = 16


class AsyncHost(Host):
    def __init__(self, dut):
        self.dut = dut

    async def drive(self, sck, mosi, cs_n, cycles):
        self.dut.ui_in.value = (cs_n << 2) | (mosi << 1) | sck
        await ClockCycles(self.dut.clk, cycles)

    async def transfer(self, data):
        replies = []
        await self.drive(0, 0, 0, HALF)
        for byte in data:
            reply = 0
            for b in range(7, -1, -1):
                await self.drive(0, (byte >> b) & 1, 0, HALF)
                reply = (reply << 1) | (str(self.dut.uo_out.value)[-1] == "1")
                await self.drive(1, (byte >> b) & 1, 0, HALF)
            replies.append(reply)
        await self.drive(0, 0, 0, HALF)
        await self.drive(0, 0, 1, 3)
        return replies

    async def write(self, reg, words):
        data = [0x80 | reg]
        for w in words:
            data += [(w >> 8) & 0xFF, w & 0xFF]
        await self.transfer(data)

    async def read(self, reg, count=1):
        reply = (await self.transfer([reg] + [0] * (2 * count)))[1:]
        return [(reply[i] << 8) | reply[i + 1] for i in range(0, 2 * count, 2)]


def frames(levels):
    """Returns [first cycle, last cycle, byte] for each 8N1 frame on a line at BIT cycles
    per bit, reported once its stop bit ends."""
    found, i = [], 1
    while i + 10 * BIT <= len(levels):
        if levels[i - 1] and not levels[i]:
            byte = sum(levels[i + (b + 1) * BIT + BIT // 2] << b for b in range(8))
            found.append([i, i + 10 * BIT - 1, byte])
            i += 10 * BIT
        else:
            i += 1
    return found


async def record(dut, pins):
    while True:
        await FallingEdge(dut.clk)
        pins.append([str(dut.uo_out.value), str(dut.uio_out.value), str(dut.uio_oe.value)])


@cocotb.test()
async def live_die(dut):
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())
    pins = []
    cocotb.start_soon(record(dut, pins))
    dut.ena.value = 1
    dut.ui_in.value = 0b100
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)

    host = AsyncHost(dut)
    # the fields reset to zero, so only write the nonzero ones
    for reg, word in config_writes(DEFAULT_CONFIG):
        if word:
            await host.write(reg, [word])
    await host.write(PROGRAM_ADDR, [0])
    program = os.environ["LIVE_DIE_PROGRAM"]
    with open(program) as f:
        words = [int(line, 16) for line in f]
    # the check reads every word, so zero the rest as Host.load does
    await host.write(PROGRAM, words + [0] * (PROGRAM_WORDS - len(words)))
    # the chip won't start a program it hasn't checked
    with open(program.replace(".hex", ".cert.hex")) as f:
        for reg, words in certify_writes([int(line, 16) for line in f]):
            await host.write(reg, words)
    check = (await host.read(CHECK_STATUS))[0]
    while check & 1:
        check = (await host.read(CHECK_STATUS))[0]
    if not check & 4:
        pc, reason = (await host.read(REJECT_PC))[0], (await host.read(REJECT_REASON))[0]
        raise AssertionError("the chip refused uart_tx at pc %d, reason %d" % (pc, reason))
    await host.write(CONTROL, [1])
    await host.write(TX, list(MESSAGE))

    while len(frames([int(uo[-2] == "1") for uo, _, _ in pins])) < len(MESSAGE):
        await ClockCycles(dut.clk, BIT)
    status = (await host.read(STATUS))[0]
    await ClockCycles(dut.clk, BIT * 2)
    with open(os.environ["LIVE_DIE_PINS"], "w") as f:
        json.dump({"pins": pins, "status": status}, f)
