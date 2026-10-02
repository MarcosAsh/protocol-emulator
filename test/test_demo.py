# SPDX-License-Identifier: Apache-2.0
"""The bench demos' own Python, run blocking in a thread with each SPI frame a cocotb
transfer, as the host Pico runs it."""

import collections
import os
import sys
import types

import cocotb
from cocotb.task import bridge, resume
from cocotb.triggers import ClockCycles, Timer
from cocotb.utils import get_sim_time

from test import AsyncHost, Pins, reset
from test_usb_board import J, SE0, Wire, data_packet, token
import protocol_emulator
from protocol_emulator import CONTROL, SELECT, STATUS, TX, Host
import demo_self_check
import demo_self_timing
import demo_sweep
import demo_usb
import sweep_firmware
import usb_board
import usb_device_firmware

# cycles in a microsecond at 48 MHz, for the Pico's pauses
US = 48


def cycle():
    return int(get_sim_time("ns")) // 20


async def watch_out0(dut, out0):
    """Appends OUT0's (cycle, level) each time it changes."""
    while True:
        await dut.uo_out.value_change
        level = 1 if str(dut.uo_out.value)[-2] == "1" else 0
        if level != out0[-1][1]:
            out0.append((cycle(), level))


async def assert_no_faults(pins):
    host = AsyncHost(pins.transfer)
    for engine in (0, 1):
        await host.write(SELECT, [engine])
        assert (await host.read(STATUS))[0] & 0x3C == 0, f"engine {engine} faulted"


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

    def level_at(cycle):
        return [level for at, level in out0 if at <= cycle][-1]

    watcher = cocotb.start_soon(watch_out0(dut, out0))
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


def assert_typed(dut, out0, period, taken, text):
    """OUT0 carries text, each key once the laptop has acknowledged its report and before
    the next report: taken holds the cycle of each report's ACK, three to a key."""
    frames = uart_frames(out0[1:], period)
    dut._log.info(f"OUT0 frames at {[start for start, _ in frames]}, report ACKs at {taken}")
    assert bytes(byte for _, byte in frames) == text, frames
    for n, (start, _) in enumerate(frames):
        key = text[n:n + 1]
        assert taken[3 * n] < start < taken[3 * n + 1], f"{key} out of step with its report"


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

    out0 = [(0, 0)]
    watcher = cocotb.start_soon(watch_out0(dut, out0))

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

    # typing waits for SET_CONFIGURATION
    await setup(3, [0x00, 9, 1, 0, 0, 0, 0, 0])
    assert await poll_in(3, 0) == data_packet(0x4B, [])

    # SET_IDLE with h's report in the fifo. The status packet queues behind it, the status
    # IN drops the report, and the ACK after that is the status packet's.
    await until(lambda: board.pending_report is not None and not board.replies)
    await setup(3, [0x21, 0x0A, 0, 0, 0, 0, 0, 0])
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
    assert_typed(dut, out0, 434, taken, b"hi")
    await assert_no_faults(pins)


# test_keyboard's Python takes no sim time, so it passed while the bench overflowed the rx
# fifo. test_keyboard_slow_host charges each call what it costs Pico A and enumerates the
# way the bench laptop did. It runs in real time, a cycle being one of the chip's 48 MHz
# for the laptop's sleeps and the Pico's ms() too: the fifo race is in microseconds against
# 32 cycle bits, and a compressed millisecond would let a reload or a collection, charged
# in real cycles, outlast the 10 ms after SET_ADDRESS. That is 330 ms of chip, an hour on
# icarus, so only Verilator runs it:
#   make SIM=verilator COCOTB_TEST_MODULES=test_demo COCOTB_TEST_FILTER=slow_host
# PICO_SCALE=k multiplies every cost, for the margin, and TURNAROUND_US the laptop's time
# between transfers.

