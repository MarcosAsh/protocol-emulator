# SPDX-License-Identifier: Apache-2.0
# DShot600, SENT and HDMI-CEC from the certified library on the chip, each line decoded
# and timed here against its protocol's limits.

import cocotb
from cocotb.triggers import ClockCycles

from test import AsyncHost, Pins, reset
from protocol_emulator import CONTROL, PROGRAM, PROGRAM_ADDR, RX, STATUS, TX, config_writes
import certified_firmware

CYCLE_NS = 20


async def start(dut, firmware, words, watch):
    """Loads and starts the firmware, then writes its words, with [watch] run every cycle
    from before the load."""
    await reset(dut)
    host = AsyncHost(Pins(dut).transfer)

    async def every_cycle():
        while True:
            watch()
            await ClockCycles(dut.clk, 1)

    task = cocotb.start_soon(every_cycle())
    for reg, word in config_writes(firmware["config"]):
        await host.write(reg, [word])
    await host.write(PROGRAM_ADDR, [0])
    await host.write(PROGRAM, firmware["words"])
    await host.write(CONTROL, [1])
    await host.write(TX, words)
    return host, task


def runs(levels):
    """(level, cycles) for each run of equal levels."""
    out = []
    for level in levels:
        if out and out[-1][0] == level:
            out[-1][1] += 1
        else:
            out.append([level, 1])
    return out


def dshot_frame(throttle, telemetry):
    value = (throttle << 1) | telemetry
    return (value << 4) | ((value ^ (value >> 4) ^ (value >> 8)) & 0xF)


def decode_dshot(levels):
    """DShot600: T0H 625 ns, T1H 1250 ns, bit 1667 ns, each within 5%; a low of more than
    two bits ends a frame."""
    def within(ns, nominal, name):
        assert abs(ns - nominal) * 20 <= nominal, f"{name} of {ns} ns"

    pulses = []
    rs = runs(levels)
    while rs and rs[0][0] == 0:
        rs.pop(0)
    for i in range(0, len(rs), 2):
        high = rs[i][1] * CYCLE_NS
        low = rs[i + 1][1] * CYCLE_NS if i + 1 < len(rs) else None
        pulses.append((high, low))
    frames, bits = [], []
    for high, low in pulses:
        one = high * 2 > 625 + 1250
        within(high, 1250 if one else 625, "T1H" if one else "T0H")
        bits.append(int(one))
        if low is not None and low <= 2 * 1667:
            within(high + low, 1667, "bit")
            continue
        assert len(bits) == 16, bits
        word = int("".join(map(str, bits)), 2)
        value = word >> 4
        assert dshot_frame(value >> 1, value & 1) == word, f"checksum of {word:#06x}"
        frames.append((value >> 1, value & 1))
        bits = []
    return frames


@cocotb.test()
async def test_dshot600(dut):
    sent = [(1046, 0), (48, 0), (2047, 1)]
    levels = []
    host, task = await start(
        dut,
        certified_firmware.DSHOT600,
        [dshot_frame(*f) for f in sent],
        lambda: levels.append((int(dut.uo_out.value) >> 1) & 1))
    await ClockCycles(dut.clk, 5200)
    task.cancel()
    assert decode_dshot(levels) == sent
    assert (await host.read(STATUS))[0] & 0x3D == 0, "running, no fault"


SENT_CRC = [0, 13, 7, 10, 14, 3, 9, 4, 1, 12, 6, 11, 15, 2, 8, 5]


def sent_crc(nibbles):
    crc = 5
    for n in nibbles:
        crc = SENT_CRC[crc] ^ n
    return SENT_CRC[crc]


def sent_words(status, data):
    nibbles = [status] + data + [0]
    return [int("".join(f"{n:x}" for n in nibbles[i:i + 4]), 16) for i in (0, 4)]


