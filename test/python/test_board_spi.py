# SPDX-License-Identifier: Apache-2.0
# python/demo_board.py and demo_board_check.py on ttboard_fake's RP2, against a model of the
# host port a clock at a time: host_spi.ml's synchronisers and shifters over a register
# file. The waveforms are held to SCK at most a twelfth of the clock; test/test_demo_board.py
# runs the same scripts on the RTL.
import sys

sys.path[:0] = sys.argv[1:3]
import protocol_emulator as pe  # noqa: E402
import ttboard_fake  # noqa: E402

HEX = sys.argv[3]


class Chip:
    """Two engines' registers behind host_spi.ml's frame logic. A started engine whose
    program begins with `uart` takes the bit period, then sends each word on uo[1]."""

    def __init__(self, uart=None):
        self.uart = uart
        self.ui, self.rst_n, self.carry, self.now, self.settle = 0b100, 1, 0, 0, 0
        self.reset()

    def reset(self):
        self.sync = [0b100, 0b100]
        self.sck, self.selected, self.count, self.shift_in, self.shift_out = 0, False, 0, 0, 0
        self.state, self.cmd, self.high, self.value = "cmd", 0, 0, 0
        self.program_addr, self.data_addr, self.select = 0, 0, 0
        self.engines = [dict(halted=1, tx=[], rx=[], program=[0] * 512, period=None,
                             free_at=0, frames=[]) for _ in range(2)]

    # the backend
    def run(self, board, ticks, stop=None):
        ttboard_fake.run_sync(self, board, ticks, stop)

    def drive(self, ui, rst_n):
        self.ui, self.rst_n = ui, rst_n
        self.settle = 5

    def pads(self):
        e = self.engines[0]
        return int(self.selected and self.shift_out >> 7) | self.line(e) << 1, 0

    def elapse(self, board, ticks):
        if not board.clock_hz:
            return
        cycles, self.carry = divmod(self.carry + ticks * board.clock_hz, board.sys_hz)
        while cycles and self.settle:
            self.clock()
            cycles -= 1
            self.settle -= 1
        self.now += cycles
        for e in self.engines:
            self.serve(e)

    def clock(self):
        self.now += 1
        if not self.rst_n:
            self.reset()
            return
        # the edge detect's register: shift_out moves on the third edge, as in the RTL
        ui = self.sync[0]
        self.sync = [self.sync[1], self.ui]
        sck, mosi, selected = ui & 1, (ui >> 1) & 1, not (ui >> 2) & 1
        rise = selected and sck and not self.sck
        fall = selected and not sck and self.sck
        start = selected and not self.selected
        self.sck, self.selected = sck, selected
        if start:
            self.count, self.state, self.shift_out = 0, "cmd", 0
        if rise:
            self.shift_in = ((self.shift_in << 1) | mosi) & 0xFF
            self.count = (self.count + 1) & 7
            if self.count == 0:
                self.byte(self.shift_in)
        if fall:
            if self.count == 0:
                self.shift_out = self.load()
            else:
                self.shift_out = (self.shift_out << 1) & 0xFF
        for e in self.engines:
            self.serve(e)

    # the register layer
    def byte(self, b):
        if self.state == "cmd":
            self.cmd, self.state = b, "high"
        elif self.state == "high":
            self.high, self.state = b, "low"
        else:
            self.state = "high"
            reg = self.cmd & 0x7F
            if self.cmd & 0x80:
                self.write(reg, self.high << 8 | b)
            elif reg == pe.RX and self.engines[self.select]["rx"]:
                self.engines[self.select]["rx"].pop(0)

    def load(self):
        if self.state == "high":
            self.value = 0 if self.cmd & 0x80 else self.read(self.cmd & 0x7F)
            return self.value >> 8
        return self.value & 0xFF

    def read(self, reg):
        e = self.engines[self.select]
        return {
            pe.STATUS: e["halted"] | len(e["tx"]) << 6 | len(e["rx"]) << 10,
            pe.NOW_LO: self.now & 0xFFFF, pe.NOW_HI: (self.now >> 16) & 0xFF,
            pe.PROGRAM_ADDR: self.program_addr, pe.DATA_ADDR: self.data_addr,
            pe.SELECT: self.select, pe.RX: e["rx"][0] if e["rx"] else 0,
        }.get(reg, 0)

    def write(self, reg, w):
        e = self.engines[self.select]
        if reg == pe.CONTROL:
            if w & 1 and e["halted"]:
                e.update(halted=0, free_at=self.now + 4)
            if w & 4:
                e.update(halted=1, period=None, frames=[])
            if w & 8 and e["halted"]:
                e.update(tx=[], rx=[])
        elif reg == pe.PROGRAM_ADDR:
            self.program_addr = w & 511
        elif reg == pe.PROGRAM:
            if all(x["halted"] for x in self.engines):
                e["program"][self.program_addr] = w
            self.program_addr = (self.program_addr + 1) & 511
        elif reg == pe.SELECT:
            self.select = w & 1
        elif reg == pe.TX and len(e["tx"]) < 8:
            e["tx"].append(w)

    # uart_tx_host_rate, as a schedule of frames
    def serve(self, e):
        if e["halted"] or not self.uart or e["program"][:len(self.uart)] != self.uart:
            return
        while e["tx"] and e["free_at"] <= self.now:
            w = e["tx"].pop(0)
            if e["period"] is None:
                e["period"], e["idle_from"], e["free_at"] = w, e["free_at"], e["free_at"] + 4
            else:
                start = max(e["free_at"], self.now) + 5
                e["frames"].append((start, w))
                e["free_at"] = start + 10 * e["period"] + 2

    def line(self, e):
        if e["period"] is None:
            return 0
        for start, w in e["frames"]:
            bit = (self.now - start) // e["period"]
            if 0 <= bit < 10:
                return 0 if bit == 0 else 1 if bit == 9 else (w >> (bit - 1)) & 1
        return int(self.now >= e["idle_from"])