# Pico A's costs in microseconds: before the call's SPI frame and after it, per word moved
# (before a write's frame, after a read's), and the bytes allocated, per call and per word.
# The frame's simulated wire time comes off the first two. bench: timed on Pico A at 200
# MHz on 2026-10-01, the timing loop's 8 us call in it; fit: solved from the bench's load
# times; est: read off the code.
COSTS = {
    "Host.status": (60, 281, 0, 320, 0),  # bench 341; split, bytes est
    "Host.read": (60, 186, 0, 210, 0),  # bench 246 a word
    "Host.pop": (60, 168, 20.6, 210, 4),  # bench 228 for none, 372 for seven
    "Host.write": (80, 12, 28, 80, 42),  # fit: 120 a word, a full load 21.4 ms
    "PicoHost.write": (40, 12, 18, 64, 0),  # fit: six words 188 (bench), loads 1.3-1.7 ms
    "Board.feed": (50, 0, 0, 8, 0),  # bench: a status OUT's three words 152
    "_reverse": (118, 0, 0, 48, 0),  # bench: a SETUP fed in 2359, in 949 with the table
    "word_bytes": (10, 0, 0, 32, 0),  # est
    "Board._setup": (440, 0, 0, 600, 0),  # bench: that 949 less its feeds and lookups
    "reply": (100, 0, 0, 100, 0),  # est
    "service": (40, 0, 0, 32, 0),  # est; the bench's 260-461 idle is mostly collections
    "bus_reset": (30, 0, 0, 0, 0),  # bench 24 less its Pin reads, and serve's loop 15 est
    "words": (1000, 0, 0, 1900, 0),  # fit: a same address load 1.4 ms less four writes
    "Host.load": (1000, 0, 0, 4100, 0),  # est: the words copied again, then zeros
    "config_writes": (400, 0, 0, 1100, 0),  # est
    "say": (300, 0, 0, 100, 0),  # est: a line printed over the Pico's USB serial
}
# PicoSpi.drain_quiet's native loop, per status read and per rx read and its words, the
# frame's wire time in each. est: a PicoHost.status of the bench's 95 less its dict, and
# a PicoHost.pop of 84 and 7.1 a word less its call and list
DRAIN_STATUS_US = 60
DRAIN_POP_US, DRAIN_WORD_US = 50, 7.1
PIN_US = 4.7  # est: a Pin read, as a CS edge
# bench: gc.mem_free() with the demo imported, and r3's pauses in serve, 660 ms apart there
GC_HEAP = 200_000
GC_PAUSE_US = 11_000

# The bench laptop, Linux on an xHCI root port. bench: the r1 and r3 logs on Pico A.
RESET_US = 50_000  # USB 2.0 7.1.7.5, a root port's
RESET_RECOVERY_US = 60_000  # bench: 110 ms from each reset to the next SETUP
SET_ADDRESS_US = 10_700  # bench: 10.7 and 10.9 ms from the status ACK to the next SETUP
# est: a completion's interrupt, the hub thread woken, the next URB queued; r3 bounds it
# below about 370 us, and nothing here is less certain
TURNAROUND_US = float(os.environ.get("TURNAROUND_US", 100))
BIND_US = 1_000  # est: the driver bound before SET_CONFIGURATION, usbhid before SET_IDLE
OPEN_US = 10_000  # est: the input device opened, then EP1 polled
POLL_US = 8_000  # xHCI's interval for bInterval 10 at low speed
# bits between a transfer's transactions, and before a transaction goes again after a NAK
# and after no good reply. bench, the analyser on 2026-10-02: 2.2 us, 57 to 197 us, 20 us
GAP = 3
NAK_RETRY = 85
ERROR_RETRY = 30
TIMEOUT = 17  # bits a host waits for the reply, USB 2.0's 16 to 18
NAK_LIMIT_US = 50_000  # in place of the kernel's 5 s, past any pause the Pico takes
ADDRESS = 16  # bench r3

ACK, NAK, DATA0, DATA1 = 0xD2, 0x5A, 0xC3, 0x4B
PIDS = {ACK: "ACK", NAK: "NAK", 0x1E: "STALL", DATA0: "DATA0", DATA1: "DATA1"}


def bus(dut):
    """D+ | D- << 1 as a Pico watching the bus sees it, the device's where it drives."""
    if int(dut.uio_oe.value) & 3 == 3:
        return int(dut.uio_out.value) & 3
    return int(dut.uio_in.value) & 3