def decode_sent(levels):
    """SAE J2716 pulses from their falling edges: sync 56 ticks and within 1/64 of the
    last, every pulse low more than 4 ticks, nibbles 12 to 27 ticks and whole to an eighth
    of a tick, a pause 12 to 768. A trailing frame cut short has its sync checked, as
    test/sent.ml's decoder does, and does not count. Like that one, an oracle for this
    transmitter: no check of J2716's 3 to 90 us tick, so the test runs short ticks, and a
    pause after every frame."""
    falls = [i for i in range(1, len(levels)) if levels[i - 1] and not levels[i]]
    rises = [i for i in range(1, len(levels)) if not levels[i - 1] and levels[i]]
    pulses = []
    for fall, nxt in zip(falls, falls[1:]):
        rise = next(r for r in rises if r > fall)
        pulses.append((nxt - fall, rise - fall))
    frames = []
    previous = None
    while pulses:
        sync, sync_low = pulses[0]
        assert 56 * sync_low > 4 * sync, ("sync low", sync_low)
        assert previous is None or abs(sync - previous) * 64 <= previous, ("sync drifts", sync)
        previous = sync
        if len(pulses) < 9:
            break
        nibbles = []
        for length, low in pulses[1:9]:
            ticks = round(56 * length / sync)
            assert abs(56 * length - ticks * sync) * 8 <= sync, "not whole ticks"
            assert 12 <= ticks <= 27 and 56 * low > 4 * sync, (ticks, low)
            nibbles.append(ticks - 12)
        assert sent_crc(nibbles[1:7]) == nibbles[7], nibbles
        frames.append((nibbles[0], nibbles[1:7]))
        pulses = pulses[9:]
        if pulses:
            pause, pause_low = pulses[0]
            assert 12 * sync <= 56 * pause <= 768 * sync, ("pause", pause)
            assert 56 * pause_low > 4 * sync, ("pause low", pause_low)
            pulses = pulses[1:]
    return frames


@cocotb.test()
async def test_sent(dut):
    """At a tick of 24 cycles, 480 ns, so the frames are short."""
    tick = 24
    sent = [(0x5, [1, 2, 3, 4, 5, 6]), (0xA, [0xC, 0xA, 0xF, 0xE, 0x0, 0x7])]
    words = [tick] + [w for frame in sent for w in sent_words(*frame)]
    levels = []
    host, task = await start(
        dut,
        certified_firmware.SENT,
        words,
        lambda: levels.append((int(dut.uo_out.value) >> 1) & 1))
    await ClockCycles(dut.clk, 12000)
    task.cancel()
    assert decode_sent(levels) == sent
    assert (await host.read(STATUS))[0] & 0x3D == 0, "running, no fault"


class CecFollower:
    """A follower at logical address 0 that acknowledges every block sent to it and times
    the initiator in units: start low 70 to 78 and 86 to 94 in all, a one low 8 to 16, a
    zero 26 to 34, a bit 41 to 55 (CEC 1.4, in 50 us units). Before a frame the line is
    free for 5 bit periods of 48 units if its initiator is new, 3 if it retries a frame
    that failed, and 7 otherwise (CEC 9.1), checked at its EOM."""

    def __init__(self, unit):
        self.unit = unit
        self.cycle = 0
        self.low = False
        self.fall = None
        self.kind = None
        self.bits = []
        self.frame = []
        self.acks = []
        self.frames = []
        self.drive_until = -1
        self.free = None
        self.previous = None

    def drives(self):
        return self.cycle < self.drive_until

    def within(self, cycles, lo, hi, name):
        assert lo * self.unit <= cycles <= hi * self.unit, f"{name} of {cycles} cycles"

    def check_free(self, frame):
        if self.free is None or self.previous is None:
            return
        previous, went_through = self.previous
        if previous[0] >> 4 != frame[0] >> 4:
            periods = 5
        elif not went_through and previous == frame:
            periods = 3
        else:
            periods = 7
        assert self.free >= periods * 48 * self.unit, f"free of {self.free} cycles"

    def step(self, low):
        if low and not self.low:
            if self.fall is not None and self.kind is None:
                self.free = self.cycle - self.fall - 48 * self.unit
            if self.fall is not None and self.kind is not None:
                period = self.cycle - self.fall
                if self.kind == "start":
                    self.within(period, 86, 94, "start")
                else:
                    self.within(period, 41, 55, "bit")
            if len(self.bits) == 9:
                header = self.frame[0] if self.frame else int("".join(map(str, self.bits[:8])), 2)
                if header & 0xF == 0:
                    self.drive_until = self.cycle + 30 * self.unit
            self.fall = self.cycle
        elif not low and self.low:
            width = self.cycle - self.fall
            if self.kind is None:
                self.within(width, 70, 78, "start low")
                self.kind = "start"
            elif len(self.bits) == 9:
                self.acks.append(int(width > 21 * self.unit))
                if self.drive_until < 0:
                    self.within(width, 8, 16, "one low")
                self.drive_until = -1
                self.frame.append(int("".join(map(str, self.bits[:8])), 2))
                eom = self.bits[8]
                self.bits = []
                self.kind = "bit"
                if eom:
                    destination = self.frame[0] & 0xF
                    went_through = (not any(self.acks)) if destination == 0xF else all(self.acks)
                    self.check_free(self.frame)
                    self.previous = (self.frame, went_through)
                    self.frames.append((self.frame, self.acks))
                    self.frame, self.acks, self.kind = [], [], None
            else:
                one = width <= 21 * self.unit
                self.within(width, *((8, 16) if one else (26, 34)), "one low" if one else "zero low")
                self.bits.append(int(one))
                self.kind = "bit"
        self.low = low
        self.cycle += 1


