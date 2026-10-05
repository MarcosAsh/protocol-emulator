# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

import random
import sys

sys.path.insert(0, "../python")
from protocol_emulator import PROGRAM_WORDS, CHECK_STATUS, CONFIG_FIELDS, CONTROL, DATA, DATA_ADDR, DEFAULT_CONFIG, PROGRAM_ADDR, PROGRAM as PROGRAM_REG, REJECT_PC, REJECT_REASON, STATUS, TX, Host, Refused, certify_writes, config_writes
from certified_hex import assumptions, certificate

HALF = 4


def assembled(name):
    """The words `make firmware` assembles from the .asm of the same name."""
    with open(f"{name}.hex") as f:
        return [int(line, 16) for line in f]


def padded(words):
    """The whole program memory, zeros after the program, as Host.load writes it: the
    chip's check reads every word, and memory nobody wrote holds anything."""
    return list(words) + [0] * (PROGRAM_WORDS - len(words))


PROGRAM = assembled("uart_tx")


class Pins:
    def __init__(self, dut):
        self.dut = dut
        self.sck = 0
        self.mosi = 0
        self.cs_n = 1

    def drive(self):
        self.dut.ui_in.value = (self.cs_n << 2) | (self.mosi << 1) | self.sck

    async def wait(self, n):
        self.drive()
        await ClockCycles(self.dut.clk, n)

    async def byte(self, out):
        acc = 0
        for b in range(7, -1, -1):
            self.mosi = (out >> b) & 1
            await self.wait(HALF)
            # MISO alone: the other outputs may not have been driven yet
            bit = 1 if str(self.dut.uo_out.value)[-1] == "1" else 0
            self.sck = 1
            await self.wait(HALF)
            self.sck = 0
            acc = (acc << 1) | bit
        return acc

    async def transfer(self, data):
        self.cs_n = 0
        await self.wait(HALF)
        replies = [await self.byte(b) for b in data]
        await self.wait(HALF)
        self.cs_n = 1
        await self.wait(3)
        return replies


class AsyncHost(Host):
    """The library is synchronous; under cocotb every call becomes an await."""

    async def write(self, reg, words):
        data = [0x80 | reg]
        for w in words:
            data += [(w >> 8) & 0xFF, w & 0xFF]
        await self.transfer(data)

    async def read(self, reg, count=1):
        reply = (await self.transfer([reg] + [0] * (2 * count)))[1:]
        return [(reply[i] << 8) | reply[i + 1] for i in range(0, 2 * count, 2)]

    async def certify(self, certificate, base=0, loaded=None, single_edge=False):
        for reg, words in certify_writes(certificate, base, loaded, single_edge):
            await self.write(reg, words)
        status = (await self.read(CHECK_STATUS))[0]
        while status & 1:
            status = (await self.read(CHECK_STATUS))[0]
        if not status & 4:
            raise Refused(status, (await self.read(REJECT_PC))[0], (await self.read(REJECT_REASON))[0])

    async def certify_firmware(self, name):
        """The certificate firmware.mk wrote for name.asm, under its assumptions."""
        await self.certify(certificate(name), **assumptions(name))


def decode_uart(levels, period):
    frames = []
    i = 0
    while i + 10 * period <= len(levels):
        if levels[i] == 0 and (i == 0 or levels[i - 1] == 1):
            byte = 0
            for b in range(8):
                byte |= levels[i + (b + 1) * period + period // 2] << b
            frames.append(byte)
            i += 10 * period
        else:
            i += 1
    return frames


async def reset(dut):
    clock = Clock(dut.clk, 20, unit="ns")
    cocotb.start_soon(clock.start())
    dut.ena.value = 1
    dut.ui_in.value = 0b100
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)
    assert int(dut.uio_oe.value) == 0


@cocotb.test()
async def test_uart_over_spi(dut):
    await reset(dut)

    host = AsyncHost(Pins(dut).transfer)
    for reg, word in config_writes(DEFAULT_CONFIG):
        await host.write(reg, [word])
    await host.write(PROGRAM_ADDR, [0])
    await host.write(PROGRAM_REG, padded(PROGRAM))
    await host.certify_firmware("uart_tx")
    await host.write(TX, [0x55, 0xA3])
    await host.write(CONTROL, [1])

    levels = []
    for _ in range(400):
        await ClockCycles(dut.clk, 1)
        levels.append((int(dut.uo_out.value) >> 1) & 1)
    assert decode_uart(levels, 16) == [0x55, 0xA3], levels
    assert (await host.read(STATUS))[0] == 0


