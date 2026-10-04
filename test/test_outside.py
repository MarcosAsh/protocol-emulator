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
from cocotb.triggers import ClockCycles, FallingEdge, First, RisingEdge, Timer
from cocotb.utils import get_sim_time
from cocotbext.i2c import I2cMemory

from test import Pins
import demo_can
import demo_can_node
import demo_ds18b20
import demo_eeprom
import demo_flash
import demo_neopixel
import demo_referee
import demo_start_hold

sys.path.insert(0, "../demo")
import sigrok
import start_hold

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


def decode(analyser, act, args=None):
    """What sigrok reads, with the act's arguments unless given others."""
    path = "outside_%s.sr" % act
    analyser.write(path)
    args = args or decoders()[act]
    # sigrok's decoders run in the system's Python, not the simulator's
    env = {k: v for k, v in os.environ.items() if not k.startswith("PYTHON")}
    run = subprocess.run(
        ["sigrok-cli", "-i", path] + args, capture_output=True, text=True, env=env
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


def in_mode(args, mode):
    """sigrok arguments with the spi decoder in mode."""
    return [a.replace("spi:", "spi:cpol=%d:cpha=%d:" % (mode >> 1, mode & 1), 1) for a in args]


@cocotb.test()
@cocotb.parametrize(mode=[0, 3])
async def test_flash(dut, mode):
    """The flash act's commands against picosoc's spiflash.v, which models only release
    from power down and the reads: so the wake and a read of a page it was loaded with, in
    mode 0 as the act runs and in mode 3, the flash's other mode. JEDEC ID, status, program
    and erase it does not have, and they are scripted only."""
    await reset(dut)
    page = [(0x5A + 11 * i) & 0xFF for i in range(demo_flash.PAGE)]
    for i, value in enumerate(page):
        dut.flash.memory[demo_flash.SECTOR + i].value = value
    # CS is low from reset until the firmware starts, as on the bench
    dut.flash_wired.value = 1
    analyser = Analyser({
        4: bit(dut.uo_out, 1), 5: bit(dut.uo_out, 2), 6: bit(dut.miso), 7: bit(dut.uo_out, 3),
    })
    transfer, pause_ms, log, _ = acted(dut)

    def act():
        host = demo_flash.pe.Host(transfer)
        demo_flash.start(host, getattr(demo_flash.bench_firmware, "SPI_CS_MODE%d" % mode))
        flash = demo_flash.Flash(host, pause_ms)
        flash.wake()
        back = flash.read(demo_flash.SECTOR, demo_flash.PAGE)
        log("read 0x%06x: %s ..." % (demo_flash.SECTOR, demo_flash.bench.hexs(back[:8])))
        return back, demo_flash.bench.faults(host)

    back, faults = await bridge(act)()
    lines = decode(analyser, "flash", in_mode(decoders()["flash"], mode))
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
        self.resets = []
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
                self.resets.append(low)
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
    # 84 units of 6 us, which leaves 480 behind by more than the clock's rounding
    cocotb.log.info("resets low for %s us", sorted(set(round(r, 1) for r in device.resets)))
    assert min(device.resets) >= 500
    decoded = decode(analyser, "ds18b20")
    serial = sum(b << (8 * i) for i, b in enumerate(rom))
    for line in ["ROM command: 0x33 'Read ROM'", "ROM: 0x%016x" % serial, "Data: 0xbe"]:
        assert "onewire_network-1: " + line in decoded, (line, decoded)


class SlowPins(Pins):
    """The host SPI at another clock, half a period of half cycles, with gap half periods
    between bytes: the RP2040's SPI in mode 0 pauses a bit and a half after each."""

    def __init__(self, dut, half, gap):
        super().__init__(dut)
        self.half = half
        self.gap = gap

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
        await self.wait(self.gap * self.half)
        return acc


# SK6812 datasheet: T0H 0.3, T1H 0.6, T0L 0.9, T1L 0.6 us, each 0.15 us either way
SK6812 = {"T0H": (150, 450), "T1H": (450, 750), "T0L": (750, 1050), "T1L": (450, 750)}


async def neopixel(dut, gap):
    """The NeoPixel act with Pico A's SPI at its clock and gap half periods between bytes:
    every pixel has to chain, so sigrok sees each frame whole, and nothing faults."""
    await reset(dut)
    analyser = Analyser({4: bit(dut.uo_out, 1)})
    half = 48_000_000 // demo_neopixel.SPI_HZ // 2
    transfer, pause_ms, log, _ = acted(dut, SlowPins(dut, half, gap))
    # engine 0's tx fifo, which drops a push when full without a fault
    level = dut.user_project.core.top.engines.engine_0.tx.level
    most = [0]

    async def watch():
        while True:
            await level.value_change
            most[0] = max(most[0], int(level.value))

    watcher = cocotb.start_soon(watch())
    assert await bridge(demo_neopixel.run)(transfer, pause_ms, log=log)
    watcher.cancel()
    cocotb.log.info("most words waiting: %d of 8", most[0])
    assert most[0] < 8
    decoded = decode(analyser, "neopixel")
    colours = [line.split(": ")[1] for line in decoded if ": #" in line]
    expected = ["#%02x%02x%02x" % p for p in demo_neopixel.PIXELS]
    assert colours == expected + expected[1:] + expected[:1], colours
    assert decoded.count("rgb_led_ws281x-1: RESET") == 2, decoded
    return analyser


@cocotb.test()
async def test_neopixel_back_to_back(dut):
    """The fifo at its fullest: the bytes with no pause between them."""
    await neopixel(dut, gap=0)


@cocotb.test()
async def test_neopixel(dut):
    """The words at their latest, a byte and its pause 9.5 SPI clocks, and every high and low
    time held to the SK6812's datasheet."""
    analyser = await neopixel(dut, gap=3)

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


# can2040's own lines, SOF to the CRC delimiter, for demo/can_node.c's replies, as
# demo/can_node/golden.c prints them and test/test_can_node.ml checks them
REPLY_LINES = [
    "0000101000010000011100000100100000101000001001111100011110011001",
    "00001010001010000101010011001010101",
    "0110101100010001000111110111110111110111110111110111110111110111110111110111110111110111110111110010101011011101",
    "000001000001000001001000001000001000001000100101101100011",
]
# Pico B's bit, a crystal's 500 kbit/s, where the chip's is 96 of its cycles
CAN_BIT_PS = 2_000_000


def crc15(bits):
    crc = 0
    for bit in bits:
        top = ((crc >> 14) & 1) ^ bit
        crc = (crc << 1) & 0x7FFF
        if top:
            crc ^= 0x4599
    return crc


class PicoB:
    """Pico B as demo/can_node.c runs can2040, on its own transceiver: it ACKs each frame
    whose CRC holds, and after a frame with ID request, delay_ms on, sends replies, can2040's
    own lines, gap_ms apart, each again until ACKed. A model of ours: it samples each bit
    three quarters in from the SOF's fall, with no resynchronising, which the simulator's
    steady clocks allow."""

    def __init__(self, dut, request, replies, delay_ms, gap_ms):
        self.dut = dut
        self.request = request
        self.replies = replies
        self.delay_ms = delay_ms
        self.gap_ms = gap_ms
        self.received = []
        self.attempts = []
        self.pending = []
        self.due = 0
        cocotb.start_soon(self.run())

    def level(self):
        return bit(self.dut.can_rx)[1]()

    async def until(self, ps):
        now = get_sim_time("ps")
        if ps > now:
            await Timer(ps - now, unit="ps")

    async def idle(self, bits):
        """Until the bus has been recessive for that many bits, a quarter bit at a time."""
        quarters = 0
        while quarters < 4 * bits:
            await Timer(CAN_BIT_PS // 4, unit="ps")
            quarters = quarters + 1 if self.level() else 0

    async def receive(self, sof):
        """The frame whose SOF fell at sof: (id, rtr, dlc, data), ACKed if its CRC holds, or
        None for a stuff, form or CRC error."""
        raw, bits = [], []
        last, run, need = None, 0, None
        while need is None or len(bits) < need or run == 5:
            await self.until(sof + (4 * len(raw) + 3) * CAN_BIT_PS // 4)
            level = self.level()
            raw.append(level)
            if run == 5:
                if level == last:
                    return None
                last, run = level, 1
                continue
            run, last = (run + 1 if level == last else 1), level
            bits.append(level)
            if len(bits) == 19:
                rtr, dlc = bits[12], int("".join(map(str, bits[15:19])), 2)
                need = 19 + (0 if rtr else 8 * min(dlc, 8)) + 15
        await self.until(sof + (4 * len(raw) + 3) * CAN_BIT_PS // 4)
        crc = int("".join(map(str, bits[-15:])), 2)
        if not self.level() or crc != crc15(bits[:-15]):
            return None
        await self.until(sof + (len(raw) + 1) * CAN_BIT_PS)
        self.dut.can_o.value = 0
        await Timer(CAN_BIT_PS, unit="ps")
        self.dut.can_o.value = 1
        value = lambda b: int("".join(map(str, b)), 2) if b else 0
        data = [value(bits[19 + 8 * i:27 + 8 * i]) for i in range((need - 34) // 8)]
        return value(bits[1:12]), bits[12], value(bits[15:19]), data

    async def send(self, line):
        """line once, after an idle bus, and whether a receiver ACKed it."""
        await self.idle(11)
        for level in line:
            self.dut.can_o.value = int(level)
            await Timer(CAN_BIT_PS, unit="ps")
        self.dut.can_o.value = 1
        await Timer(3 * CAN_BIT_PS // 4, unit="ps")
        acked = not self.level()
        await Timer(CAN_BIT_PS // 4, unit="ps")
        return acked

    async def run(self):
        await self.idle(11)
        while True:
            if self.pending and get_sim_time("ps") >= self.due:
                tries = 1
                while not await self.send(self.pending[0]):
                    tries += 1
                self.attempts.append(tries)
                self.pending.pop(0)
                self.due = get_sim_time("ps") + self.gap_ms * 10**9
                continue
            fell = FallingEdge(self.dut.can_rx)
            if await First(fell, Timer(CAN_BIT_PS, unit="ps")) is not fell:
                continue
            frame = await self.receive(get_sim_time("ps"))
            await self.idle(7)
            if frame is None:
                continue
            self.received.append(frame)
            if frame[0] == self.request and not frame[1] and not self.pending:
                self.pending = list(self.replies)
                self.due = get_sim_time("ps") + self.delay_ms * 10**9


def can_ids(decoded):
    return [line.partition("Identifier: ")[2] for line in decoded if "Identifier: " in line]


@cocotb.test()
async def test_can_node(dut):
    """The can_node act against a model of Pico B: armed, the sender's four frames, each
    ACKed and the ACK read back, the last asking for Pico B's four, which the receiver ACKs.
    sigrok decodes both ways on module A's R."""
    await reset(dut)
    pico_b = PicoB(dut, demo_can_node.REQUEST, REPLY_LINES, delay_ms=5, gap_ms=2)
    transfer, pause_ms, log, _ = acted(dut)
    await bridge(demo_can_node.arm)(transfer, log=log)
    await ClockCycles(dut.clk, 2 * demo_can_node.PERIOD)
    analyser = Analyser({6: bit(dut.can_rx)})
    assert await bridge(demo_can_node.run)(transfer, pause_ms, log=log)
    sent = [(ident, 0, len(data), data) for ident, data in demo_can_node.FRAMES]
    assert pico_b.received == sent, pico_b.received
    cocotb.log.info("Pico B's attempts at each reply: %s", pico_b.attempts)
    assert pico_b.attempts == [1] * len(REPLY_LINES)
    decoded = decode(analyser, "can_node")
    frames = sent + demo_can_node.REPLIES
    assert can_ids(decoded) == ["%d (0x%x)" % (f[0], f[0]) for f in frames], decoded
    # sigrok 0.5.3 reads a remote frame's DLC of data bytes, test/sigrok_scenarios.ml's
    # can_remote, so its CRC and ACK slot are not where it looks
    data_frames = [f for f in frames if not f[1]]
    assert decoded.count("can-1: ACK slot: ACK") == len(data_frames), decoded
    assert not any("must be" in line or "arning" in line for line in decoded), decoded


def two_engines(transfer, pause_ms):
    """The receiver in engine 1 with its ACK on OUT2, and the sender in engine 0, which has
    its period and leaves OUT1 recessive; the receiver hears eleven idle bits after."""
    host = demo_can_node.pe.Host(transfer)
    bench = demo_can_node.bench
    firmware = demo_can_node.bench_firmware
    config = dict(firmware.CAN_RECEIVER["config"], set_base=7, out_base=7)
    bench.load(host, dict(firmware.CAN_RECEIVER, config=config), engine=1)
    bench.load(host, firmware.CAN_SENDER, engine=0)
    host.select(1)
    host.start()
    host.select(0)
    host.start()
    host.push([demo_can_node.PERIOD])
    pause_ms(1)


def send(transfer, pause_ms, log, frames):
    """frames from engine 0, the ACKs it read, what engine 1 heard, and their faults."""
    host = demo_can_node.pe.Host(transfer)
    bench = demo_can_node.bench
    acks, words = [], []
    for ident, data in frames:
        host.push(demo_can.words(ident, data))
        pause_ms(demo_can_node.FRAME_MS)
        acks += host.pop(bench.rx_level(host))
        # a long frame is seven words, so each is read before the next
        host.select(1)
        words += host.pop(bench.rx_level(host))
        host.select(0)
    heard, _ = demo_can_node.frames(words)
    log("engine 0 read %s, engine 1 heard %s" % (acks, heard))
    faults = bench.faults(host)
    host.select(1)
    faults |= bench.faults(host)
    host.select(0)
    return acks, heard, faults


def stop_engine_1(transfer):
    """Its OUT2 holds the recessive level it left."""
    host = demo_can_node.pe.Host(transfer)
    host.select(1)
    host.stop()
    host.select(0)


@cocotb.test()
async def test_can_chip_to_chip(dut):
    """The chip's sender in engine 0 on OUT1 and its receiver in engine 1 on OUT2, through
    two transceivers on one bus: engine 1 takes and ACKs each frame and engine 0 reads the
    ACK, then with engine 1 stopped reads none. sigrok decodes the bus."""
    await reset(dut)
    dut.can_out2.value = 1
    transfer, pause_ms, log, _ = acted(dut)
    await bridge(two_engines)(transfer, pause_ms)
    analyser = Analyser({6: bit(dut.can_rx)})
    frames = demo_can.FRAMES[:2]
    acks, heard, faults = await bridge(send)(transfer, pause_ms, log, frames)
    assert acks == [0] * len(frames)
    assert heard == [(ident, 0, len(data), data) for ident, data in frames], heard
    assert faults == 0
    await bridge(stop_engine_1)(transfer)
    acks, heard, faults = await bridge(send)(transfer, pause_ms, log, frames)
    assert acks == [1] * len(frames)
    assert heard == [] and faults == 0
    decoded = decode(analyser, "can_node")
    idents = [ident for ident, _ in frames] * 2
    assert can_ids(decoded) == ["%d (0x%x)" % (i, i) for i in idents], decoded
    slots = [line for line in decoded if "ACK slot" in line]
    assert slots == ["can-1: ACK slot: ACK"] * len(frames) + ["can-1: ACK slot: NACK"] * len(
        frames
    ), slots


# Standard-mode at 100 kHz: SCL low and high 5 us each, SDA moving a quarter into the low
HALF_PS = 5_000_000
QUARTER_PS = 1_250_000
READS = 3


async def i2c_reads(dut, hold_ps):
    """READS reads as a master that holds each START hold_ps: START, 0x50 to write, a
    repeated START, 0x50 to read, STOP. Nothing answers, so both addresses are NACKed."""

    async def wait(ps):
        await Timer(ps, unit="ps")

    async def clock(sda):
        await wait(QUARTER_PS)
        dut.sda_o.value = sda
        await wait(HALF_PS - QUARTER_PS)
        dut.scl_o.value = 1
        await wait(HALF_PS)

    async def start():
        dut.sda_o.value = 0
        await wait(hold_ps)
        dut.scl_o.value = 0

    async def address(byte):
        for b in [(byte >> i) & 1 for i in range(7, -1, -1)] + [1]:
            await clock(b)
            dut.scl_o.value = 0

    for _ in range(READS):
        await start()
        await address(0xA0)
        await clock(1)
        await start()
        await address(0xA1)
        await clock(0)
        dut.sda_o.value = 1
        await wait(2 * HALF_PS)


async def start_holds(dut, hold_ps):
    """The start hold act against a master holding every START hold_ps, with Pico A's SPI
    at the NeoPixel act's clock: the chip's holds each within a cycle of it, the analyser's
    within a sample, nothing driven on the bus, and the stick lit with the host's verdict,
    which is returned."""
    await reset(dut)
    analyser = Analyser({4: bit(dut.uo_out, 1), 6: bit(dut.sda), 7: bit(dut.scl)})
    driven = []

    async def watch():
        while True:
            await dut.uio_oe.value_change
            if int(dut.uio_oe.value) & 0b1100:
                driven.append(get_sim_time("ns"))

    watcher = cocotb.start_soon(watch())
    half = 48_000_000 // demo_neopixel.SPI_HZ // 2
    transfer, pause_ms, log, _ = acted(dut, SlowPins(dut, half, 3))
    host = demo_start_hold.pe.Host(transfer)
    await bridge(demo_start_hold.arm)(host)
    master = cocotb.start_soon(i2c_reads(dut, hold_ps))
    holds = await bridge(demo_start_hold.collect)(host, pause_ms, 2 * READS, 5)
    await master
    faults = await bridge(demo_start_hold.bench.faults)(host)
    watcher.cancel()
    verdict = demo_start_hold.judge(holds, log)
    cycles = hold_ps / CLOCK_PS
    assert len(holds) == 2 * READS, holds
    assert all(abs(h - cycles) <= 1 for h in holds), (holds, cycles)
    assert faults == 0
    assert not driven, "the chip drove the bus at %s ns" % driven[:3]
    decoded = decode(analyser, "start_hold")
    assert decoded.count("i2c-1: Start") == READS, decoded
    assert decoded.count("i2c-1: Start repeat") == READS, decoded
    seen, sample = start_hold.holds("outside_start_hold.sr")
    cocotb.log.info("analyser: %s ns, each +-%.1f", sorted(set(round(h) for h in seen)), sample)
    assert len(seen) == 2 * READS
    assert all(abs(h - hold_ps / 1000) <= sample for h in seen), seen
    await bridge(demo_start_hold.light)(host, verdict, pause_ms)
    colours = [line.split(": ")[1] for line in decode(analyser, "neopixel") if ": #" in line]
    colour = demo_start_hold.GREEN if verdict else demo_start_hold.RED
    assert colours == ["#%02x%02x%02x" % colour] * 8, colours
    return verdict


@cocotb.test()
async def test_start_hold_pio_i2c(dut):
    """pio/i2c's START: 10 PIO cycles at 125 MHz over 39.0625, 3.125 us, which the host
    has to FAIL against 4.0 us."""
    assert await start_holds(dut, 3_125_000) is False


@cocotb.test()
async def test_start_hold_hardware_i2c(dut):
    """The RP2040 I2C block's START, taken as its SCL high time, HCNT + SPKLEN + 7 = 553
    cycles at 125 MHz, 4.424 us, which the host has to PASS."""
    assert await start_holds(dut, 4_424_000) is True


async def refereed(dut, act, **kwargs):
    """act(referee) as Pico A runs it, the SPI clock switched as the script switches it:
    act's result, each cheat's start bit fall on wire 20 and period, engine 1's irq rises,
    the analyser on OUT0 and the log. Wire 20 and the irq never reach a pad, so the RTL's."""
    await reset(dut)
    analyser = Analyser({4: bit(dut.uo_out, 1)})
    pins = SlowPins(dut, 48_000_000 // demo_referee.HOST_HZ // 2, 3)
    _, pause_ms, log, lines = acted(dut, pins)
    engines = dut.user_project.core.top.engines
    check = demo_referee.check

    def cycle():
        return int(get_sim_time("ps")) // CLOCK_PS

    def rate(hz):
        pins.half = 48_000_000 // hz // 2

    # (cycle, period) of each restart's push to engine 0, whose first word is the period
    pushes = []
    periods = {check.PERIOD + slip for slip in (-2, -1, 0, 1, 2)}

    @resume
    async def transfer(data):
        if data[0] == 0x80 | demo_referee.pe.TX and (data[1] << 8 | data[2]) in periods:
            pushes.append((cycle(), data[1] << 8 | data[2]))
        return await pins.transfer(data)

    wire, irqs = [(0, 0)], []

    async def watch_wire():
        while True:
            await engines.engine_0.pin_out.value_change
            level = (int(engines.engine_0.pin_out.value) >> check.WIRE) & 1
            if level != wire[-1][1]:
                wire.append((cycle(), level))

    async def watch_irq():
        while True:
            await engines.engine_1.irq.value_change
            if int(engines.engine_1.irq.value):
                irqs.append(cycle())

    watchers = [cocotb.start_soon(watch_wire()), cocotb.start_soon(watch_irq())]
    referee = await bridge(demo_referee.Referee)(transfer, rate, pause_ms, log, **kwargs)
    ok = await bridge(act)(referee)
    for watcher in watchers:
        watcher.cancel()
    cheats = [
        (next(at for at, level in wire if at > pushed and level == 0), period)
        for pushed, period in pushes
        if period != check.PERIOD
    ]
    return ok, cheats, irqs, analyser, lines


def assert_refereed(cheats, irqs, analyser, lines, slips, frames):
    """One alarm a cheat and none on the honest frames, each six cycles after the write the
    rows name shows on wire 20, the stick showing frames after the catches, no faults."""
    check = demo_referee.check
    period = check.PERIOD
    assert [p - period for _, p in cheats] == slips, cheats
    assert len(irqs) == len(cheats), (irqs, cheats)
    # the frame test_self_check.ml prints
    edges = [bit * period for bit in range(1, 10)] + [10 * period + 6]
    for (start, glitch), irq in zip(cheats, irqs):
        _, at = check.caught_by(edges, check.GLITCH_BYTE, glitch)
        cocotb.log.info("period %d: irq %d after the start bit, the rows' %d", glitch,
                        irq - start, at)
        assert irq - start == at + 6, (glitch, irq - start, at)
    decoded = decode(analyser, "referee")
    colours = [line.split(": ")[1] for line in decoded if ": #" in line]
    assert colours == [c for frame in frames for c in frame], colours
    assert decoded.count("rgb_led_ws281x-1: RESET") == len(frames), decoded
    assert "faults [0, 0]" in lines, lines


def lit(colour, n):
    return [colour] * n + ["#000000"] * (8 - n)


RED = "#200000"
GREEN = "#002000"


@cocotb.test()
async def test_referee_auto(dut):
    """The referee's auto mode, a cycle and two late and early: each cheat caught at the
    check the rows name, the stick red a pixel a catch and swept green after 21 honest
    frames, the checker re-armed and quiet on the honest frames between."""

    def act(referee):
        return demo_referee.auto(referee, cheats=4, frames=7, linger_ms=0)

    ok, cheats, irqs, analyser, lines = await refereed(
        dut, act, sweep_every=21, sweep_ms=demo_neopixel.LATCH_MS)
    assert ok
    assert "slipped past: 0 of 4" in lines, lines
    sweep = [lit(GREEN, n) for n in range(1, 9)]
    frames = [lit(RED, 1), lit(RED, 2)] + sweep + [lit(RED, 2), lit(RED, 3), lit(RED, 4)]
    assert_refereed(cheats, irqs, analyser, lines, [1, -1, 2, -2], frames)


@cocotb.test()
async def test_referee_play(dut):
    """The game with BOOTSEL pressed on the second and fourth polls: a cycle late, then a
    cycle early, each caught, with honest frames before each, and the second held to end."""
    reads = iter([False, True, False, True, True, True])

    @resume
    async def poll():
        await ClockCycles(dut.clk, 10)

    def act(referee):
        pressed = demo_referee.button(lambda: next(reads), hold=3)
        ok = demo_referee.play(referee, pressed, poll, restart_every=1)
        return not referee.faults() and ok

    ok, cheats, irqs, analyser, lines = await refereed(dut, act)
    assert ok
    assert "you 0, referee 2" in lines, lines
    assert_refereed(cheats, irqs, analyser, lines, [1, -1], [lit(RED, 1), lit(RED, 2)])