def cec_words(blocks):
    return [len(blocks) - 1] + [(b << 8) | ((i == len(blocks) - 1) << 7) for i, b in enumerate(blocks)]


@cocotb.test()
async def test_cec(dut):
    """At a unit of 8 cycles: a poll of the TV, 0, which answers, and one of 5, which
    does not; the initiator pushes the line it saw in each ACK slot."""
    unit = 8
    follower = CecFollower(unit)
    frames = [[0x40], [0x45]]
    words = [unit] + [w for blocks in frames for w in cec_words(blocks)]

    def line():
        chip_low = (int(dut.uio_oe.value) & 1) and not (int(dut.uio_out.value) & 1)
        low = bool(chip_low) or follower.drives()
        dut.uio_in.value = 0 if low else 1
        follower.step(low)

    host, task = await start(dut, certified_firmware.CEC, words, line)
    await ClockCycles(dut.clk, 16000)
    task.cancel()
    assert follower.frames == [([0x40], [1]), ([0x45], [0])], follower.frames
    assert await host.read(RX, 2) == [0, 1], "ACK from 0, none from 5"
    assert (await host.read(STATUS))[0] & 0x3D == 0, "running, no fault"


def cec_lows(sends):
    """An initiator's line in units, a cycle each: per frame the bit periods free before
    it, its initiator, its destination and its data."""
    def bit(one):
        return [i < (12 if one else 30) for i in range(48)]

    lows = []
    for free, initiator, destination, data in sends:
        blocks = [(initiator << 4) | destination] + data
        lows += [False] * (free * 48) + [i < 74 for i in range(90)]
        for i, block in enumerate(blocks):
            for b in range(7, -1, -1):
                lows += bit((block >> b) & 1)
            lows += bit(i == len(blocks) - 1) + bit(True)
    return lows


@cocotb.test()
async def test_cec_follower_free_time(dut):
    """The follower's CEC 9.1 cases on a drawn line: 4 polls 5, where no one answers, so a
    retry of it may come 3 bit periods on, but a new frame of 4's owes 7 and one from a new
    initiator, 3, owes 5."""
    failed, ok = (0, 4, 5, []), (0, 4, 0, [])
    cases = [
        ([failed, (3, 4, 5, [])], True),
        ([failed, (2, 4, 5, [])], False),
        ([ok, (5, 3, 0, [])], True),
        ([ok, (4, 3, 0, [])], False),
        ([failed, (3, 3, 0, [])], False),
        ([failed, (3, 4, 0, [])], False),
        ([failed, (7, 4, 0, [0x04])], True),
    ]
    for sends, passes in cases:
        follower = CecFollower(1)
        try:
            for low in cec_lows(sends):
                follower.step(low or follower.drives())
            assert len(follower.frames) == 2, follower.frames
            verdict = True
        except AssertionError as e:
            assert str(e).startswith("free of"), e
            verdict = False
        assert verdict == passes, (sends, verdict)


def sent_levels(frames, low=5):
    """A line drawn from (tick in cycles, status, data) frames, each pulse [low] ticks low,
    a 12-tick pause after each, and a last fall to close the last pulse. A frame with no
    data is its sync alone."""
    levels = [True]
    for tick, status, data in frames:
        nibbles = [status] + data + [sent_crc(data)] if data else []
        for ticks in [56] + [12 + n for n in nibbles] + ([12] if data else []):
            levels += [i >= low * tick for i in range(ticks * tick)]
    return levels + [False]


@cocotb.test()
async def test_sent_decoder_sync_drift(dut):
    """J2716 lets successive syncs differ by 1/64 at most, a trailing sync with no frame
    after it too; a tick of 64 then 65 cycles is at the bound, 64 then 66 past it."""
    data = [1, 2, 3, 4, 5, 6]
    assert decode_sent(sent_levels([(64, 5, data), (65, 5, data)])) == [(5, data)] * 2
    for frames in ([(64, 5, data), (66, 5, data)], [(64, 5, data), (66, 5, [])]):
        levels = sent_levels(frames)
        try:
            decode_sent(levels)
        except AssertionError as e:
            assert "sync drifts" in str(e), e
        else:
            assert False, ("accepted", frames)


@cocotb.test()
async def test_sent_decoder_low(dut):
    """J2716's lows are more than 4 ticks: 5 passes, 4 does not."""
    frames = [(16, 5, [1, 2, 3, 4, 5, 6])]
    assert decode_sent(sent_levels(frames, low=5)) == [(5, [1, 2, 3, 4, 5, 6])]
    try:
        decode_sent(sent_levels(frames, low=4))
    except AssertionError:
        pass
    else:
        assert False, "a low of 4 ticks accepted"
