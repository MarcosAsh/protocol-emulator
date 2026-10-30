# SPDX-License-Identifier: Apache-2.0
"""A full speed host enumerating the chip as a USB device: D+ and D- at four cycles a bit,
the board's Python (demo_usb_fs, usb_fs_board) on SPI as the Pico runs it."""

import sys

import cocotb
from cocotb.task import bridge, resume
from cocotb.triggers import ClockCycles, RisingEdge

sys.path.insert(0, "../python")
import demo_usb_fs
import usb_fs_board
from protocol_emulator import STATUS, Host

from test import Pins, reset

BIT = 4
J, K, SE0 = (1, 0), (0, 1), (0, 0)
IN, OUT, SETUP = 0x69, 0xE1, 0x2D
DATA0, DATA1, ACK, NAK, STALL = 0xC3, 0x4B, 0xD2, 0x5A, 0x1E
# a reset is SE0 for 10 ms; here a "millisecond" is 500 cycles
CYCLES_MS = 500


class Done(Exception):
    """Ends `serve`, which runs until told."""


def crc5(address, endpoint):
    bits = [(address >> i) & 1 for i in range(7)] + [(endpoint >> i) & 1 for i in range(4)]
    reg = 0x1F
    for bit in bits:
        reg = (reg >> 1) ^ (0x14 if (reg ^ bit) & 1 else 0)
    return reg ^ 0x1F


def token(pid, address, endpoint):
    return [pid, address | ((endpoint & 1) << 7), (endpoint >> 1) | (crc5(address, endpoint) << 3)]


def encode(packet):
    """Line states a bit at a time: SYNC, NRZI with stuffing, EOP."""
    lines, state = [], J
    for bit in usb_fs_board.line_bits(packet):
        if not bit:
            state = K if state == J else J
        lines.append(state)
    return lines + [SE0, SE0, J]


def decode(lines):
    """The bytes after SYNC of the packet whose line states, a bit each, start at its SOP
    and end at its EOP's SE0, or None where it breaks the rules."""
    bits, previous, ones = [], J, 0
    for state in lines:
        bit = 1 if state == previous else 0
        previous = state
        if ones == 6:
            if bit:
                return None
            ones = 0
            continue
        bits.append(bit)
        ones = ones + 1 if bit else 0
    if bits[:8] != [0] * 7 + [1] or len(bits) % 8:
        return None
    return [sum(b << i for i, b in enumerate(bits[n:n + 8])) for n in range(8, len(bits), 8)]