class Pico:
    """Pico A's clock, and the MicroPython it runs on. A call's cost goes on a tab that is
    paid in chip cycles before the Pico next touches the chip, and a collection joins it
    each time calls have allocated a heap's worth."""

    def __init__(self, dut, scale):
        self.dut = dut
        self.pins = Pins(dut)
        self.scale = scale
        self.owed = 0.0
        self.free = GC_HEAP
        self.depth = 0
        # inside a native loop, whose frames are charged one by one
        self.native = False
        self.done = False
        self.collections = []
        self.undo = []

    def spend(self, us, allocates=0):
        self.owed += us * US * self.scale
        self.free -= allocates
        if self.free <= 0:
            self.collect()

    def collect(self):
        self.collections.append(cycle() + round(self.owed))
        self.owed += GC_PAUSE_US * US * self.scale
        self.free = GC_HEAP

    async def settle(self):
        if self.done:
            raise Done
        cycles = round(self.owed)
        self.owed -= cycles
        if cycles > 0:
            await Timer(cycles * 20, "ns")

    @resume
    async def frame(self, data):
        await self.settle()
        return await self.pins.transfer(data)

    @resume
    async def line(self, pin):
        await self.settle()
        return bus(self.dut) >> (pin - 6) & 1

    @resume
    async def ticks_ms(self):
        await self.settle()
        return cycle() // (1000 * US)

    def costly(self, cost, function, words=None):
        """function, costing what COSTS says. With words, which gives the words its SPI frame
        moves, it is I/O, charged at the outermost call only."""
        before, after, per_word, allocates, per_word_allocates = COSTS[cost]

        def charged(*args, **kwargs):
            if words is None:
                self.spend(before, allocates)
                return function(*args, **kwargs)
            if self.depth:
                return function(*args, **kwargs)
            n = words(*args, **kwargs)
            first, then = (before + per_word * n, after) if cost.endswith("write") else (
                before, after + per_word * n)
            cut = max(0, 1 - (64 * (1 + 2 * n) + 11) / US / (first + then))
            self.spend(first * cut, allocates + per_word_allocates * n)
            self.depth += 1
            try:
                return function(*args, **kwargs)
            finally:
                self.depth -= 1
                self.spend(then * cut)

        return charged

    def native_frame(self, out):
        n = (len(out) - 1) // 2
        us = DRAIN_STATUS_US if out[0] == STATUS else DRAIN_POP_US + DRAIN_WORD_US * n
        self.spend(max(0, us - (64 * len(out) + 11) / US), 4 * n)

    def natively(self, function):
        """function, a native loop over SPI frames, each charged as native_frame says."""

        def charged(*args):
            self.native = True
            try:
                return function(*args)
            finally:
                self.native = False

        return charged

    def patch(self, owner, name, value):
        self.undo.append((owner, name, getattr(owner, name)))
        setattr(owner, name, value)

    def charge(self, owner, name, cost, words=None):
        if name in vars(owner):
            self.patch(owner, name, self.costly(cost, vars(owner)[name], words))

    def install(self):
        """machine and micropython as pico_board uses them, the clock as demo_usb.run
        does, and every call costed, as far as the code in python/ has it."""
        pico = self

        class Pin:
            IN, OUT = 0, 1

            def __init__(self, pin, mode=IN, value=0):
                self.pin = pin

            # chip select's edges frame each transfer, which is one cocotb transfer here
            def __call__(self, value=None):
                if value is not None:
                    return None
                pico.spend(PIN_US)
                return pico.line(self.pin)

        class SPI:
            MSB = 0

            def __init__(self, *args, **kwargs):
                pass

            def write_readinto(self, out, into):
                if pico.native:
                    pico.native_frame(out)
                into[:] = bytes(pico.frame(list(out)))

            def write(self, out):
                pico.frame(list(out))

        machine = types.SimpleNamespace(Pin=Pin, SPI=SPI, freq=lambda hz=None: None)
        sys.modules["machine"] = machine
        sys.modules["micropython"] = types.SimpleNamespace(native=lambda f: f)
        sys.modules.pop("pico_board", None)
        import pico_board

        self.patch(demo_usb, "time", types.SimpleNamespace(ticks_ms=self.ticks_ms))
        if hasattr(usb_board, "gc"):
            self.patch(usb_board, "gc", types.SimpleNamespace(collect=self.collect))
        se0_reset = demo_usb.se0_reset
        self.patch(demo_usb, "se0_reset",
                   lambda *args, **kwargs: self.costly("bus_reset", se0_reset(*args, **kwargs)))
        one = lambda *args: 1
        count = lambda host, count=1: count
        for owner, prefix in ((Host, "Host"), (getattr(pico_board, "PicoHost", None), "PicoHost")):
            if owner is None:
                continue
            self.charge(owner, "status", f"{prefix}.status", one)
            self.charge(owner, "read", f"{prefix}.read", lambda host, reg, count=1: count)
            self.charge(owner, "pop", f"{prefix}.pop", count)
            self.charge(owner, "write", f"{prefix}.write", lambda host, reg, words: len(words))
        if hasattr(pico_board.PicoSpi, "drain_quiet"):
            self.patch(pico_board.PicoSpi, "drain_quiet",
                       self.natively(pico_board.PicoSpi.drain_quiet))
        self.charge(Host, "load", "Host.load")
        self.charge(protocol_emulator, "config_writes", "config_writes")
        self.charge(usb_board.Board, "feed", "Board.feed")
        self.charge(usb_board.Board, "_setup", "Board._setup")
        for name in ("_reverse", "word_bytes", "reply", "service"):
            self.charge(usb_board, name, name)
        self.charge(usb_device_firmware, "words", "words")

    def uninstall(self):
        for owner, name, value in reversed(self.undo):
            setattr(owner, name, value)
        for name in ("machine", "micropython", "pico_board"):
            sys.modules.pop(name, None)