def board(chip=None, **kwargs):
    b = ttboard_fake.Board(chip or Chip(), **kwargs)
    return b, b.install()


def edges(b, clock_hz):
    """(chip cycle, ui byte) of each change on the pads."""
    return [(t * clock_hz, ui) for t, ui in b.trace]


def assert_spi_timing(trace, clock_hz, sck_hz):
    """SCK's half periods are four clocks or more, MOSI moves only with SCK low, and CS_N
    frames whole bytes, each more than two clocks from an SCK edge."""
    half = clock_hz / sck_hz / 2
    rises = falls = 0
    last_sck, last_edge, cs_n = None, None, 1
    for (at, ui), (_, before) in zip(trace[1:], trace):
        sck, mosi, new_cs = ui & 1, (ui >> 1) & 1, (ui >> 2) & 1
        if sck != before & 1:
            if last_sck is not None:
                assert at - last_sck >= min(half, 4) - 0.01, (at - last_sck, half)
            assert not new_cs, "SCK moved outside a frame"
            last_sck = last_edge = at
            rises += sck
            falls += not sck
        if mosi != (before >> 1) & 1:
            assert not sck, "MOSI moved with SCK high"
        if new_cs != cs_n:
            assert sck == 0
            assert last_edge is None or at - last_edge > 2, "CS_N on an SCK edge"
            if new_cs:
                assert rises == falls and rises % 8 == 0, (rises, falls)
            last_edge, last_sck, cs_n = at, None, new_cs
    return rises


def test_frames_and_timing():
    for kind, clock_hz, sck_hz in (("dbv3", 48_000_000, None), ("dbv3", 10_000_000, None),
                                   ("tt06", 48_000_000, 4_000_000)):
        chip = Chip()
        b, m = board(chip, kind=kind)
        spi = m.demo_board.DemoBoardSpi(clock_hz=clock_hz, sck_hz=sck_hz)
        host = pe.Host(spi.transfer)
        assert host.status()["halted"] == 1
        for word in (0x1A5, 0x05A, 0x1FF, 0):
            host.write(pe.PROGRAM_ADDR, [word])
            assert host.read(pe.PROGRAM_ADDR) == [word]
        # every frame length up to a 31-byte rx read, across the chunks of four
        chip.engines[0]["rx"] = list(range(0x100, 0x10F))
        assert host.pop(15) == list(range(0x100, 0x10F))
        assert host.status()["rx_level"] == 0
        words = [(i * 0x9E37) & 0xFFFF for i in range(300)]
        host.load(words)
        assert chip.engines[0]["program"] == words + [0] * 212
        assert host.read(pe.PROGRAM_ADDR) == [0]
        rises = assert_spi_timing(edges(b, clock_hz), clock_hz, spi.sck_hz)
        assert rises > 8 * 1025, rises
        # on the RP2350B the PIO reaches GPIO 33 from base 16; the RP2040's needs none
        assert b.pios[1].base == (16 if kind == "dbv3" else 0), (kind, b.pios[1].base)
        b.uninstall()


