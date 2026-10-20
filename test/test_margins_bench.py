# SPDX-License-Identifier: Apache-2.0
"""demo_margins.py on the RTL as Pico A runs it, judged by demo/margins.py as the bench is,
against models with thresholds of their own: a few points of each part's sweeps either
side of a model's threshold, which the judgement has to find. MARGINS names the JSON
test/python/write_margins.exe writes; VSYS settles in 2 ms, which the model needs no
longer, and the EEPROM's bus guard is a tenth as long."""

import json
import os

import cocotb
from cocotb.task import bridge, resume
from cocotb.triggers import ClockCycles, Timer
from cocotb.utils import get_sim_time

# test_outside puts ../python and ../demo on the path, through test
from test_outside import MS, Ds18b20, Memory, SlowPins, acted, bit, reset, with_crc
import demo_margins
import margins

with open(os.environ["MARGINS"]) as f:
    MARGINS = json.load(f)
REPEATS = 2


def point(part, parameter, cycles):
    for sweep in MARGINS["sweeps"]:
        if sweep["part"] == part and sweep["parameter"] == parameter:
            for p in sweep["points"]:
                if p.get("cycles") == cycles:
                    return sweep, p
    raise KeyError((part, parameter, cycles))


def short(dut):
    """pause_ms at a tenth of a millisecond a millisecond."""
    @resume
    async def pause_ms(n):
        await ClockCycles(dut.clk, n * MS // 10)

    return pause_ms


class Stick:
    """SK6812s on OUT3 as a threshold reads them: a high under SHORT_NS is no bit, over
    ONE_NS a one; a low of LATCH_NS latches, each pixel taking 24 bits and passing the
    rest on. VSYS falls by DROP volts a full channel lit."""

    SHORT_NS = 100
    ONE_NS = 600
    LATCH_NS = 80_000
    DROP = 0.0005
    VSYS = 4.95

    def __init__(self, dut, pixels=8):
        self.signal, self.level = bit(dut.uo_out, 4)
        self.bits = []
        self.shown = [(0, 0, 0)] * pixels
        self.last = (get_sim_time("ns"), self.level())
        cocotb.start_soon(self.run())

    async def run(self):
        while True:
            await self.signal.value_change
            now, level = get_sim_time("ns"), self.level()
            since, was = self.last
            if level == was:
                continue
            width = now - since
            if was == 1 and width >= self.SHORT_NS:
                self.bits.append(1 if width > self.ONE_NS else 0)
            elif was == 0 and width >= self.LATCH_NS:
                self.latch()
            self.last = (now, level)

    def latch(self):
        bits, self.bits = self.bits, []
        for i in range(len(self.shown)):
            mine = bits[24 * i:24 * i + 24]
            if len(mine) < 24:
                break
            g, r, b = (sum(v << (7 - k) for k, v in enumerate(mine[8 * c:8 * c + 8]))
                       for c in range(3))
            self.shown[i] = (r, g, b)

    def vsys(self):
        since, level = self.last
        if level == 0 and get_sim_time("ns") - since >= self.LATCH_NS and self.bits:
            self.latch()
        return self.VSYS - self.DROP * sum(sum(p) for p in self.shown) / 255


async def judged(dut, part, parameter, cycles, run):
    sweep, p = point(part, parameter, cycles)
    out = await bridge(run)(p)
    ok, lines = margins.judge(sweep, out, REPEATS)
    for line in lines:
        cocotb.log.info("%s %s %d: %s", part, parameter, cycles, line)
    return all(ok), out


@cocotb.test()
async def test_sk6812(dut):
    """T0H either side of the model's 600 ns, and the gap either side of its 80 us latch."""
    await reset(dut)
    demo_margins.REFERENCES = 1
    demo_margins.SETTLE_MS = 2
    stick = Stick(dut)
    # Pico A's SPI at the neopixel demo's clock, which the references' frames need, and
    # their pauses as long as the bench's
    half = 48_000_000 // demo_margins.demo_neopixel.SPI_HZ // 2
    transfer, pause_ms, _, _ = acted(dut, SlowPins(dut, half, gap=3))
    host = demo_margins.pe.Host(transfer)

    @resume
    async def vsys():
        return stick.vsys()

    def run(kind):
        return lambda p: demo_margins.sk6812(host, pause_ms, vsys, p, REPEATS, kind == "pair")

    for parameter, cycles, passes, kind in [
        ("T0H", 17, True, "single"), ("T0H", 32, False, "single"),
        ("reset", 4800, True, "pair"), ("reset", 1440, False, "pair"),
    ]:
        ok, out = await judged(dut, "SK6812", parameter, cycles, run(kind))
        assert ok == passes, (parameter, cycles, out)
        assert not out["faults"], out


@cocotb.test()
async def test_eeprom(dut):
    """The library's rate and the least 1/fSCL the kernel takes: cocotbext-i2c's memory
    has no timing of its own, so both read the page."""
    await reset(dut)
    memory = Memory(sda=dut.sda, sda_o=dut.sda_o, scl=dut.scl, scl_o=dut.scl_o,
                    addr=demo_margins.EEPROM_DEVICE, size=32768)
    page = bytes((7 + 13 * i) & 0xFF for i in range(demo_margins.EEPROM_BYTES))
    memory.write_mem(demo_margins.EEPROM_PAGE, page)
    transfer, pause_ms, _, _ = acted(dut)
    host = demo_margins.pe.Host(transfer)
    sweep, _ = point("24LC256", "1/fSCL", 192)
    least = min(p["cycles"] for p in sweep["points"] if "refused" not in p)
    for cycles in (192, least):
        ok, out = await judged(
            dut, "24LC256", "1/fSCL", cycles,
            lambda p: demo_margins.eeprom(host, short(dut), p, p["model_words"], REPEATS))
        assert ok, out
        assert out["before"] == list(page) == out["after"], out


class WritableDs18b20(Ds18b20):
    """test_outside's model, which also takes WRITE SCRATCHPAD's three bytes."""

    def __init__(self, dut, rom, scratchpad):
        super().__init__(dut, rom, scratchpad)
        self.writing = 0

    def take(self, value):
        if not self.writing:
            super().take(value)
            if self.log and self.log[-1] == "0x4e":
                self.writing = 3
            return
        self.received.append(value)
        if len(self.received) < 8:
            return
        byte = sum(b << i for i, b in enumerate(self.received))
        self.received = []
        index = 5 - self.writing
        self.writing -= 1
        self.scratchpad[index] = byte if index < 4 else (byte & 0x60) | 0x1F
        self.scratchpad[8] = with_crc(self.scratchpad[:8])[8]


@cocotb.test()
async def test_ds18b20(dut):
    """Either side of the model's own thresholds: a reset of 480 us, a presence 30 to
    150 us after it, a write's low read as a zero from 15 us, a zero held 30 us."""
    await reset(dut)
    rom = with_crc([0x28, 0xD1, 0xC3, 0x5A, 0x0B, 0x00, 0x00])
    pad = with_crc([0x91, 0x01, 0x4B, 0x46, 0x7F, 0xFF, 0x0C, 0x10])
    device = WritableDs18b20(dut, rom, list(pad))
    transfer, _, _, _ = acted(dut)
    host = demo_margins.pe.Host(transfer)
    us = 48
    # each point simulates some 50 ms, so the library's timing once and a failure a kind
    for parameter, cycles, passes in [
        ("tRSTL", 504 * us, True), ("tRSTL", 400 * us, False),
        ("presence sample", 20 * us, False), ("tLOW0", 10 * us, False),
        ("read sample", 40 * us, False),
    ]:
        sweep, _ = point("DS18B20", parameter, cycles)
        ok, out = await judged(
            dut, "DS18B20", parameter, cycles,
            lambda p: demo_margins.ds18b20(host, p, margins.kind(sweep), REPEATS))
        assert ok == passes, (parameter, cycles, out)
        assert out["before"][1] == rom == out["after"][1], out
        assert out["after"][2][2:5] == pad[2:5], out
    cocotb.log.info("model log: %s", device.log[-12:])
    await Timer(1, unit="us")