@cocotb.test()
async def test_fractional_period(dut):
    """115200 baud at 48 MHz: 416 and 43691/65536 cycles a bit, as the OCaml model gives.

    The start bit is a whole period; the fraction carries a cycle into two bits in three.
    """
    await reset(dut)

    host = AsyncHost(Pins(dut).transfer)
    config = dict(DEFAULT_CONFIG, period_fraction=43691)
    for reg, word in config_writes(config):
        await host.write(reg, [word])
    await host.write(PROGRAM_ADDR, [0])
    await host.write(PROGRAM_REG, padded(assembled("uart_tx_host_rate")))
    await host.certify_firmware("uart_tx_host_rate")
    await host.write(TX, [416, 0x55])
    await host.write(CONTROL, [1])

    edges = []
    previous = 0
    for cycle in range(12 * 417):
        await ClockCycles(dut.clk, 1)
        level = (int(dut.uo_out.value) >> 1) & 1
        if level != previous:
            edges.append(cycle)
        previous = level
    # the line going idle, then the start bit and the eight data bits of 0x55
    lengths = [b - a for a, b in zip(edges[1:], edges[2:])]
    assert lengths == [416, 416, 417, 417, 416, 417, 417, 416, 417], lengths
    assert (await host.read(STATUS))[0] == 0


@cocotb.test()
async def test_data_memory(dut):
    """The host fills the data memory and the program streams it out with autopull."""
    await reset(dut)

    host = AsyncHost(Pins(dut).transfer)
    config = dict(DEFAULT_CONFIG, out_base=12, out_count=8, autopull=1, autopull_data=1)
    for reg, word in config_writes(config):
        await host.write(reg, [word])
    await host.write(PROGRAM_ADDR, [0])
    await host.write(PROGRAM_REG, padded(assembled("data_stream")))
    await host.certify_firmware("data_stream")
    await host.write(DATA_ADDR, [0])
    await host.write(DATA, [0x2211, 0x4433, 0x6655, 0x8877])
    assert (await host.read(DATA_ADDR))[0] == 4, "the address counts the words written"
    await host.write(CONTROL, [1])

    # a byte every six cycles; past the four words written the memory holds nothing
    shown = []
    for _ in range(100):
        if len(shown) == 8:
            break
        await ClockCycles(dut.clk, 1)
        byte = int(dut.uio_out.value)
        if not shown or shown[-1] != byte:
            shown.append(byte)
    assert shown == [0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88], shown
    assert (await host.read(STATUS))[0] & 0x3D == 0, "running, no fault"


WRAPPED_LOOP = assembled("wrapped_loop")


@cocotb.test()
async def test_wrapped_loop(dut):
    await reset(dut)

    host = AsyncHost(Pins(dut).transfer)
    config = dict(DEFAULT_CONFIG, in_base=5, wrap_bottom=3, wrap_top=4)
    for reg, word in config_writes(config):
        await host.write(reg, [word])
    await host.write(PROGRAM_ADDR, [0])
    await host.write(PROGRAM_REG, padded(WRAPPED_LOOP))
    await host.certify_firmware("wrapped_loop")
    await host.write(CONTROL, [1])

    await ClockCycles(dut.clk, 20)
    levels = []
    for _ in range(40):
        await ClockCycles(dut.clk, 1)
        levels.append((int(dut.uo_out.value) >> 1) & 1)
    assert levels in ([0, 0, 1, 1] * 10, [0, 1, 1, 0] * 10, [1, 1, 0, 0] * 10, [1, 0, 0, 1] * 10), levels
    assert (await host.read(STATUS))[0] == 0


def predicate_settings(name):
    """What `generate.exe predicate -settings` wrote beside the watch: the config, the
    host budget if any, and the certified window."""
    with open(f"{name}.settings") as f:
        return {key: int(value) for key, value in (line.split() for line in f)}


