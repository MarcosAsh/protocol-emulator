# SPDX-License-Identifier: Apache-2.0
"""The outside chip acts' own Python on the RTL at the bench's 48 MHz, run blocking in a
thread as Pico A runs it, against a third-party model of the part where there is one. The
pins are sampled as the analyser samples them and decoded with the sigrok decoders
demo/outside.sh runs on the bench's capture."""

import math
import os
import re
import subprocess
import sys

import cocotb
from cocotb.clock import Clock
from cocotb.task import bridge, resume
from cocotb.triggers import ClockCycles, FallingEdge, RisingEdge, Timer
from cocotb.utils import get_sim_time
from cocotbext.i2c import I2cMemory

from test import Pins
import demo_can
import demo_ds18b20
import demo_eeprom
import demo_flash
import demo_neopixel

sys.path.insert(0, "../demo")
import sigrok

# 48 MHz, as the Icepi's PLL makes it
CLOCK_PS = 20834
# the analyser's rate on the bench
RATE = 24_000_000
# cycles in a millisecond: the acts' pauses are kept, which CAN's idle and the SK6812's
# latch need
MS = 48_000


def decoders():
    """Each act's sigrok arguments from demo/outside.sh, so the rehearsal decodes what the
    bench decodes."""
    with open("../demo/outside.sh") as f:
        text = f.read()
    return {
        act: args.split()
        for act, args in re.findall(r"^(\w+)\)\n\s+ms=\d+\n\s+decode=\"([^\"]*)\"", text, re.M)
    }


async def reset(dut):
    cocotb.start_soon(Clock(dut.clk, CLOCK_PS, unit="ps").start())
    dut.ena.value = 1
    dut.ui_in.value = 0b100
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)