class Failed(Exception):
    """The laptop gave up, with the kernel's error."""


class Laptop:
    """Linux enumerating a low-speed device on an xHCI root port: a transfer's packets back
    to back, a NAKed transaction retried within 60 us, three tries before -71."""

    def __init__(self, dut, overflowed):
        self.dut = dut
        self.wire = Wire(dut)
        self.overflowed = overflowed
        self.events = collections.deque(maxlen=400)
        self.naks = 0
        # (cycles from a transaction's first try to its answer, the transfer, the kind)
        self.waits = []
        self.addressed = None

    def note(self, what):
        self.events.append((cycle(), what))

    async def idle(self, us, state=J):
        self.dut.uio_in.value = state[0] | (state[1] << 1)
        await Timer(round(us * US) * 20, "ns")

    async def send(self, packet, what):
        self.note(what)
        await self.wire.send(packet)

    async def reply(self):
        packet = await self.wire.listen(TIMEOUT)
        if packet is None:
            self.note("no reply")
        else:
            payload = bytes(packet[1:-2]).hex() if len(packet) > 1 else ""
            self.note(f"{PIDS.get(packet[0], hex(packet[0]))} {payload}".strip())
        return packet

    async def transaction(self, what, kind, send):
        """send() puts a transaction on the wire and returns the reply: a handshake or a good
        data packet. It goes again after a NAK, and after a bad reply up to three times."""
        errors, since = 0, cycle()
        while True:
            reply = await send()
            if self.overflowed():
                raise Failed(f"{what}: the rx fifo overflowed")
            if reply == [NAK]:
                self.naks += 1
                if cycle() - since > NAK_LIMIT_US * US:
                    raise Failed(f"{what}: -110, NAKed for {NAK_LIMIT_US // 1000} ms")
            elif reply and (len(reply) == 1 or reply == data_packet(reply[0], reply[1:-2])):
                self.waits.append((cycle() - since, what, kind))
                return reply
            else:
                errors += 1
                if errors == 3:
                    raise Failed(f"{what}: -71, {reply or 'no reply'} to {kind}")
            await self.wire.drive(J, NAK_RETRY if reply == [NAK] else ERROR_RETRY)

    async def setup(self, address, request, what):
        async def send():
            await self.send(token(0x2D, address, 0), f"SETUP {address}")
            await self.wire.drive(J, 3)
            await self.send(data_packet(DATA0, request), f"DATA0 {bytes(request).hex()}")
            return await self.reply()

        if await self.transaction(what, "SETUP", send) != [ACK]:
            raise Failed(f"{what}: SETUP not acknowledged")

    async def data_in(self, address, endpoint, pid, what):
        async def send():
            await self.send(token(0x69, address, endpoint), f"IN {address}/{endpoint}")
            return await self.reply()

        packet = await self.transaction(what, "IN", send)
        if packet[0] != pid:
            raise Failed(f"{what}: {PIDS.get(packet[0], hex(packet[0]))} where {PIDS[pid]} was due")
        await self.send([ACK], "ACK")
        return packet[1:-2]

    async def status_out(self, address, what):
        async def send():
            await self.send(token(0xE1, address, 0), f"OUT {address}")
            await self.wire.drive(J, 3)
            await self.send(data_packet(DATA1, []), "DATA1")
            return await self.reply()

        if await self.transaction(what, "OUT", send) != [ACK]:
            raise Failed(f"{what}: status OUT not acknowledged")

    async def control_read(self, address, request, what):
        await self.setup(address, request, what)
        length, data, pid = request[6] | request[7] << 8, [], DATA1
        while True:
            await self.wire.drive(J, GAP)
            payload = await self.data_in(address, 0, pid, what)
            data += payload
            pid = DATA0 if pid == DATA1 else DATA1
            if len(payload) < 8 or len(data) >= length:
                break
        await self.wire.drive(J, GAP)
        await self.status_out(address, what)
        return data

    async def control_write(self, address, request, what):
        await self.setup(address, request, what)
        await self.wire.drive(J, GAP)
        if await self.data_in(address, 0, DATA1, what) != []:
            raise Failed(f"{what}: data in the status stage")

    async def reset(self):
        self.note("reset")
        await self.idle(RESET_US, SE0)
        await self.idle(RESET_RECOVERY_US)