async def load_watch(host, name):
    settings = predicate_settings(name)
    # every field from the settings, so a missing one fails rather than falls back
    config = {k: settings[k] for k in CONFIG_FIELDS if k}
    for reg, word in config_writes(config):
        await host.write(reg, [word])
    await host.write(PROGRAM_ADDR, [0])
    await host.write(PROGRAM_REG, padded(assembled(name)))
    await host.certify_firmware(name)
    if "budget_from_host" in settings:
        await host.write(TX, [settings["budget_from_host"]])
    await host.write(CONTROL, [1])
    return settings


# The pads add the two synchroniser flops and the pin register to a certified latency,
# which runs from the core's first sample of the event to the verdict's issue.
PAD_DELAY = 3


@cocotb.test()
async def test_i2c_start_watch(dut):
    """Every SDA fall while SCL is high pulses OUT0 a fixed 13 cycles later, and nothing else."""
    await reset(dut)

    host = AsyncHost(Pins(dut).transfer)
    settings = await load_watch(host, "i2c_start_watch")
    assert settings["jitter"] == 0

    # (sda, scl, cycles): a start, a byte's worth of data changes while SCL is low, a
    # repeated start, a stop, and an SDA fall while SCL is low
    bit = [(0, 0, 12), (0, 1, 12), (1, 1, 12), (1, 0, 12)]
    waveform = [(1, 1, 30), (0, 1, 30), (0, 0, 20)] + bit * 4
    waveform += [(1, 0, 12), (1, 1, 30), (0, 1, 30), (0, 0, 20), (0, 1, 20), (1, 1, 30)]
    waveform += [(1, 0, 20), (0, 0, 20), (1, 0, 20), (1, 1, 40)]
    starts, verdicts = [], []
    cycle, sda, scl, previous = 0, 1, 1, 0
    for next_sda, next_scl, cycles in waveform:
        if sda == 1 and next_sda == 0 and next_scl == 1:
            starts.append(cycle)
        sda, scl = next_sda, next_scl
        for _ in range(cycles):
            dut.ui_in.value = 0b100 | (sda << 3) | (scl << 4)
            await ClockCycles(dut.clk, 1)
            level = (int(dut.uo_out.value) >> 1) & 1
            if level and not previous:
                verdicts.append(cycle)
            previous = level
            cycle += 1
    assert len(starts) == 2
    pad_latency = settings["latency"] + PAD_DELAY
    assert [v - s for s, v in zip(starts, verdicts)] == [pad_latency] * 2, (starts, verdicts)
    assert len(verdicts) == 2, verdicts
    assert (await host.read(STATUS))[0] & 0x3D == 0, "running, no fault"


def quiet_runs(settings, seed, count=40):
    """Seeded runs of the pin from min_run to about twice the window, a third of them as
    short as allowed so some edges come just after another."""
    rng = random.Random(seed)
    shortest = settings["min_run"]
    longest = 2 * (settings["latency"] + settings["jitter"] + PAD_DELAY)
    return [rng.randint(shortest, shortest + 2) if rng.random() < 1 / 3
            else rng.randint(shortest, longest) for _ in range(count)]


async def refused_watch(dut, name, pc):
    await reset(dut)
    host = AsyncHost(Pins(dut).transfer)
    try:
        await load_watch(host, name)
    except Refused as refused:
        assert refused.args[1:] == (pc, 0), refused.args  # reason 0: a wait not in time
        await host.write(CONTROL, [1])
        assert (await host.read(STATUS))[0] & 1, "a start without a certificate leaves it halted"
        assert (await host.read(CHECK_STATUS))[0] & 8, "and shows it refused"
    else:
        assert False, "the chip started a watch it cannot check"


@cocotb.test()
async def test_quiet_watch(dut):
    """The compiled quiet watch's timing rests on the kernel's affine rows, a phase less a
    multiple of x, which the chip's check does not carry: the chip refuses to start it,
    at its first deadline wait. The kernel on the host accepts it (test_asm.ml)."""
    await refused_watch(dut, "quiet_watch", pc=8)


@cocotb.test()
async def test_quiet_watch_slow(dut):
    """The same at a latency whose budget the host sends, as the settings say."""
    assert "budget_from_host" in predicate_settings("quiet_watch_slow")
    await refused_watch(dut, "quiet_watch_slow", pc=10)
