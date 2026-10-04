# SPDX-License-Identifier: Apache-2.0
"""The SWD act's own Python (python/demo_swd.py) on the RTL at the bench's 48 MHz, run
blocking in a thread as Pico A runs it, against two RP2040 SW-DPs modelled from the spec
(swd_target.py). Then what the act never sees: WAIT, FAULT, bad parity, a garbled ACK and
Pico B unpowered."""

import os
import re
import shutil
import subprocess
import sys

import cocotb
from cocotb.clock import Clock
from cocotb.task import bridge, resume
from cocotb.triggers import ClockCycles

from test import Pins
import demo_swd
import swd_target

sys.path.insert(0, "../demo")
import sigrok

# 48 MHz, as the Icepi's PLL makes it
CLOCK_PS = 20834
SWCLK = 3
SWDIO = 5


async def reset(dut):
    cocotb.start_soon(Clock(dut.clk, CLOCK_PS, unit="ps").start())
    dut.ena.value = 1
    dut.ui_in.value = 0b100
    dut.uio_in.value = 1 << SWDIO
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)


def wire(dut, bus, samples=None):
    """SWCLK from OUT2 and SWDIO on IO5, pulled up, to the DPs, every cycle, and the two
    lines into samples on D6 and D7, the analyser channels the act puts them on."""
    async def every_cycle():
        while True:
            swclk = (int(dut.uo_out.value) >> SWCLK) & 1
            drives = (int(dut.uio_oe.value) >> SWDIO) & 1
            host = (int(dut.uio_out.value) >> SWDIO) & 1 if drives else None
            line = bus.step(swclk, host)
            dut.uio_in.value = line << SWDIO
            if samples is not None:
                samples.append((swclk << 6) | (line << 7))
            await ClockCycles(dut.clk, 1)

    return cocotb.start_soon(every_cycle())


async def unwire(dut, task):
    """Stops the wire, and lets its last write land: with one pending when the test ends,
    after a thread has run, this cocotb's Icarus segfaults on the way out."""
    task.cancel()
    await ClockCycles(dut.clk, 2)