async def enumerate_and_type(laptop, text):
    """What the bench laptop did: hub_port_init's two resets around the first read, then the
    descriptors, the configuration, usbhid's requests, and EP1 polled until text is typed.
    The reports and the cycle of each one's ACK."""

    def get(kind, length, recipient=0x80):
        return [recipient, 6, 0, kind, 0, 0, length & 0xFF, length >> 8]

    async def read(address, request, what, expected):
        data = await laptop.control_read(address, request, what)
        if data != expected:
            raise Failed(f"{what}: {bytes(data).hex()}")
        await laptop.idle(TURNAROUND_US)

    await laptop.reset()
    await read(0, get(1, 64), "device descriptor read/64", demo_usb.DEVICE)
    await laptop.reset()
    await laptop.control_write(0, [0, 5, ADDRESS, 0, 0, 0, 0, 0], "SET_ADDRESS")
    laptop.addressed = cycle()
    await laptop.idle(SET_ADDRESS_US)
    await read(ADDRESS, get(1, 18), "device descriptor read/all", demo_usb.DEVICE)
    configuration = demo_usb.CONFIGURATION
    await read(ADDRESS, get(2, 9), "config index 0 descriptor/start", configuration[:9])
    await read(ADDRESS, get(2, len(configuration)), "config index 0 descriptor/all", configuration)
    await laptop.idle(BIND_US)
    await laptop.control_write(ADDRESS, [0, 9, 1, 0, 0, 0, 0, 0], "SET_CONFIGURATION")
    await laptop.idle(BIND_US)
    await laptop.control_write(ADDRESS, [0x21, 0x0A, 0, 0, 0, 0, 0, 0], "SET_IDLE")
    await laptop.idle(TURNAROUND_US)
    report = demo_usb.REPORT
    await read(ADDRESS, get(0x22, len(report), 0x81), "report descriptor", report)
    await laptop.idle(OPEN_US)

    reports, taken, pid = [], [], DATA0
    for _ in range(10 * len(text)):
        if len(reports) == 3 * len(text):
            break
        start = cycle()
        await laptop.send(token(0x69, ADDRESS, 1), f"IN {ADDRESS}/1")
        packet = await laptop.reply()
        if packet != [NAK]:
            if not packet or packet[0] != pid or packet != data_packet(pid, packet[1:-2]):
                raise Failed(f"EP1 poll: {packet}")
            taken.append(cycle())
            await laptop.send([ACK], "ACK")
            reports.append(packet[1:-2])
            pid = DATA0 if pid == DATA1 else DATA1
        await laptop.idle(POLL_US - (cycle() - start) / US)
    return reports, taken


