# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

WEN = 1 << 7
BANK = 1 << 6
HIGH = 1 << 5


async def write(dut, addr, value):
    dut.ui_in.value = BANK
    dut.uio_in.value = addr >> 5
    await ClockCycles(dut.clk, 1)
    dut.ui_in.value = WEN | (addr & 0x1F)
    dut.uio_in.value = value & 0xFF
    await ClockCycles(dut.clk, 1)
    dut.ui_in.value = WEN | HIGH | (addr & 0x1F)
    dut.uio_in.value = value >> 8
    await ClockCycles(dut.clk, 1)


async def read(dut, addr):
    dut.ui_in.value = BANK
    dut.uio_in.value = addr >> 5
    await ClockCycles(dut.clk, 1)
    dut.ui_in.value = addr & 0x1F
    dut.uio_in.value = 0
    await ClockCycles(dut.clk, 2)
    low = int(dut.uo_out.value)
    dut.ui_in.value = HIGH | (addr & 0x1F)
    await ClockCycles(dut.clk, 2)
    return (int(dut.uo_out.value) << 8) | low


@cocotb.test()
async def test_sram(dut):
    clock = Clock(dut.clk, 20, unit="ns")
    cocotb.start_soon(clock.start())
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)
    assert int(dut.uio_oe.value) == 0

    words = {0: 0x1234, 1: 0xABCD, 31: 0x00FF, 32: 0xFF00, 255: 0x5A5A, 511: 0xBEEF}
    for addr, value in words.items():
        await write(dut, addr, value)
    for addr, value in words.items():
        assert await read(dut, addr) == value, f"address {addr}"

    # A byte write must leave the other byte alone.
    dut.ui_in.value = BANK
    dut.uio_in.value = 0
    await ClockCycles(dut.clk, 1)
    dut.ui_in.value = WEN | 1
    dut.uio_in.value = 0x11
    await ClockCycles(dut.clk, 1)
    assert await read(dut, 1) == 0xAB11