class Analyser:
    """Every change of the lines on its channels, sampled at RATE into a sigrok session."""

    def __init__(self, channels):
        self.channels = channels
        self.edges = {channel: [(0, level())] for channel, (_, level) in channels.items()}
        for channel in channels:
            cocotb.start_soon(self.watch(channel))

    async def watch(self, channel):
        signal, level = self.channels[channel]
        edges = self.edges[channel]
        while True:
            await signal.value_change
            now = level()
            if now != edges[-1][1]:
                edges.append((get_sim_time("ps"), now))

    def levels(self, channel):
        return self.edges[channel]

    def write(self, path):
        period = 10**12 / RATE
        count = int(get_sim_time("ps") // period)
        samples = 0
        for channel, edges in self.edges.items():
            ends = [at for at, _ in edges[1:]] + [count * period]
            pieces = [
                bytes([level << channel]) * (
                    min(count, math.ceil(end / period)) - min(count, math.ceil(at / period)))
                for (at, level), end in zip(edges, ends)
            ]
            samples |= int.from_bytes(b"".join(pieces), "big")
        sigrok.write(path, RATE, samples.to_bytes(count, "big"))


def bit(signal, n=None):
    """A line's level, 1 for anything not driven low."""
    def level():
        text = str(signal.value)
        return 0 if (text[len(text) - 1 - n] if n is not None else text) == "0" else 1

    return signal, level


def decode(analyser, act):
    path = "outside_%s.sr" % act
    analyser.write(path)
    # sigrok's decoders run in the system's Python, not the simulator's
    env = {k: v for k, v in os.environ.items() if not k.startswith("PYTHON")}
    run = subprocess.run(
        ["sigrok-cli", "-i", path] + decoders()[act], capture_output=True, text=True, env=env
    )
    assert run.returncode == 0, run.stderr
    out = run.stdout
    cocotb.log.info("sigrok, as demo/outside.sh %s decodes the bench:\n%s", act, out)
    return out.splitlines()


def acted(dut, pins=None):
    """transfer and pause_ms for an act's thread, and the log it writes to."""
    pins = pins or Pins(dut)
    lines = []

    @resume
    async def transfer(data):
        return await pins.transfer(data)

    @resume
    async def pause_ms(n):
        await ClockCycles(dut.clk, n * MS)

    def log(text=""):
        cocotb.log.info(text)
        lines.append(text)

    return transfer, pause_ms, log, lines


@cocotb.test()
async def test_flash(dut):
    """The flash act's commands against picosoc's spiflash.v, which models only release
    from power down and the reads: so the wake and a read of a page it was loaded with.
    JEDEC ID, status, program and erase it does not have, and they are scripted only."""
    await reset(dut)
    page = demo_flash.pattern(0x5A)
    for i, value in enumerate(page):
        dut.flash.memory[demo_flash.SECTOR + i].value = value
    # the model takes no command until CS has risen once
    dut.flash_cs_n.value = 0
    await ClockCycles(dut.clk, 1)
    dut.flash_cs_n.value = 1
    analyser = Analyser({
        4: bit(dut.uo_out, 1), 5: bit(dut.uo_out, 2), 6: bit(dut.miso), 7: bit(dut.flash_cs_n),
    })
    transfer, pause_ms, log, _ = acted(dut)

    @resume
    async def cs(level):
        dut.flash_cs_n.value = level

    def act():
        host = demo_flash.pe.Host(transfer)
        demo_flash.start(host)
        flash = demo_flash.Flash(host, cs, pause_ms)
        flash.wake()
        back = flash.read(demo_flash.SECTOR, demo_flash.PAGE)
        log("read 0x%06x: %s ..." % (demo_flash.SECTOR, demo_flash.bench.hexs(back[:8])))
        return back, demo_flash.bench.faults(host)

    back, faults = await bridge(act)()
    lines = decode(analyser, "flash")
    assert back == page
    assert faults == 0
    assert "spiflash-1: Command: Release from deep powerdown / Read electronic ID (RDP/RES)" in lines
    read = "spiflash-1: Read data (addr 0x%06x, %d bytes): %s" % (
        demo_flash.SECTOR, demo_flash.PAGE, demo_flash.bench.hexs(page))
    assert read in lines, lines


class Memory(I2cMemory):
    """cocotbext-i2c 0.1.2's memory keeps bits of the old address when a two-byte one comes
    in, its mask not shifted to the byte, so here each byte is set in place."""

    async def handle_write(self, data):
        if self.addr_ptr < 0:
            await super().handle_write(data)
            return
        shift = 8 * self.addr_ptr
        self.ptr = (self.ptr & ~(0xFF << shift)) | (data << shift)
        self.addr_ptr -= 1


@cocotb.test()
async def test_eeprom(dut):
    """The EEPROM act against cocotbext-i2c's I2C memory, 32 KiB at 0x52, so the act has to
    find it. The model ends no write cycle, so ACK polling sees no NACK."""
    await reset(dut)
    memory = Memory(
        sda=dut.sda, sda_o=dut.sda_o, scl=dut.scl, scl_o=dut.scl_o, addr=0x52, size=32768
    )
    analyser = Analyser({6: bit(dut.sda), 7: bit(dut.scl)})
    transfer, _, log, lines = acted(dut)

    @resume
    async def clock():
        return get_sim_time("ns") // 1_000_000

    assert await bridge(demo_eeprom.run)(transfer, clock, log=log)
    page = [(1 + 13 * i) & 0xFF for i in range(demo_eeprom.PAGE)]
    assert list(memory.read_mem(demo_eeprom.PAGE_ADDRESS, demo_eeprom.PAGE)) == page
    assert memory.read_mem(demo_eeprom.BYTE_ADDRESS, 1) == b"\x01"
    # every START, repeated ones included: SCL high this long before SDA falls, which
    # SCL's rise on the bench eats into against Fast-mode's 600 ns
    scl = analyser.levels(7)
    setups = [
        (fall - max(at for at, level in scl if at <= fall and level == 1)) / 1000
        for fall, level in analyser.levels(6)[1:]
        if level == 0 and [v for at, v in scl if at <= fall][-1] == 1
    ]
    cocotb.log.info("least START setup: %d ns", min(setups))
    assert min(setups) >= 1000
    decoded = decode(analyser, "eeprom")
    data = " ".join("%02X" % b for b in page)
    for line in [
        "Page write (addr=%04X, 1 byte): 01" % demo_eeprom.BYTE_ADDRESS,
        "Page write (addr=%04X, 64 bytes): %s" % (demo_eeprom.PAGE_ADDRESS, data),
        "Sequential random read (addr=%04X, 64 bytes): %s" % (demo_eeprom.PAGE_ADDRESS, data),
    ]:
        assert "eeprom24xx-1: " + line in decoded, (line, decoded)


class Ds18b20:
    """A DS18B20 as its datasheet times it. There is no third-party model, so this one is
    ours: a presence pulse 30 to 150 us after a reset, a zero held 30 us from the falling
    edge, READ ROM, SKIP ROM, CONVERT T busy for CONVERTING read slots, READ SCRATCHPAD."""

    CONVERTING = 12

    def __init__(self, dut, rom, scratchpad):
        self.dut = dut
        self.rom = rom
        self.scratchpad = scratchpad
        self.sending = []
        self.received = []
        self.busy = 0
        self.log = []
        cocotb.start_soon(self.run())

    async def hold(self, us):
        self.dut.dq_o.value = 0
        await Timer(us, unit="us")
        self.dut.dq_o.value = 1

    def take(self, value):
        self.received.append(value)
        if len(self.received) < 8:
            return
        byte = sum(b << i for i, b in enumerate(self.received))
        self.received = []
        self.log.append("0x%02x" % byte)
        if byte == 0x33:
            self.sending = [(b >> i) & 1 for b in self.rom for i in range(8)]
        elif byte == 0x44:
            self.busy = self.CONVERTING
        elif byte == 0xBE:
            self.sending = [(b >> i) & 1 for b in self.scratchpad for i in range(8)]

    async def run(self):
        while True:
            await RisingEdge(self.dut.dq_held)
            start = get_sim_time("ns")
            # a read slot: a bit of what is being sent, or a zero while converting
            sent = None
            if self.sending:
                sent = self.sending.pop(0)
            elif self.busy:
                self.busy -= 1
                sent = 0
            if sent == 0:
                cocotb.start_soon(self.hold(30))
            await FallingEdge(self.dut.dq_held)
            low = (get_sim_time("ns") - start) / 1000
            if low >= 480:
                self.sending, self.received, self.busy = [], [], 0
                self.log.append("reset")
                await Timer(30, unit="us")
                await self.hold(120)
            elif sent is None:
                self.take(1 if low < 15 else 0)


def with_crc(data):
    return data + [demo_ds18b20.crc8(data)]


@cocotb.test()
async def test_ds18b20(dut):
    """The DS18B20 act against our own model, its line decoded by sigrok's 1-Wire link and
    network layers."""
    await reset(dut)
    rom = with_crc([0x28, 0xD1, 0xC3, 0x5A, 0x0B, 0x00, 0x00])
    # +25.0625 C, the datasheet's own example, and 12-bit resolution
    pad = with_crc([0x91, 0x01, 0x4B, 0x46, 0x7F, 0xFF, 0x0C, 0x10])
    device = Ds18b20(dut, rom, pad)
    analyser = Analyser({6: bit(dut.dq)})
    transfer, _, log, lines = acted(dut)
    assert await bridge(demo_ds18b20.run)(transfer, log=log)
    assert any("25.0625 C" in line for line in lines), lines
    assert device.log[:3] == ["reset", "0x33", "reset"], device.log
    decoded = decode(analyser, "ds18b20")
    serial = sum(b << (8 * i) for i, b in enumerate(rom))
    for line in ["ROM command: 0x33 'Read ROM'", "ROM: 0x%016x" % serial, "Data: 0xbe"]:
        assert "onewire_network-1: " + line in decoded, (line, decoded)


class SlowPins(Pins):
    """The host SPI at another clock: half a period of half cycles."""

    def __init__(self, dut, half):
        super().__init__(dut)
        self.half = half

    async def byte(self, out):
        acc = 0
        for b in range(7, -1, -1):
            self.mosi = (out >> b) & 1
            await self.wait(self.half)
            bit = 1 if str(self.dut.uo_out.value)[-1] == "1" else 0
            self.sck = 1
            await self.wait(self.half)
            self.sck = 0
            acc = (acc << 1) | bit
        return acc


# SK6812 datasheet: T0H 0.3, T1H 0.6, T0L 0.9, T1L 0.6 us, each 0.15 us either way
SK6812 = {"T0H": (150, 450), "T1H": (450, 750), "T0L": (750, 1050), "T1L": (450, 750)}


@cocotb.test()
async def test_neopixel(dut):
    """The NeoPixel act with Pico A's SPI at 1.5 MHz, its frames decoded by sigrok and every
    high and low time held to the SK6812's datasheet."""
    await reset(dut)
    analyser = Analyser({4: bit(dut.uo_out, 1)})
    half = 48_000_000 // demo_neopixel.SPI_HZ // 2
    transfer, pause_ms, log, _ = acted(dut, SlowPins(dut, half))
    assert await bridge(demo_neopixel.run)(transfer, pause_ms, log=log)
    decoded = decode(analyser, "neopixel")
    colours = [line.split(": ")[1] for line in decoded if ": #" in line]
    expected = ["#%02x%02x%02x" % p for p in demo_neopixel.PIXELS]
    assert colours == expected + expected[1:] + expected[:1], colours

    # each bit is a high time and the low time after it, the last of a frame excepted
    edges = analyser.levels(4)
    times = {name: [] for name in SK6812}
    for (rise, high), (fall, _), (next_rise, _) in zip(edges[1::2], edges[2::2], edges[3::2]):
        assert high == 1
        width, gap = (fall - rise) / 1000, (next_rise - fall) / 1000
        if gap > 5000:
            continue
        one = width > 500
        times["T1H" if one else "T0H"].append(width)
        times["T1L" if one else "T0L"].append(gap)
    for name, (low, high) in SK6812.items():
        seen = sorted(set(round(t) for t in times[name]))
        cocotb.log.info("%s: %s ns, the SK6812 allows %d to %d", name, seen, low, high)
        assert seen and all(low <= t <= high for t in seen), (name, seen)


@cocotb.test()
async def test_can(dut):
    """The CAN act: armed, then its frames on OUT1 decoded by sigrok as the receiving
    transceiver's R line. OUT1 is dominant until armed and the first SOF comes at least 11
    recessive bits later. Nothing ACKs here; on the bench Pico B does."""
    await reset(dut)
    line = Analyser({6: bit(dut.uo_out, 2)})
    transfer, pause_ms, log, _ = acted(dut)
    await bridge(demo_can.arm)(transfer)
    # the pin lets go a bit after the period, and D is wired only then, so the bench's
    # capture starts on a recessive line
    await ClockCycles(dut.clk, 2 * demo_can.PERIOD)
    analyser = Analyser({5: bit(dut.uo_out, 2), 6: bit(dut.uo_out, 2)})
    assert await bridge(demo_can.run)(transfer, pause_ms, log=log)
    edges = line.levels(6)
    assert edges[0][1] == 0, "dominant from reset"
    recessive, first_sof = edges[1][0], edges[2][0]
    bits = (first_sof - recessive) / (CLOCK_PS * demo_can.PERIOD)
    cocotb.log.info("OUT1 recessive %.1f bits before the first SOF", bits)
    assert bits >= 11
    decoded = decode(analyser, "can")
    ids = [line.partition("Identifier: ")[2] for line in decoded if "Identifier: " in line]
    assert ids == ["%d (0x%x)" % (ident, ident) for ident, _ in demo_can.FRAMES], ids
    assert decoded.count("can-1: ACK slot: NACK") == len(demo_can.FRAMES), decoded
    assert not any("must be" in line or "arning" in line for line in decoded), decoded