class Bus:
    """D+ is uio[0] and D- uio[1]: the device's levels where it drives both, else the
    host's, else J from the pull-up. Every cycle's line is kept."""

    def __init__(self, dut):
        self.dut = dut
        self.host = None
        self.lines = []
        self.turnarounds = []

    async def run(self):
        while True:
            await RisingEdge(self.dut.clk)
            oe = int(self.dut.uio_oe.value) & 3
            if oe == 3:
                out = int(self.dut.uio_out.value)
                line = (out & 1, (out >> 1) & 1)
            else:
                line = self.host or J
            self.dut.uio_in.value = line[0] | (line[1] << 1)
            self.lines.append(line)

    def driving(self):
        return int(self.dut.uio_oe.value) & 3 == 3

    async def send(self, packet):
        for state in encode(packet):
            self.host = state
            await ClockCycles(self.dut.clk, BIT)
        self.host = None

    async def idle(self, bits):
        await ClockCycles(self.dut.clk, bits * BIT)

    async def listen(self):
        """The device's packet, if it starts within 16 bit times of the host's EOP; its
        turnaround, from the EOP's J to its SOP, goes in turnarounds."""
        # the EOP's J started a bit ago
        j = len(self.lines) - BIT
        for _ in range(16 * BIT):
            if self.driving() and self.lines[-1] == K:
                break
            await ClockCycles(self.dut.clk, 1)
        else:
            return None
        sop = len(self.lines) - 1
        while self.lines[-1] != SE0:
            await ClockCycles(self.dut.clk, 1)
        end = len(self.lines) - 1
        await ClockCycles(self.dut.clk, 4 * BIT)
        self.turnarounds.append((sop - j) / BIT)
        return decode(self.lines[sop + BIT // 2:end:BIT])

    async def transaction(self, *packets, gap=3):
        for n, packet in enumerate(packets):
            if n:
                await self.idle(gap)
            await self.send(packet)
        return await self.listen()

    async def bus_reset(self, ms=12):
        self.host = SE0
        await ClockCycles(self.dut.clk, ms * CYCLES_MS)
        self.host = None
        await self.idle(100)


async def control(bus, address, setup, out_data=False):
    """A control transfer, retrying each NAKed IN as a host does; the data read, or the
    PID the device ended it with."""
    reply = await bus.transaction(token(SETUP, address, 0), usb_fs_board.data_packet(DATA0, setup))
    assert reply == [ACK], f"SETUP {setup}: {reply}"
    length = setup[6] | (setup[7] << 8)
    data, toggle = [], DATA1
    while True:
        for _ in range(400):
            reply = await bus.transaction(token(IN, address, 0))
            if reply != [NAK]:
                break
            await bus.idle(20)
        else:
            raise AssertionError(f"{setup}: NAKed throughout")
        if reply == [STALL]:
            return STALL
        assert reply is not None and reply[0] == toggle, f"{setup}: {reply}"
        assert check_crc(reply), reply
        await bus.idle(3)
        await bus.send([ACK])
        await bus.idle(10)
        payload = reply[1:-2]
        data += payload
        toggle = DATA0 if toggle == DATA1 else DATA1
        if setup[0] & 0x80 == 0 or len(payload) < 8 or len(data) >= length:
            break
    if setup[0] & 0x80:
        reply = await bus.transaction(token(OUT, address, 0), usb_fs_board.data_packet(DATA1, []))
        assert reply == [ACK], f"status OUT: {reply}"
        await bus.idle(10)
    return data


def check_crc(packet):
    payload, crc = packet[1:-2], packet[-2] | (packet[-1] << 8)
    return usb_fs_board.crc16(payload) == crc


def get_descriptor(kind, index, length, request_type=0x80, language=0):
    return [request_type, 6, index, kind, language & 0xFF, language >> 8, length & 0xFF, length >> 8]


@cocotb.test()
async def test_enumeration(dut):
    """Enumerated as Linux does a full speed HID device, each answer the descriptor it
    asks for, an unknown descriptor stalled, and every reply inside 2 to 6.5 bit times."""
    await reset(dut)
    bus = Bus(dut)
    cocotb.start_soon(bus.run())
    pins = Pins(dut)
    stop, said, served = [False], [], [False]

    @resume
    async def transfer(data):
        return await pins.transfer(data)

    @resume
    async def lines():
        return int(dut.uio_in.value) & 3

    @resume
    async def ms():
        return len(bus.lines) // CYCLES_MS

    def serve():
        host = Host(transfer)
        board = usb_fs_board.Board(demo_usb_fs.DESCRIPTORS)
        usb_fs_board.load(host, board)
        served[0] = True
        demo_usb_fs.serve(host, board, demo_usb_fs.se0_reset(lines, ms), said.append,
                          lambda: stop[0])

    server = cocotb.start_soon(bridge(serve)())
    while not served[0]:
        await ClockCycles(dut.clk, 1000)

    await bus.bus_reset()
    device = await control(bus, 0, get_descriptor(1, 0, 64))
    assert device == demo_usb_fs.DEVICE, device
    await bus.bus_reset()
    assert await control(bus, 0, [0, 5, 5, 0, 0, 0, 0, 0]) == []
    await bus.idle(200)
    assert await control(bus, 5, get_descriptor(1, 0, 18)) == demo_usb_fs.DEVICE
    assert await control(bus, 5, get_descriptor(2, 0, 9)) == demo_usb_fs.CONFIGURATION[:9]
    assert await control(bus, 5, get_descriptor(2, 0, 255)) == demo_usb_fs.CONFIGURATION
    assert await control(bus, 5, get_descriptor(6, 0, 10)) == STALL
    assert await control(bus, 5, get_descriptor(3, 0, 255)) == [4, 3, 0x09, 0x04]
    product = await control(bus, 5, get_descriptor(3, 1, 255, language=0x0409))
    assert product == demo_usb_fs.string(demo_usb_fs.PRODUCT), product
    assert await control(bus, 5, [0, 9, 1, 0, 0, 0, 0, 0]) == []
    assert await control(bus, 5, [0x21, 0x0A, 0, 0, 0, 0, 0, 0]) == []
    report = await control(bus, 5, get_descriptor(0x22, 0, len(demo_usb_fs.REPORT), 0x81))
    assert report == demo_usb_fs.REPORT, report
    assert await bus.transaction(token(IN, 5, 1)) == [NAK]
    # the device answers no other address
    assert await bus.transaction(token(IN, 0, 0)) is None

    stop[0] = True
    await server
    status = (await AsyncHostRead(pins).status())
    dut._log.info(f"board said {said}")
    dut._log.info(f"turnarounds {min(bus.turnarounds)} to {max(bus.turnarounds)} bit times")
    assert 2 <= min(bus.turnarounds) and max(bus.turnarounds) <= 6.5, bus.turnarounds
    assert status & 0x403D == 0, f"engine 0 halted or faulted: {status:#06x}"


class AsyncHostRead:
    def __init__(self, pins):
        self.pins = pins

    async def status(self):
        reply = await self.pins.transfer([STATUS, 0, 0])
        return (reply[1] << 8) | reply[2]
