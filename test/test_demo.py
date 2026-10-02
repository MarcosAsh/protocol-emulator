# SPDX-License-Identifier: Apache-2.0
"""The bench demos' own Python, run blocking in a thread with each SPI frame a cocotb
transfer, as the host Pico runs it."""

import cocotb
from cocotb.task import bridge, resume
from cocotb.triggers import ClockCycles
from cocotb.utils import get_sim_time

from test import AsyncHost, Pins, reset
from test_usb_board import J, SE0, Wire, data_packet, token
from protocol_emulator import CONTROL, SELECT, STATUS, Host
import demo_self_timing
import demo_sweep
import demo_usb
import sweep_firmware
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


@cocotb.test()
async def test_sweep(dut):
    """Act 2 for every swept firmware, each poll taking as long as the table lets the Pico
    take; every edge has to land where the kernel's rows along the model's path put it."""
    await reset(dut)
    pins = Pins(dut)

    @resume
    async def transfer(data):
        return await pins.transfer(data)

    @resume
    async def pause():
        await ClockCycles(dut.clk, sweep_firmware.POLL)

    assert await bridge(demo_sweep.run)(transfer, pause=pause)


class Done(Exception):
    """Ends `serve`, which runs forever on the Pico."""


def uart_frames(edges, period):
    """(start, byte) for each frame in a line's (cycle, level) edges, the first of which is
    it going idle. Every edge must be a whole number of periods after its start bit."""
    assert edges[0][1] == 1, "idle high"
    frames, rest = [], edges[1:]
    while rest:
        start = rest[0][0]
        frame = [(at - start, level) for at, level in rest if at < start + 10 * period]
        assert all(offset % period == 0 for offset, _ in frame), frame
        levels = {offset // period: level for offset, level in frame}
        bits = [0]
        for bit in range(1, 10):
            bits.append(levels.get(bit, bits[-1]))
        assert bits[9] == 1, "stop bit"
        frames.append((start, sum(b << n for n, b in enumerate(bits[1:9]))))
        rest = rest[len(frame):]
    return frames


@cocotb.test()
async def test_keyboard(dut):
    """Act 3 as the Pico runs it: demo_usb.serve against a host that resets the bus, reads
    the device descriptor, sets address 3, configures it and polls the keyboard, while
    engine 1 sends each key the host took out of OUT0, every edge on its certified cycle."""
    await reset(dut)
    dut.uio_in.value = 2
    pins = Pins(dut)
    wire = Wire(dut)
    board = usb_board.Board(demo_usb.DESCRIPTORS)
    # engine 0's starts, as engine 1's start comes first
    starts, selected, done = [], [0], False

    @resume
    async def transfer(data):
        if done:
            raise Done
        replies = await pins.transfer(data)
        if data[:2] == [0x80 | SELECT, 0]:
            selected.append(data[2])
        if data == [0x80 | CONTROL, 0, 1] and selected[-1] == 0:
            starts.append(get_sim_time("ns") // 20)
        return replies

    @resume
    async def lines():
        return int(dut.uio_in.value) & 3

    # a millisecond is a thousand cycles here, so the reset is short enough to simulate
    @resume
    async def ms():
        return get_sim_time("ns") // 20_000

    # OUT0 from each cycle it changes
    out0 = [(0, 0)]

    async def watch():
        while True:
            await dut.uo_out.value_change
            level = 1 if str(dut.uo_out.value)[-2] == "1" else 0
            if level != out0[-1][1]:
                out0.append((int(get_sim_time("ns")) // 20, level))

    watcher = cocotb.start_soon(watch())

    def serve():
        host = Host(transfer)
        # the testbench's 50 MHz, so 434 cycles a bit
        log = demo_usb.start_log(host, demo_usb.words("uart_tx_host_rate"), 50_000_000)
        try:
            demo_usb.serve(host, board, demo_usb.reports("hi"), demo_usb.se0_reset(lines, ms), log)
        except Done:
            pass

    server = cocotb.start_soon(bridge(serve)())

    async def until(condition, cycles=200_000):
        for _ in range(cycles // 100):
            if condition():
                return
            await ClockCycles(dut.clk, 100)
        raise AssertionError("timed out")

    async def setup(address, request):
        await wire.send(token(0x2D, address, 0))
        await wire.drive(J, 3)
        await wire.send(data_packet(0xC3, request))
        assert await wire.listen() == [0xD2]

    # the cycle each IN's ACK starts
    acked = []

    async def poll_in(address, endpoint):
        """An IN's data packet, asked again after each NAK, and acknowledged."""
        for _ in range(100):
            await wire.send(token(0x69, address, endpoint))
            packet = await wire.listen()
            if packet != [0x5A]:
                break
            await wire.drive(J, 200)
        acked.append(int(get_sim_time("ns")) // 20)
        await wire.send([0xD2])
        await wire.drive(J, 4)
        return packet

    async def status_out():
        await wire.send(token(0xE1, 0, 0))
        await wire.drive(J, 3)
        await wire.send(data_packet(0x4B, []))
        assert await wire.listen() == [0xD2]

    await until(lambda: starts)
    await wire.drive(SE0, 150)
    # idle, which the reset rereads until the reload is done
    dut.uio_in.value = 2
    await until(lambda: len(starts) == 2)
    await wire.drive(J, 40)

    await setup(0, [0x80, 6, 0, 1, 0, 0, 8, 0])
    assert await poll_in(0, 0) == data_packet(0x4B, demo_usb.DEVICE[:8])
    await status_out()

    await setup(0, [0x00, 5, 3, 0, 0, 0, 0, 0])
    assert await poll_in(0, 0) == data_packet(0x4B, [])
    await until(lambda: len(starts) == 3)

    # SET_CONFIGURATION with h's report in the fifo. The status packet queues behind it,
    # the status IN drops the report, and the ACK after that is the status packet's.
    await until(lambda: board.pending_report is not None and not board.replies)
    await setup(3, [0x00, 9, 1, 0, 0, 0, 0, 0])
    await wire.drive(J, 100)
    assert await poll_in(3, 0) == data_packet(0x4B, [])

    h, i = demo_usb.KEYS["h"], demo_usb.KEYS["i"]
    # the fifth, i's release, is queued only once i is logged
    received = [await poll_in(3, 1) for _ in range(5)]
    taken = acked[-5:]
    done = True
    await wire.drive(J, 400)
    await server
    watcher.cancel()
    assert received == [
        data_packet(0xC3, [1, 0, h, 0, 0, 0, 0, 0]),
        data_packet(0x4B, [1, 0, 0, 0, 0, 0, 0, 0]),
        data_packet(0xC3, [2, 0, 3, 0]),
        data_packet(0x4B, [1, 0, i, 0, 0, 0, 0, 0]),
        data_packet(0xC3, [1, 0, 0, 0, 0, 0, 0, 0]),
    ], received
    assert board.address == 3

    frames = uart_frames(out0[1:], 434)
    dut._log.info(f"OUT0 frames at {[start for start, _ in frames]}, report ACKs at {taken}")
    assert bytes(byte for _, byte in frames) == b"hi", frames
    # each key goes out once the host acknowledges its report, before the next report
    assert taken[0] < frames[0][0] < taken[1], "h out of step with its report"
    assert taken[3] < frames[1][0] < taken[4], "i out of step with its report"
    host = AsyncHost(pins.transfer)
    for engine in (0, 1):
        await host.write(SELECT, [engine])
        assert (await host.read(STATUS))[0] & 0x3C == 0, f"engine {engine} faulted"
