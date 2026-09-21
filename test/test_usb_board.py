# SPDX-License-Identifier: Apache-2.0
"""A control transfer through the chip: a USB host on D+ and D-, the board's Python on SPI."""

import cocotb
from cocotb.triggers import ClockCycles

import sys

sys.path.insert(0, "../python")
from protocol_emulator import CONFIG, CONFIG_FIELDS, CONTROL, PROGRAM_ADDR, PROGRAM as PROGRAM_REG, RX, STATUS, TX
import usb_board
import usb_device_firmware as firmware
from test import AsyncHost, Pins, reset

BIT = firmware.BIT_PERIOD
J, K, SE0 = (0, 1), (1, 0), (0, 0)
DEVICE = [18, 1, 0x10, 1, 0, 0, 0, 8, 0x09, 0x12, 1, 0, 0, 1, 0, 0, 0, 1]


def bits_of(data):
    return [(byte >> i) & 1 for byte in data for i in range(8)]


def crc(bits, width, poly):
    reg = (1 << width) - 1
    for bit in bits:
        reg = (reg >> 1) ^ (poly if (reg ^ bit) & 1 else 0)
    return reg ^ ((1 << width) - 1)


def token(pid, address, endpoint):
    field = [(address >> i) & 1 for i in range(7)] + [(endpoint >> i) & 1 for i in range(4)]
    return [pid, address | ((endpoint & 1) << 7), (endpoint >> 1) | (crc(field, 5, 0x14) << 3)]


def data_packet(pid, payload):
    c = crc(bits_of(payload), 16, 0xA001)
    return [pid] + payload + [c & 0xFF, c >> 8]


def encode(packet):
    """Line states a bit at a time: SYNC, NRZI with stuffing, EOP."""
    lines, state, ones = [], J, 0
    for bit in bits_of([0x80] + packet):
        if not bit:
            state = K if state == J else J
        ones = ones + 1 if bit else 0
        lines.append(state)
        if ones == 6:
            state = K if state == J else J
            lines.append(state)
            ones = 0
    return lines + [SE0, SE0, J]


class Wire:
    """D+ is uio[0] and D- is uio[1]; the device wins where it drives."""

    def __init__(self, dut):
        self.dut = dut

    async def drive(self, state, bits=1):
        self.dut.uio_in.value = state[0] | (state[1] << 1)
        await ClockCycles(self.dut.clk, bits * BIT)

    async def send(self, packet):
        for state in encode(packet):
            await self.drive(state)

    def line(self):
        oe, out = str(self.dut.uio_oe.value), str(self.dut.uio_out.value)
        if oe[-2:] != "11":
            return None
        return (int(out[-1]), int(out[-2]))

    async def listen(self, timeout=200):
        """The device's next packet, bytes after SYNC, or None."""
        self.dut.uio_in.value = 2
        for _ in range(timeout * BIT):
            await ClockCycles(self.dut.clk, 1)
            if self.line() == K:
                break
        else:
            return None
        await ClockCycles(self.dut.clk, BIT // 2)
        bits, previous, ones = [], J, 0
        while True:
            state = self.line()
            if state == SE0 or state is None:
                break
            bit = 1 if state == previous else 0
            previous = state
            if ones == 6:
                ones = 0
            else:
                bits.append(bit)
                ones = ones + 1 if bit else 0
            await ClockCycles(self.dut.clk, BIT)
        await ClockCycles(self.dut.clk, 4 * BIT)
        return [sum(b << i for i, b in enumerate(bits[n:n + 8])) for n in range(8, len(bits) - 7, 8)]


async def load(host, address):
    await host.write(CONTROL, [4])
    for n, name in enumerate(CONFIG_FIELDS):
        await host.write(CONFIG + n, [firmware.CONFIG[name]])
    await host.write(PROGRAM_ADDR, [0])
    await host.write(PROGRAM_REG, firmware.words(address))
    await host.write(TX, [firmware.BIT_PERIOD])
    await host.write(CONTROL, [1])


async def serve(dut, host, board, faults, loads):
    """usb_board.service, with awaits, and as unhurried as MicroPython is."""
    while True:
        await ClockCycles(dut.clk, 5000)
        status = (await host.read(STATUS))[0]
        faults.append((status >> 2) & 0xF)
        level = (status >> 10) & 15
        if level:
            for word in await host.read(RX, level):
                board.feed(word)
        if board.reload is not None:
            address, board.reload = board.reload, None
            await load(host, address)
            loads.append(address)
        elif board.replies and ((status >> 6) & 15) + len(board.replies[0]) <= 8:
            await host.write(TX, board.replies.pop(0))


@cocotb.test()
async def test_get_descriptor(dut):
    await reset(dut)
    dut.uio_in.value = 2
    board = usb_board.Board({1: DEVICE})
    faults, loads = [], []
    server = cocotb.start_soon(serve(dut, AsyncHost(Pins(dut).transfer), board, faults, loads))
    wire = Wire(dut)
    while not loads:
        await ClockCycles(dut.clk, 1000)
    await wire.drive(J, 40)

    await wire.send(token(0x2D, 0, 0))
    await wire.drive(J, 3)
    await wire.send(data_packet(0xC3, [0x80, 6, 0, 1, 0, 0, 8, 0]))
    assert await wire.listen() == [0xD2]

    naks = 0
    while True:
        await wire.send(token(0x69, 0, 0))
        packet = await wire.listen()
        if packet != [0x5A]:
            break
        naks += 1
        assert naks < 40
        await wire.drive(J, 200)
    assert packet == data_packet(0x4B, DEVICE[:8]), packet
    await wire.send([0xD2])
    await wire.drive(J, 4)

    await wire.send(token(0xE1, 0, 0))
    await wire.drive(J, 3)
    await wire.send(data_packet(0x4B, []))
    assert await wire.listen() == [0xD2]

    await wire.drive(J, 400)
    server.cancel()
    dut._log.info(f"the core sent {naks} NAKs while the board caught up over SPI")
    assert naks > 0
    assert not any(faults), faults
