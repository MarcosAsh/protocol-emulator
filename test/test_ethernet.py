# SPDX-License-Identifier: Apache-2.0
# A UDP datagram from python/ethernet.py through the data memory, read back off TD+ and
# TD- (IO0, IO1) at four cycles a bit, with the FCS the chip's CRC unit appends checked
# against the host's.

import cocotb
from cocotb.triggers import ClockCycles

from test import AsyncHost, Pins, assembled, reset
from protocol_emulator import PROGRAM, PROGRAM_ADDR, STATUS, config_writes
import ethernet


@cocotb.test()
async def test_udp_datagram(dut):
    await reset(dut)
    host = AsyncHost(Pins(dut).transfer)
    for reg, word in config_writes(ethernet.CONFIG):
        await host.write(reg, [word])
    await host.write(PROGRAM_ADDR, [0])
    await host.write(PROGRAM, assembled("ethernet"))
    frame = ethernet.udp(b"hello from the chip")
    data = ethernet.wire(frame)
    # what ethernet.send does, with a short link interval so the frame starts soon
    for reg, values in ethernet.writes(frame, link_tenth=50):
        await host.write(reg, values)

    # +1 while TD+ is high, -1 while TD- is, from the first cycle the line leaves idle
    levels = []
    for _ in range(100 + 32 * len(data) + 100):
        await ClockCycles(dut.clk, 1)
        out = int(dut.uio_out.value) & int(dut.uio_oe.value)
        level = {1: 1, 2: -1}.get(out & 3, 0)
        if level:
            levels.append(level)
        elif levels:
            break

    # each bit is its complement for two cycles and itself for two
    bits = []
    for k in range(0, len(levels) - 3, 4):
        a, a2, b, b2 = levels[k:k + 4]
        if a != a2 or b != b2 or a != -b:
            break
        bits.append(int(b > 0))
    received = [sum(bits[8 * i + j] << j for j in range(8)) for i in range(len(bits) // 8)]
    assert received == data
    tail = levels[4 * len(bits):]
    assert all(level > 0 for level in tail) and 10 <= len(tail) <= 14, "TP_IDL"
    assert (await host.read(STATUS))[0] & 0x3D == 0, "running, no fault"
