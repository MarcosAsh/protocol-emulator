# SPDX-License-Identifier: Apache-2.0
"""The bench demos' own Python, run blocking in a thread with each SPI frame a cocotb
transfer, as the host Pico runs it."""

import cocotb
from cocotb.task import bridge, resume
from cocotb.triggers import ClockCycles
from cocotb.utils import get_sim_time

from test import Pins, reset
from test_usb_board import J, SE0, Wire, data_packet, token
from protocol_emulator import CONTROL, Host
import demo_self_timing
import demo_usb
import usb_board

# cycles in a microsecond at 48 MHz, for the Pico's pauses
US = 48


@cocotb.test()
async def test_self_timing(dut):
    await reset(dut)
    pins = Pins(dut)

    @resume
    async def transfer(data):
        return await pins.transfer(data)

    @resume
    async def pause():
        await ClockCycles(dut.clk, 300 * US)

    # OUT0's level from each cycle on
    out0 = [(0, 0)]

    async def watch():
        while True:
            await dut.uo_out.value_change
            level = 1 if str(dut.uo_out.value)[-2] == "1" else 0
            if level != out0[-1][1]:
                out0.append((get_sim_time("ns") // 20, level))

    def level_at(cycle):
        return [level for at, level in out0 if at <= cycle][-1]

    watcher = cocotb.start_soon(watch())
    text = b"Hi!"
    ok = await bridge(demo_self_timing.run)(transfer, text=text, pause=pause)
    watcher.cancel()
    assert ok
    # OUT0 echoes the wire, so it carries the text twice at 9600 baud
    period = demo_self_timing.PERIOD
    falls = [at for at, level in out0 if level == 0][1:]
    received, next_start = [], 0
    for fall in falls:
        if fall < next_start:
            continue
        middle = fall + period // 2
        bits = [level_at(middle + (i + 1) * period) for i in range(8)]
        assert level_at(middle + 9 * period) == 1, "stop bit"
        received.append(sum(b << i for i, b in enumerate(bits)))
        next_start = middle + 9 * period
    assert bytes(received) == text * 2, received


class Done(Exception):
    """Ends `serve`, which runs forever on the Pico."""


@cocotb.test()
async def test_keyboard(dut):
    """demo_usb.serve as the Pico runs it, against a host that resets the bus, sets
    address 3 and polls the keyboard's endpoint."""
    await reset(dut)
    dut.uio_in.value = 2
    pins = Pins(dut)
    wire = Wire(dut)
    board = usb_board.Board(demo_usb.DESCRIPTORS)
    starts, done = [], False

    @resume
    async def transfer(data):
        if done:
            raise Done
        replies = await pins.transfer(data)
        if data == [0x80 | CONTROL, 0, 1]:
            starts.append(get_sim_time("ns") // 20)
        return replies

    @resume
    async def lines():
        return int(dut.uio_in.value) & 3

    # a millisecond is a thousand cycles here, so the reset is short enough to simulate
    @resume
    async def ms():
        return get_sim_time("ns") // 20_000

    def serve():
        try:
            demo_usb.serve(Host(transfer), board, demo_usb.reports("hi"), demo_usb.se0_reset(lines, ms))
        except Done:
            pass

    server = cocotb.start_soon(bridge(serve)())

    async def until(condition, cycles=200_000):
        for _ in range(cycles // 100):
            if condition():
                return
            await ClockCycles(dut.clk, 100)
        raise AssertionError("timed out")

    async def poll_in(address, endpoint):
        """An IN's data packet, asked again after each NAK, and acknowledged."""
        for _ in range(100):
            await wire.send(token(0x69, address, endpoint))
            packet = await wire.listen()
            if packet != [0x5A]:
                break
            await wire.drive(J, 200)
        await wire.send([0xD2])
        await wire.drive(J, 4)
        return packet

    await until(lambda: starts)
    await wire.drive(SE0, 150)
    # idle, which the reset rereads until the reload is done
    dut.uio_in.value = 2
    await until(lambda: len(starts) == 2)
    await wire.drive(J, 40)

    await wire.send(token(0x2D, 0, 0))
    await wire.drive(J, 3)
    await wire.send(data_packet(0xC3, [0x00, 5, 3, 0, 0, 0, 0, 0]))
    assert await wire.listen() == [0xD2]
    assert await poll_in(0, 0) == data_packet(0x4B, [])
    await until(lambda: len(starts) == 3)

    h, i = demo_usb.KEYS["h"], demo_usb.KEYS["i"]
    received = [await poll_in(3, 1) for _ in range(4)]
    done = True
    await wire.drive(J, 400)
    await server
    assert received == [
        data_packet(0xC3, [1, 0, h, 0, 0, 0, 0, 0]),
        data_packet(0x4B, [1, 0, 0, 0, 0, 0, 0, 0]),
        data_packet(0xC3, [2, 0, 3, 0]),
        data_packet(0x4B, [1, 0, i, 0, 0, 0, 0, 0]),
    ], received
    assert board.address == 3