def decode(samples):
    """sigrok's reading of the lines, with the arguments demo/outside.sh swd gives it."""
    with open("../demo/outside.sh") as f:
        args = re.search(r"^swd\)\n\s+ms=\d+\n\s+decode=\"([^\"]*)\"", f.read(), re.M)[1]
    sigrok.write("outside_swd.sr", 10**12 // CLOCK_PS, samples)
    # sigrok's decoders run in the system's Python, not the simulator's
    env = {k: v for k, v in os.environ.items() if not k.startswith("PYTHON")}
    run = subprocess.run(["sigrok-cli", "-i", "outside_swd.sr"] + args.split(),
                         capture_output=True, text=True, env=env)
    assert run.returncode == 0, run.stderr
    cocotb.log.info("sigrok, as demo/outside.sh swd decodes the bench:\n%s", run.stdout)
    return run.stdout.splitlines()


def acted(dut):
    """transfer for the act's thread, and the log it writes to."""
    pins = Pins(dut)
    lines = []

    @resume
    async def transfer(data):
        return await pins.transfer(data)

    def log(text=""):
        cocotb.log.info(text)
        lines.append(text)

    return transfer, log, lines


def clean(bus):
    for i, dp in enumerate(bus.dps):
        cocotb.log.info("DP %d: %s, shortest %s ps", i, dp.log, dp.shortest)
        assert dp.violations == [], (i, dp.violations)
    assert bus.contention == 0


def let_go(dut):
    """SWCLK low and SWDIO not driven, as the act leaves them."""
    return (int(dut.uo_out.value) >> SWCLK) & 1 == 0 and (int(dut.uio_oe.value) >> SWDIO) & 1 == 0


def started(transfer, half=10):
    """SWD firmware running at half, its report of SWDIO let go read."""
    host = demo_swd.pe.Host(transfer)
    demo_swd.bench.load(host, demo_swd.bench_firmware.SWD)
    host.start()
    swd = demo_swd.Swd(host)
    assert swd.send([half], 1) == [1]
    return host, swd


@cocotb.test()
async def test_swd_act(dut):
    await reset(dut)
    bus = swd_target.Bus()
    samples = bytearray()
    task = wire(dut, bus, samples)
    transfer, log, lines = acted(dut)
    assert await bridge(demo_swd.run)(transfer, log=log), lines
    await ClockCycles(dut.clk, 100)
    assert let_go(dut)
    await unwire(dut, task)
    clean(bus)
    if shutil.which("sigrok-cli"):
        decoded = decode(samples)
        # it misreads the selection alert and TARGETSEL's data, but not the DPIDR reads
        reads = ["\n".join(decoded[i:i + 3]) for i, text in enumerate(decoded)
                 if text == "swd-1: IDCODE"]
        assert reads.count("swd-1: IDCODE\nswd-1: OK\nswd-1: 0x0bc12477") == 3, decoded
    core0, core1 = (dp.log for dp in bus.dps)
    assert core0[:4] == [
        "dormant to SWD", "line reset", "TARGETSEL 0x01002927: selected",
        "R DP 0x0 OK 0x0bc12477",
    ], core0
    assert "R DP 0xc OK 0x04770031" in core0, core0
    assert "TARGETSEL 0x11002927: selected" in core1, core1
    assert "TARGETSEL 0x21002927: deselected" in core0 and \
        "TARGETSEL 0x21002927: deselected" in core1


@cocotb.test()
async def test_swd_refusals(dut):
    """An AP busy for 60 clocks WAITs the RDBUFF read after its read; a read outside memory
    sets STICKYERR, so the next write FAULTs and the core drops its data words; and a DP
    sending the wrong parity has the core flag it."""
    await reset(dut)
    memory = {0x40000000: 0x20002927}
    bus = swd_target.Bus([swd_target.Dp(swd_target.CORE0, ap_latency=60, memory=memory)])
    task = wire(dut, bus)
    transfer, log, _ = acted(dut)

    def act():
        host, swd = started(transfer)
        swd.wake()
        swd.line_reset()
        swd.targetsel(swd_target.CORE0)
        acks = [swd.read(0, 0x0)[0], swd.write(0, demo_swd.SELECT, 0)]
        # TAR, then DRW too soon after it, then again, and RDBUFF too soon after that
        acks.append(swd.write(1, 0x4, 0x40000000))
        acks.append(swd.read(1, 0xC)[0])
        swd.read_until(1, 0xC)
        acks.append(swd.read(0, demo_swd.RDBUFF)[0])
        ack, value, good = swd.read_until(0, demo_swd.RDBUFF)
        acks.append(ack)
        # a read outside memory, and the write after it
        acks.append(swd.write(1, 0x4, 0x50000000))
        swd.read_until(1, 0xC)
        acks.append(swd.write(1, 0x4, 0x40000000))
        acks.append(swd.read(0, demo_swd.CTRL_STAT)[0])
        log("acks %s, RDBUFF 0x%08x" % (acks, value))
        return acks, value, good, demo_swd.bench.faults(host)

    acks, value, good, faults = await bridge(act)()
    await unwire(dut, task)
    clean(bus)
    OK, WAIT, FAULT = swd_target.OK, swd_target.WAIT, swd_target.FAULT
    assert acks == [OK, OK, OK, WAIT, WAIT, OK, OK, FAULT, OK], acks
    assert value == 0x20002927 and good
    assert faults == 0
    assert "W AP 0x4 FAULT" in bus.dps[0].log, bus.dps[0].log


@cocotb.test()
async def test_swd_parity(dut):
    """A DP whose RDATA parity is wrong: the core says so in the status."""
    await reset(dut)

    class Corrupt(swd_target.Dp):
        def respond(self, ap, read, address):
            actions = super().respond(ap, read, address)
            if read and len(actions) == 38:
                actions[35] = ("drive", 1 - actions[35][1])
            return actions

    bus = swd_target.Bus([Corrupt(swd_target.CORE0)])
    task = wire(dut, bus)
    transfer, _, _ = acted(dut)

    def act():
        _, swd = started(transfer)
        swd.wake()
        swd.line_reset()
        return swd.read(0, 0x0)

    ack, value, good = await bridge(act)()
    await unwire(dut, task)
    clean(bus)
    assert (ack, value, good) == (swd_target.OK, swd_target.DPIDR, False)


@cocotb.test()
async def test_swd_garbled_ack(dut):
    """A DP whose first two OK ACKs the wire garbles and which goes on with the data phase:
    the core lets the line be through RDATA and sends no WDATA, then a line reset and the
    DP answers."""
    await reset(dut)
    bus = swd_target.Bus([swd_target.Dp(swd_target.CORE0, corrupt_acks=2)])
    task = wire(dut, bus)
    transfer, _, _ = acted(dut)

    def act():
        _, swd = started(transfer)
        swd.wake()
        swd.line_reset()
        acks = [swd.read(0, 0x0)[0], swd.write(0, demo_swd.ABORT, 0x4)]
        swd.line_reset()
        return acks, swd.read(0, 0x0)

    acks, read = await bridge(act)()
    await unwire(dut, task)
    clean(bus)
    assert acks == [0b101, 0b101], acks
    assert read == (swd_target.OK, swd_target.DPIDR, True), read
    assert "W DP 0x0 with no WDATA" in bus.dps[0].log, bus.dps[0].log


@cocotb.test()
async def test_swd_unpowered(dut):
    """Pico B unpowered, so SWDIO reads low let go: the act stops before driving either
    line."""
    await reset(dut)
    bus = swd_target.Bus(undriven=0)
    driven = []

    async def watch():
        while True:
            driven.append(not let_go(dut))
            await ClockCycles(dut.clk, 1)

    task = wire(dut, bus)
    watcher = cocotb.start_soon(watch())
    transfer, log, lines = acted(dut)
    assert not await bridge(demo_swd.run)(transfer, log=log)
    watcher.cancel()
    await unwire(dut, task)
    assert not any(driven), "a line driven"
    assert "SWDIO is low" in lines[0], lines


@cocotb.test()
async def test_swd_unpowered_after_a_stopped_run(dut):
    """An earlier run stopped part-way through a sequence, SWCLK high and SWDIO driven
    high, then Pico B unpowered with no reset: the act lets SWDIO go before it reads it,
    and stops without driving either line again."""
    await reset(dut)
    bus = swd_target.Bus(undriven=0)
    driven = []

    async def watch():
        while True:
            driven.append(not let_go(dut))
            await ClockCycles(dut.clk, 1)

    task = wire(dut, bus)
    transfer, log, lines = acted(dut)

    def stopped():
        host = demo_swd.pe.Host(transfer)
        demo_swd.bench.load(host, demo_swd.bench_firmware.SWD)
        host.start()
        swd = demo_swd.Swd(host)
        swd.send([10], 1)
        swd.send(demo_swd.sequence([0xFFFF, 0xFFFF])[:2], 0)

    await bridge(stopped)()
    await ClockCycles(dut.clk, 1000)
    assert not let_go(dut)
    watcher = cocotb.start_soon(watch())
    assert not await bridge(demo_swd.run)(transfer, log=log)
    watcher.cancel()
    await unwire(dut, task)
    first = driven.index(False)
    assert not any(driven[first:]), "a line driven after the act let go"
    assert "SWDIO is low" in lines[0], lines


def words(data):
    """The words of a write frame."""
    return [(data[i] << 8) | data[i + 1] for i in range(1, len(data), 2)]


def levels(transfer):
    """The tx and rx fifo levels, read with transfer."""
    reply = transfer([demo_swd.pe.STATUS, 0, 0])
    status = (reply[1] << 8) | reply[2]
    return (status >> 6) & 15, (status >> 10) & 15


@cocotb.test()
async def test_swd_stopped_mid_sequence(dut):
    """Ctrl-C between the two pushes of the wake-up's eleven words, eight deep, the core
    holding SWCLK high and SWDIO driven for the rest, and again as the act lets go: it
    still lets both lines go."""
    await reset(dut)
    bus = swd_target.Bus()
    task = wire(dut, bus)
    transfer, log, _ = acted(dut)
    wake = demo_swd.sequence([0xFFFF] + demo_swd.ALERT + [demo_swd.ACTIVATION])
    pushed, held, again = [], [], []

    @resume
    async def holding():
        return not let_go(dut)

    def stopping(data):
        if held and not again and data[0] == 0x80 | demo_swd.pe.CONTROL:
            again.append(data)
            raise KeyboardInterrupt
        if data[0] == 0x80 | demo_swd.pe.TX:
            if not held and len(pushed) == 2 and pushed[1] == wake[:len(pushed[1])]:
                while levels(transfer)[0]:
                    pass
                for _ in range(50):
                    levels(transfer)
                held.append(holding())
                raise KeyboardInterrupt
            pushed.append(words(data))
        return transfer(data)

    def act():
        try:
            demo_swd.run(stopping, log=log)
        except KeyboardInterrupt:
            return True
        return False

    assert await bridge(act)()
    await ClockCycles(dut.clk, 100)
    assert held == [True] and len(again) == 1
    assert let_go(dut)
    await unwire(dut, task)
    assert bus.contention == 0


async def stopped_reading(dut, link_fails):
    """Ctrl-C while the act polls for core 0's DPIDR with replies waiting, and the SPI
    link failing from then on if link_fails. What run raised, whether the lines are let
    go, and the log."""
    await reset(dut)
    bus = swd_target.Bus()
    task = wire(dut, bus)
    transfer, log, lines = acted(dut)
    dpidr = [0x80 | demo_swd.pe.TX, 0, demo_swd.request(0, 1, 0x0)]
    asked, stopped = [], []

    def stopping(data):
        if stopped and link_fails:
            raise OSError("SPI link down")
        if list(data) == dpidr:
            asked.append(data)
        if asked and not stopped and data[0] == demo_swd.pe.STATUS:
            if levels(transfer)[1]:
                stopped.append(data)
                raise KeyboardInterrupt
        return transfer(data)

    def act():
        try:
            demo_swd.run(stopping, log=log)
        except BaseException as e:
            return e
        return None

    raised = await bridge(act)()
    await ClockCycles(dut.clk, 100)
    released = let_go(dut)
    await unwire(dut, task)
    return raised, released, lines


@cocotb.test()
async def test_swd_stopped_with_replies_waiting(dut):
    """Replies left in the rx fifo do not stop the act letting go, nor hide the Ctrl-C."""
    raised, released, _ = await stopped_reading(dut, link_fails=False)
    assert isinstance(raised, KeyboardInterrupt), repr(raised)
    assert released


@cocotb.test()
async def test_swd_letting_go_fails(dut):
    """The SPI link failing as the act lets go: the Ctrl-C is still what it raises, and the
    log says the lines may be held."""
    raised, _, lines = await stopped_reading(dut, link_fails=True)
    assert isinstance(raised, KeyboardInterrupt), repr(raised)
    assert "may be held" in lines[-1] and "SPI link down" in lines[-1], lines