def timeline(laptop, levels, halts, pico, start, end):
    """The laptop's packets, the rx fifo's level, engine 0 halting and starting, and the
    Pico's collections over the 12 ms to end, one a line, a run of NAKed INs on one."""
    lines = [(at, what) for at, what in laptop.events]
    lines += [(at, f"    rx fifo {level}") for at, level in levels]
    lines += [(at, f"    engine 0 {'halted' if halted else 'started'}") for at, halted in halts]
    lines += [(at, f"    GC {GC_PAUSE_US * pico.scale / 1000:.0f} ms") for at in pico.collections]
    rows = []
    for at, what in sorted(lines, key=lambda line: line[0]):
        if not end - 12_000 * US <= at <= end or what == "NAK" and not rows:
            continue
        if rows and rows[-1][1].startswith("IN") and what == "NAK":
            rows[-1][2] += 1
        elif not (rows and rows[-1][2] and what == rows[-1][1]):
            rows.append([at, what, 0])
    return "\n".join(
        f"{(at - start) / (1000 * US):10.3f} ms  {what}" + (f", NAKed {naks} times" if naks else "")
        for at, what, naks in rows)


@cocotb.test(skip=cocotb.SIM_NAME != "Verilator")
async def test_keyboard_slow_host(dut):
    """Act 3 as demo_usb.run runs it on Pico A, at Pico A's pace, against the bench laptop."""
    await reset(dut)
    start = cycle()
    scale = float(os.environ.get("PICO_SCALE", 1))
    engine = dut.user_project.core.top.engines.engine_0
    overflow = next(h for h in engine if "fault$overflow" in h._name)
    levels, halts, overflowed, out0 = [(0, 0)], [], [], [(0, 0)]

    async def watch(signal, changes):
        while True:
            await signal.value_change
            changes.append((cycle(), int(signal.value)))

    async def watch_overflow():
        while int(overflow.value) == 0:
            await overflow.value_change
        overflowed.append(cycle())

    watchers = [
        cocotb.start_soon(w)
        for w in (watch(engine.rx_level, levels), watch(engine.halted, halts), watch_overflow(),
                  watch_out0(dut, out0))
    ]
    pico = Pico(dut, scale)
    pico.install()

    said = []

    def run():
        try:
            demo_usb.run("hi", say=pico.costly("say", said.append))
        except Done:
            pass

    server = cocotb.start_soon(bridge(run)())
    laptop = Laptop(dut, lambda: overflowed)
    try:
        reports, taken = await enumerate_and_type(laptop, b"hi")
    except Failed as failure:
        failed, failed_at = failure, cycle()
    else:
        failed = None
        await laptop.idle(500)
    finally:
        pico.done = True
        await server
        pico.uninstall()
    for watcher in watchers:
        watcher.cancel()
    peak = max(level for _, level in levels)
    dut._log.info(
        f"k {scale}: {(cycle() - start) / (1000 * US):.1f} ms of chip, peak rx level {peak}, "
        f"{laptop.naks} NAKs, collections at "
        f"{[round((at - start) / (1000 * US), 1) for at in pico.collections]} ms")
    # USB 2.0 9.2.6: a request's data within 500 ms, a status stage within 50 ms, and the
    # new address within 2 ms of SET_ADDRESS's status stage, where Linux waits 10
    if laptop.waits:
        waited, what, kind = max(laptop.waits)
        dut._log.info(f"longest wait for an answer {waited / (1000 * US):.3f} ms, {kind} of {what}")
    if laptop.addressed is not None:
        ready = next((at for at, halted in halts if not halted and at > laptop.addressed), None)
        dut._log.info(
            "engine 0 never started at the new address" if ready is None else
            f"engine 0 started at the new address {(ready - laptop.addressed) / (1000 * US):.3f}"
            " ms after SET_ADDRESS's status stage")
    if failed or overflowed:
        end = overflowed[0] if overflowed else failed_at
        host = AsyncHost(pico.pins.transfer)
        await host.write(SELECT, [0])
        status = (await host.read(STATUS))[0]
        faults = [name for bit, name in ((2, "underflow"), (3, "overflow")) if status >> bit & 1]
        raise AssertionError(
            f"{failed}; peak rx level {peak}"
            + (f", overflow at {(end - start) / (1000 * US):.3f} ms" if overflowed else "")
            + f", engine 0 faults {faults}\n" + timeline(laptop, levels, halts, pico, start, end))
    assert reports == demo_usb.reports("hi"), reports
    dut._log.info(f"the Pico said {said}")
    assert any(line.startswith("engine 0 is serving") for line in said), said
    assert said[-4:] == [f"address {ADDRESS}", "configured", "typed h", "typed i"], said
    # run() starts the logger for 48 MHz
    assert_typed(dut, out0, (48_000_000 + demo_usb.BAUD // 2) // demo_usb.BAUD, taken, b"hi")
    await assert_no_faults(pico.pins)


@cocotb.test()
async def test_self_check(dut):
    """The self-check as the Pico runs it: the quiet frames all on the wire with no alarm,
    one alarm per glitch, from the check the script names, then quiet again. Wire 20 never
    reaches a pad, so the testbench reads it, and engine 1's irq, from the RTL."""
    await reset(dut)
    pins = Pins(dut)
    engines = dut.user_project.core.top.engines

    def cycle():
        return int(get_sim_time("ns")) // 20

    # (cycle, period) of each restart's push
    pushes = []

    @resume
    async def transfer(data):
        if data[0] == 0x80 | TX:
            pushes.append((cycle(), data[1] << 8 | data[2]))
        return await pins.transfer(data)

    @resume
    async def pause():
        await ClockCycles(dut.clk, 300 * US)

    # the wire's level from each cycle it changes, and each rise of engine 1's irq
    wire, irqs = [(0, 0)], []

    async def watch_wire():
        while True:
            await engines.engine_0.pin_out.value_change
            level = (int(engines.engine_0.pin_out.value) >> demo_self_check.WIRE) & 1
            if level != wire[-1][1]:
                wire.append((cycle(), level))

    async def watch_irq():
        while True:
            await engines.engine_1.irq.value_change
            if int(engines.engine_1.irq.value):
                irqs.append(cycle())

    watchers = [cocotb.start_soon(watch_wire()), cocotb.start_soon(watch_irq())]
    frames = 14
    ok = await bridge(demo_self_check.run)(transfer, frames=frames, pause=pause)
    for watcher in watchers:
        watcher.cancel()
    assert ok

    period = demo_self_check.PERIOD
    glitches = [(at, p) for at, p in pushes if p != period]
    assert [p for _, p in glitches] == list(demo_self_check.GLITCHES), pushes
    first, last = glitches[0][0], glitches[-1][0]
    rearmed = next(at for at, _ in pushes if at > last)
    # each quiet run is every byte in turn on the wire, from the line idle high
    before = [edge for edge in wire[1:] if edge[0] < first]
    after = [(rearmed, 1)] + [edge for edge in wire if edge[0] > rearmed]
    for line in before, after:
        quiet = uart_frames(line, period)
        assert bytes(byte for _, byte in quiet) == bytes(range(frames)), quiet
    # one alarm a glitch, none on the quiet frames
    assert len(irqs) == len(glitches), (irqs, glitches)
    # the frame test_self_check.ml prints, as the script reads it from the rows
    edges = [bit * period for bit in range(1, 10)] + [10 * period + 6]
    with open("uart_tx_host_rate_rows.hex") as f:
        assert demo_self_check.certified([int(w, 16) for w in f.read().split()]) == edges
    # the checker's irq shows six cycles after the write it checks shows on the wire
    for (pushed, glitch), irq in zip(glitches, irqs):
        start = next(at for at, level in wire if at > pushed and level == 0)
        moved, check = demo_self_check.caught_by(edges, demo_self_check.GLITCH_BYTE, glitch)
        dut._log.info(f"period {glitch}: moved at {moved}, irq {irq - start} after the start bit")
        assert irq - start == check + 6, (glitch, irq - start, check)