def test_sck_margin():
    """SCK at an eighth, were it allowed, reads each bit before MISO moves: the limit is
    what the lag from the chip's pads to the PIO costs."""
    b, m = board()
    m.demo_board.SCK_DIVIDE = 8
    spi = m.demo_board.DemoBoardSpi(clock_hz=48_000_000, sck_hz=6_000_000)
    host = pe.Host(spi.transfer)
    host.write(pe.PROGRAM_ADDR, [0x1A5])
    assert host.read(pe.PROGRAM_ADDR) != [0x1A5]
    b.uninstall()


def test_setup():
    """Mode before enable, enable's clock and the button's monitor stopped, the PWM at
    the clock asked for and the project reset under it, uio left to the chip."""
    b, m = board()
    spi = m.demo_board.DemoBoardSpi(clock_hz=48_000_000)
    events = [(what, value) for _, what, value in b.log]
    assert events == [
        ("mode", 1), ("enable", "tt_um_marcosash_protocol_emulator"), ("clock", 50_000_000),
        ("clock", 0), ("clock", 48_000_000), ("reset", True), ("reset", False),
    ], events
    held = [t for t, what, _ in b.log if what == "reset"]
    assert (held[1] - held[0]) * 48_000_000 > 10_000
    assert m.tt.manual_project_clock.monitoring is False
    assert m.tt.uio_oe_pico.value == 0
    assert b.sys_hz == 96_000_000 and spi.sck_hz == 3_000_000
    b.uninstall()


def test_refusals():
    b, m = board()
    for kwargs, message in (({"sck_hz": 4_000_001}, "over 1/12"),
                            ({"project": "tt_um_other"}, "not on this chip")):
        try:
            m.demo_board.DemoBoardSpi(**kwargs)
            raise AssertionError(kwargs)
        except (ValueError, RuntimeError) as e:
            assert message in str(e), e
    b.uninstall()
    b, m = board(switches=0b010)
    said = []
    assert not m.demo_board_check.run(window_ms=2, say=said.append)
    assert said == ["FAIL setup: ui[1] reads high: turn its DIP switch off", "FAIL"], said
    b.uninstall()


def test_check():
    with open(HEX) as f:
        words = pe.hex_words(f.read())
    b, m = board(Chip(uart=words))
    assert m.demo_board_check.UART_TX == words
    said = []
    assert m.demo_board_check.run(window_ms=2, say=said.append), said
    assert said == [
        "pass status 0: 0x0001, wants 0x0001",
        "pass status 1: 0x0001, wants 0x0001",
        "pass readback: program address and select read 0x1a5 0x05a 0x001 0x000",
        "pass clock: %s" % said[3].split(": ", 1)[1],
        "pass load: program address 0x000 after 512 words",
        "pass uart: 0x55 0xa3 0x00 0xff at 417 cycles a bit, faults 0x00",
        "PASS",
    ], said
    b.uninstall()
    # in one session after a host, and again: each instance loads its programs afresh
    b, m = board(Chip(uart=words))
    host = m.demo_board.host()
    assert host.status()["halted"] == 1
    for _ in range(2):
        said = []
        assert m.demo_board_check.run(window_ms=2, say=said.append), said
    b.uninstall()
    # a chip that never starts the uart, and one on half the clock
    for chip, clock_hz, failed in ((Chip(), 48_000_000, "FAIL uart"),
                                   (Chip(uart=words), 24_000_000, "FAIL clock")):
        b, m = board(chip)
        m.tt.clock_project_PWM = lambda hz, set_clock=b.set_clock: set_clock(clock_hz)
        said = []
        assert not m.demo_board_check.run(window_ms=2, say=said.append)
        assert any(line.startswith(failed) for line in said), said
        b.uninstall()


test_frames_and_timing()
test_sck_margin()
test_setup()
test_refusals()
test_check()
