# SPDX-License-Identifier: Apache-2.0
"""demo_thermometer.py on the RTL at the bench's 48 MHz, run blocking in a thread as Pico A
runs it: engine 1 on the 1-Wire master against test_outside's DS18B20, engine 0 on the USB
keyboard against a laptop on D+ and D-. The laptop's polls are decoded back to text. A
Pico millisecond is a thousand cycles here, so the pauses are shortened to simulate."""

import cocotb
from cocotb.task import bridge, resume
from cocotb.triggers import ClockCycles
from cocotb.utils import get_sim_time

# test_outside puts ../python on the path, through test
from test_outside import CLOCK_PS, Ds18b20, reset, with_crc
from test import AsyncHost, Pins
from test_usb_board import J, SE0, Wire, data_packet, token
from protocol_emulator import CONTROL, SELECT, STATUS, Host
import demo_thermometer
import demo_usb
import usb_board

FAULTS = 0x3C
ADDRESS = 3
NAK = [0x5A]
PERIOD_MS = 300
CONVERT_MS = 100
# +21.375 and then +22.375 C, in 1/16 C
FIRST, SECOND = 0x0156, 0x0166
CHARS = {code: c for c, code in demo_thermometer.KEYS.items()}


class Line:
    def __init__(self, dut):
        self.dut = dut

    @property
    def value(self):
        return self.dut.usb_in.value

    @value.setter
    def value(self, v):
        self.dut.usb_in.value = v & 3


class UsbPort:
    """What test_usb_board.Wire takes for the dut: D+ and D- are the testbench's usb_in."""

    def __init__(self, dut):
        self.clk, self.uio_oe, self.uio_out = dut.clk, dut.uio_oe, dut.uio_out
        self.uio_in = Line(dut)


def scratchpad(raw):
    return with_crc([raw & 0xFF, raw >> 8, 0x4B, 0x46, 0x7F, 0xFF, 0x0C, 0x10])


def typed(report):
    """The character a keyboard report presses, None for a release."""
    return CHARS[report[2]] if report[2] else None


@cocotb.test()
async def test_thermometer_types(dut):
    """Two readings, a degree apart, typed as "21.4 C" and "22.4 C" and a return each, with
    both engines running and neither faulted throughout."""
    await reset(dut)
    dut.usb_in.value = 2
    rom = with_crc([0x28, 0xD1, 0xC3, 0x5A, 0x0B, 0x00, 0x00])
    sensor = Ds18b20(dut, rom, scratchpad(FIRST))
    pins = Pins(dut)
    wire = Wire(UsbPort(dut))
    board = usb_board.Board(demo_usb.DESCRIPTORS)
    queue, said = [], []
    # engine 0's starts, as engine 1's start comes first
    starts, selected, done = [], [0], [False]

    class Done(Exception):
        """Ends `serve`, which runs forever on the Pico."""

    @resume
    async def transfer(data):
        if done[0]:
            raise Done
        replies = await pins.transfer(data)
        if data[:2] == [0x80 | SELECT, 0]:
            selected.append(data[2])
        if data == [0x80 | CONTROL, 0, 1] and selected[-1] == 0:
            starts.append(get_sim_time("ps") // CLOCK_PS)
        return replies

    @resume
    async def lines():
        return int(dut.usb_in.value) & 3

    @resume
    async def ms():
        return get_sim_time("ps") // (CLOCK_PS * 1000)

    def say(line):
        cocotb.log.info(line)
        said.append(line)

    def serve():
        host = Host(transfer)
        thermometer = demo_thermometer.Thermometer(
            host, board, queue, ms, say, PERIOD_MS, CONVERT_MS)
        thermometer.start()
        try:
            demo_usb.serve(host, board, queue, demo_usb.se0_reset(lines, ms), tick=thermometer.step)
        except Done:
            pass

    server = cocotb.start_soon(bridge(serve)())

    async def until(condition, cycles=400_000):
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

    async def poll_in(address, endpoint, tries=100):
        """An IN's data packet, asked again after each NAK, and acknowledged."""
        for _ in range(tries):
            await wire.send(token(0x69, address, endpoint))
            packet = await wire.listen()
            if packet != NAK:
                break
            await wire.drive(J, 200)
        else:
            return None
        await wire.send([0xD2])
        await wire.drive(J, 4)
        return packet

    async def status_out(address=0):
        await wire.send(token(0xE1, address, 0))
        await wire.drive(J, 3)
        await wire.send(data_packet(0x4B, []))
        assert await wire.listen() == [0xD2]

    # the laptop's enumeration as test_demo's act 3, once engine 0 is serving
    await until(lambda: starts)
    await wire.drive(SE0, 150)
    dut.usb_in.value = 2
    await until(lambda: len(starts) == 2)
    await wire.drive(J, 40)
    await setup(0, [0x80, 6, 0, 1, 0, 0, 8, 0])
    assert await poll_in(0, 0) == data_packet(0x4B, demo_usb.DEVICE[:8])
    await status_out()
    await setup(0, [0x00, 5, ADDRESS, 0, 0, 0, 0, 0])
    assert await poll_in(0, 0) == data_packet(0x4B, [])
    await until(lambda: len(starts) == 3)
    await setup(ADDRESS, [0x00, 9, 1, 0, 0, 0, 0, 0])
    assert await poll_in(ADDRESS, 0) == data_packet(0x4B, [])
    length = len(demo_usb.REPORT)
    await setup(ADDRESS, [0x81, 6, 0, 0x22, 0, 0, length & 0xFF, length >> 8])
    report, pid = [], 0x4B
    while len(report) < length:
        packet = await poll_in(ADDRESS, 0)
        assert packet == data_packet(pid, packet[1:-2]), packet
        report += packet[1:-2]
        pid = 0xC3 if pid == 0x4B else 0x4B
    assert report == demo_usb.REPORT
    await status_out(ADDRESS)

    # the laptop polls the keyboard until two lines are typed, the sensor warmer in between
    text, shifts = "", []
    while text.count("\n") < 2:
        packet = await poll_in(ADDRESS, 1, tries=2000)
        assert packet, f"no report after {text!r}"
        payload = packet[1:-2]
        assert payload[0] == 1 and len(payload) == 8, payload
        if typed(payload):
            text += typed(payload)
            shifts.append(payload[1])
            if text == "21.4 C\n":
                sensor.scratchpad = scratchpad(SECOND)
    cocotb.log.info(f"typed {text!r}")

    # both engines still run, with neither faulted, as the pins show
    host = AsyncHost(pins.transfer)
    done[0] = True
    await wire.drive(J, 400)
    await server
    states = []
    for engine in (0, 1):
        await host.write(SELECT, [engine])
        states.append((await host.read(STATUS))[0])
    assert [s & (FAULTS | 1) for s in states] == [0, 0], [hex(s) for s in states]

    assert text == "21.4 C\n22.4 C\n"
    # shift is held for the capital C alone
    assert shifts == [0, 0, 0, 0, 0, 2, 0] * 2, shifts
    # per reading: reset, SKIP ROM, CONVERT T, then reset, SKIP ROM, READ SCRATCHPAD
    reading = ["reset", "0xcc", "0x44", "reset", "0xcc", "0xbe"]
    assert sensor.log[:12] == reading * 2, sensor.log
    assert board.address == ADDRESS and board.configured
    assert not any("faults" in line or "bad" in line for line in said), said
