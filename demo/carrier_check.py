# SPDX-License-Identifier: Apache-2.0
# The bench carrier v1.2's self-test, with icepi/carrier_check.v in the Icepi and MicroPython
# on both Picos: a line per net of demo/carrier_netlist.csv, or group, with its pads. PASS or
# FAIL where a pin reaches it, SKIP where none does. Both Picos run python/carrier_pins.py.
# --analysers pulses every analysed net a count of its own while each analyser captures,
# which finds a probe on the wrong pin. A flash JEDEC ID of all 00 or ff is a SKIP.
# --button-only checks SW1 alone, which waits for a press.
# demo/carrier_check.sh loads the bitstream, runs this, and puts the chip back.
# Usage: PICO=id:<serial of Pico A> [PICO_B_SERIAL=<serial>] python3 demo/carrier_check.py
#            [--analysers] [--no-button | --button-only] [--evidence DIR]

import argparse
import ast
import csv
import datetime
import glob
import os
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Callable

import sigrok

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "python"))
import carrier_pins  # noqa: E402
import demo_ds18b20  # noqa: E402
import demo_flash  # noqa: E402
import demo_swd  # noqa: E402
from carrier_pins import HEADER, bit  # noqa: E402

NETLIST = ROOT / "demo/carrier_netlist.csv"
PICO_B_SERIAL = "e66548545740ad29"
# Pico GPn's physical pin, and the sockets of each Pico's pins 1-20 and 40-21
GP_PIN = {0: 1, 1: 2, 2: 4, 3: 5, 4: 6, 5: 7, 6: 9, 7: 10, 8: 11, 9: 12}
SOCKETS = {"A": ("J13", "J14"), "B": ("J15", "J16")}
# header pins carrier_check.v holds high, and those that read high let go: the pull-ups and
# CAN board A's R
DRIVEN_HIGH = {10, 28}
IDLE_HIGH = {5, 10, 28, 33, 35, 36, 37}
# not driven against what drives them: CAN board A's R, and the flash's CS, which would
# select it
LISTEN_ONLY = {5, 28}
# what driving a pin moves elsewhere through the carrier: R14-R16-R15, and CAN board A
COUPLED = {38: {40}, 40: {38}, 10: {5}}
PULL_UPS = [
    (33, ["I2C_SDA"], "R5 2k2 to 3V3_A"),
    (35, ["I2C_SCL"], "R6 2k2 to 3V3_A"),
    (37, ["DQ"], "R7 4k7 to 3V3_A"),
    (28, ["FLASH_CS_N"], "R2 10k to 3V3_A"),
    (36, ["SWDIO", "SWDIO_PICO"], "R12 220R and R13 4k7 to 3V3_B"),
]
# each analysed net's pulses: the header pin that makes them and the level they go to.
# Header 10 reaches analyser A's D5 through CAN board A, as CAN_RX.
PULSED = [(8, 1), (10, 0), (12, 1), (36, 0), (26, 1), (22, 1), (3, 1), (28, 0), (18, 1),
          (37, 0), (33, 0), (35, 0)]
ANALYSERS = {"A": "J2", "B": "J3"}
# The analysers often stop within half a second, so Pico A repeats the pulses past the
# capture and the check reads one whole train from the middle. A train takes some 90 ms.
TRAINS, TRAIN_GAP_US, SPLIT_S = 60, 30_000, 0.015
CAPTURE_MS = 8000
BUTTON_MS = 120_000
# the longest a call on a Pico may take: the wait for a press, then some
CALL_S = BUTTON_MS // 1000 + 15
# Pico A's VSYS from USB: VBUS less its Schottky diode
VSYS = (4.3, 5.5)


def netlist(path=NETLIST):
    """Each net's pads, and each pad's net."""
    with open(path) as f:
        nets = {row["net"]: row["pads"].split() for row in csv.DictReader(f)}
    return nets, {pad: net for net, pads in nets.items() for pad in pads}


def pico_pad(pico, gp):
    left, right = SOCKETS[pico]
    n = GP_PIN[gp]
    return "%s.%d" % (left, n) if n <= 20 else "%s.%d" % (right, 41 - n)


@dataclass
class Bench:
    pins: object
    a: object
    b: object
    # capture(analyser, action): its samples while action runs
    capture: Callable
    say: Callable = print


class Report:
    def __init__(self, nets, say):
        self.nets, self.say = nets, say
        self.lines = []

    def line(self, status, nets, detail):
        pads = sorted({p for n in nets for p in self.nets.get(n, [])}, key=_pad_order)
        self.lines.append((status, nets, detail))
        where = "%s [%s]: " % (" ".join(nets), " ".join(pads)) if nets else ""
        self.say("%s %s%s" % (status, where, detail))

    def check(self, ok, nets, detail, why):
        self.line("PASS" if ok else "FAIL", nets, detail if ok else why)
        return ok

    def count(self, status):
        return sum(s == status for s, _, _ in self.lines)


def _pad_order(pad):
    ref, n = pad.split(".")
    letters = ref.rstrip("0123456789")
    return letters, int(ref[len(letters):] or 0), int(n)


def host_port(bench, r):
    nets = ["HOST_SCK", "HOST_MOSI", "HOST_MISO", "HOST_CS_N"]
    signature = bench.pins.signature()
    if signature != carrier_pins.SIGNATURE:
        r.line("FAIL", nets, "Pico A read %r, not b'pin': carrier_check.v is not loaded, or "
               "SCK, MISO or CS_N is open" % signature)
        return False
    up, down = bit(bench.pins.apply({8: 1}), 8), bit(bench.pins.apply({8: None}), 8)
    return r.check((up, down) == (1, 0), nets, "the bitstream answers 'pin' and takes frames",
                   "the bitstream answers but frames do not take: MOSI is open")


def shorts(bench, r, names):
    """Every pin let go at its idle level, then each driven the other way alone: nothing else
    may move but what COUPLED lets."""
    pins = bench.pins
    base = pins.idle()
    stuck = [h for h in HEADER if bit(base, h) != (h in IDLE_HIGH)]
    for h in stuck:
        r.line("FAIL", [names[h]], "header %d reads %d let go: %s" % (
            h, bit(base, h), "a short to 3V3 or a Pico driving it" if bit(base, h)
            else "CAN board A's R is not high" if h == 5 else "no pull-up, or a short to GND"))
    found = []
    for h in HEADER:
        if h in LISTEN_ONLY:
            continue
        moved = pins.apply({h: 1 - bit(base, h)})
        pins.apply({h: 1 if h in DRIVEN_HIGH else None})
        found += [(h, o) for o in HEADER
                  if o != h and o not in COUPLED.get(h, ()) and o not in stuck
                  and bit(moved, o) != bit(base, o)]
    for h, o in found:
        r.line("FAIL", [names[h], names[o]], "driving header %d to %d moves header %d: a short"
               % (h, 1 - bit(base, h), o))
    spare = [h for h in (7, 11, 13) if h in stuck or any(h in pair for pair in found)]
    if not spare:
        r.line("PASS", [names[h] for h in (7, 11, 13)],
               "let go they read 0, and nothing else moves them (J12 is open)")
    if not found:
        r.line("PASS", [], "no shorts among the 21 header pins")
    return not found and not stuck


def pull_ups(bench, r):
    pins, passed = bench.pins, []
    for h, nets, part in PULL_UPS:
        pins.put({h: None})
        high = pins.slot(h, 0, 5, 30)
        if h in DRIVEN_HIGH:
            pins.put({h: 1})
        passed.append(r.check(high == 1, nets, "%s pulls header %d up within 25 us" % (part, h),
                              "header %d stays low once let go: %s missing" % (h, part)))
    return passed


def replug(bench, r):
    """SW1 on Pico A's GP9, which only a press shows."""
    a = bench.a
    if a.pressed(9, 0):
        r.line("FAIL", ["REPLUG"], "GP9 is low before any press: SW1 shorted")
        return
    bench.say("     press REPLUG (SW1, below Pico A) within %d s" % (BUTTON_MS // 1000))
    r.check(a.pressed(9, BUTTON_MS), ["REPLUG"], "a press pulls Pico A GP9 low",
            "no press reached GP9 in %d s: SW1 or its pads" % (BUTTON_MS // 1000))


def pico_a(bench, r):
    a, pins = bench.a, bench.pins
    for gp in (6, 7, 8):
        a.let_go(gp)
    seen = []
    for v in (1, 0):
        pins.apply({29: v, 31: 1 - v})
        seen.append((a.read(6), a.read(7)))
    pins.apply({29: None, 31: None})
    r.check([s[0] for s in seen] == [1, 0], ["USB_MIR0"], "header 29 reaches Pico A GP6",
            "Pico A GP6 read %s for header 29 at 1 then 0" % [s[0] for s in seen])
    r.check([s[1] for s in seen] == [0, 1], ["USB_MIR1"], "header 31 reaches Pico A GP7",
            "Pico A GP7 read %s for header 31 at 0 then 1" % [s[1] for s in seen])
    out = []
    for v in (1, 0):
        a.drive(8, v)
        out.append(bit(pins.apply({}), 15))
    a.let_go(8)
    back = []
    for v in (1, 0):
        pins.apply({15: v})
        back.append(a.read(8))
    pins.apply({15: None})
    r.check(out == [1, 0] and back == [1, 0], ["USB_DETACH"],
            "Pico A GP8 and header 15 reach each other",
            "header 15 read %s for GP8 at 1 then 0, GP8 read %s back" % (out, back))


def pico_b(bench, r):
    b, pins = bench.b, bench.pins
    for gp in (1, 2, 3, 6):
        b.let_go(gp)
    # CAN board B's D, recessive throughout but where the check drives it
    b.drive(7, 1)
    to_b, to_fpga = [], []
    for v in (1, 0):
        pins.apply({8: v})
        to_b.append(b.read(1))
    pins.apply({8: None})
    for v in (1, 0):
        b.drive(1, v)
        to_fpga.append(bit(pins.apply({}), 8))
    b.let_go(1)
    r.check(to_b == [1, 0] and to_fpga == [1, 0], ["UART_B", "UART_B_PICO"],
            "header 8 and Pico B GP1 reach each other through R8",
            "GP1 read %s for header 8 at 1 then 0, header 8 read %s back" % (to_b, to_fpga))
    # each line pulled low alone, from either end
    to_b, to_fpga = [], []
    for h in (33, 35):
        pins.apply({h: 0})
        to_b.append((b.read(2), b.read(3)))
        pins.apply({h: None})
    for gp in (2, 3):
        b.drive(gp, 0)
        levels = pins.apply({})
        to_fpga.append((bit(levels, 33), bit(levels, 35)))
        b.let_go(gp)
    r.check(to_b == [(0, 1), (1, 0)] and to_fpga == [(0, 1), (1, 0)], ["I2C_SDA", "I2C_SCL"],
            "header 33 is Pico B GP2 (SDA) and header 35 GP3 (SCL)",
            "GP2, GP3 read %s for headers 33 then 35 low, headers 33, 35 read %s for GP2 then "
            "GP3 low" % (to_b, to_fpga))


def eeprom(bench, r):
    found = bench.b.i2c_scan(2, 3)
    at = [x for x in found if 0x50 <= x <= 0x57]
    nets = ["I2C_SDA", "I2C_SCL", "3V3_A"]
    if not at:
        return r.check(False, nets, "", "Pico B's scan finds %s, no 24LC256 at 0x50 to 0x57: "
                       "the module on J10 or its cable" % ["0x%02x" % x for x in found])
    free = set(range(0x50, 0x58)) - set(found)
    if not free:
        return r.check(False, nets, "", "Pico B's scan finds every address 0x50 to 0x57: "
                       "SDA held low")
    absent = min(free)
    acked, refused = bench.pins.i2c_probe(at[0]), not bench.pins.i2c_probe(absent)
    note = "" if at[0] == 0x50 else ", not 0x50: its address jumpers"
    return r.check(acked and refused, nets,
                   "the EEPROM ACKs at 0x%02x%s, from Pico B and from the header, and 0x%02x does "
                   "not" % (at[0], note, absent),
                   "Pico B finds 0x%02x, but from the header it %s and 0x%02x %s" % (
                       at[0], "ACKs" if acked else "does not ACK", absent,
                       "does not" if refused else "ACKs too"))


def can(bench, r):
    b, pins = bench.b, bench.pins
    idle = (bit(pins.apply({}), 5), b.read(6))
    a_drives = (bit(pins.apply({10: 0}), 5), b.read(6))
    pins.apply({10: 1})
    b.drive(7, 0)
    b_drives = (bit(pins.apply({}), 5), b.read(6))
    b.drive(7, 1)
    board_a = r.check(idle[0] == 1 and a_drives[0] == 0,
                      ["CAN_TX", "CANA_CTX", "CANA_CRX", "CAN_RX"],
                      "header 10 low makes board A's R low on header 5",
                      "header 5 read %d idle and %d with header 10 low: board A on J4, R9, R10"
                      % (idle[0], a_drives[0]))
    board_b = r.check(idle[1] == 1 and b_drives[1] == 0, ["CANB_TX", "CANB_RX"],
                      "Pico B GP7 low makes board B's R low on GP6",
                      "GP6 read %d idle and %d with GP7 low: board B on J6" % (idle[1],
                                                                               b_drives[1]))
    if not (board_a and board_b):
        r.line("SKIP", ["CANH", "CANL"], "the bus needs both boards")
        return board_b
    r.check(a_drives[1] == 0 and b_drives[0] == 0, ["CANH", "CANL"],
            "each board's dominant reaches the other",
            "Pico B GP6 read %d with A dominant, header 5 %d with B dominant: the CANH and CANL "
            "jumpers from J5 and J7 to the boards" % (a_drives[1], b_drives[0]))
    return board_b


def swd(bench, r):
    s = demo_swd
    ack, value, parity = bench.pins.swd_dpidr([0xFFFF] + s.ALERT + [s.ACTIVATION],
                                              s.LINE_RESET, s.request(0, 0, 0xC), s.CORE0)
    good = parity == bin(value).count("1") & 1
    return r.check(ack == s.OK and value == s.DPIDR and good,
                   ["SWCLK", "SWCLK_PICO", "SWDIO", "SWDIO_PICO"],
                   "Pico B's core 0 answers DPIDR 0x%08x through J8" % value,
                   "DPIDR: ACK %s, 0x%08x, parity %s: the debug cable on J8 or R11, R12"
                   % (s.ack_name(ack), value, "good" if good else "bad"))


def flash(bench, r):
    nets = ["FLASH_CLK", "FLASH_DI", "FLASH_DO", "FLASH_CS_N"]
    jedec = bench.pins.jedec()
    if set(jedec) <= {0x00} or set(jedec) <= {0xFF}:
        r.line("SKIP", nets, "flash: not fitted (JEDEC ID %s)" % " ".join(
            "%02x" % b for b in jedec))
        return None
    part = demo_flash.PARTS.get(tuple(jedec))
    return r.check(part is not None, nets, "JEDEC ID %s: %s" % (
        " ".join("%02x" % b for b in jedec), part), "JEDEC ID %s is no part demo_flash knows: "
        "the breakout's seating or DI, CLK, DO swapped" % " ".join("%02x" % b for b in jedec))


def ds18b20(bench, r):
    rom = bench.pins.read_rom()
    if rom is None:
        return r.check(False, ["DQ"], "", "no presence pulse: U5's seating or its legs")
    t = demo_ds18b20
    return r.check(t.crc8(rom) == 0 and rom[0] == t.FAMILY, ["DQ"],
                   "DS18B20 ROM %s, CRC good" % " ".join("%02x" % b for b in rom),
                   "ROM %s: not a DS18B20's with a good CRC" % " ".join("%02x" % b for b in rom))


def ethernet(bench, r):
    pins = bench.pins
    txp = bit(pins.apply({38: 1}), 40)
    txn = bit(pins.apply({38: None, 40: 1}), 38)
    pins.apply({40: None})
    return r.check(txp == 1 and txn == 1, ["ETH_TXP", "ETH_TXP_J", "ETH_TXN_J", "ETH_TXN"],
                   "headers 38 and 40 reach each other through R14, R16 and R15",
                   "header 40 read %d with 38 high, 38 read %d with 40 high: R14, R16, R15"
                   % (txp, txn))


def edges(samples, channel):
    """The sample index of each change on one channel."""
    levels = samples.translate(bytes((b >> channel) & 1 for b in range(256)))
    found = []
    for pattern in (b"\x00\x01", b"\x01\x00"):
        at = levels.find(pattern)
        while at >= 0:
            found.append(at)
            at = levels.find(pattern, at + 1)
    return sorted(found)


def trains(rate, changes):
    """The spans of the pulse trains in a capture, whole ones only: the first and last
    may be cut by its ends."""
    every = sorted(p for c in changes for p in c)
    if not every:
        return []
    spans, start = [], every[0]
    for before, after in zip(every, every[1:]):
        if after - before > SPLIT_S * rate:
            spans.append((start, before))
            start = after
    spans.append((start, every[-1]))
    return spans[1:-1]


def analysers(bench, r, nets, pads):
    """Each pulsed net gets count pulses, its place in PULSED; each channel must see its
    net's in one train. Analyser A's D0 to D3 are the host port's SPI, which only has to
    move."""
    count = {}
    for i, (h, _) in enumerate(PULSED):
        count["CAN_RX" if h == 10 else pads["J1.%d" % h]] = i + 1
    plan = [(h, i + 1, level) for i, (h, level) in enumerate(PULSED)]
    whose = {n: net for net, n in count.items()}
    for name, header in ANALYSERS.items():
        rate, samples = bench.capture(
            name, lambda: bench.pins.pulses(plan, TRAINS, TRAIN_GAP_US))
        channel_nets = [pads.get("%s.%d" % (header, k + 1)) for k in range(8)]
        changes = [edges(samples, k) for k in range(8)]
        whole = trains(rate, [c for c, net in zip(changes, channel_nets) if net in count])
        if not whole:
            r.line("FAIL", [n for n in channel_nets if n in count],
                   "analyser %s sent %.0f ms with no whole pulse train: it stops early, "
                   "run again" % (name, 1000 * len(samples) / rate))
            continue
        start, end = whole[0]
        for channel, net in enumerate(channel_nets):
            where = "analyser %s D%d" % (name, channel)
            if net not in count:
                r.check(len(changes[channel]) > 0, [net],
                        "%s moves (%d edges)" % (where, len(changes[channel])),
                        "%s never moves: its probe" % where)
                continue
            seen = sum(start <= p <= end for p in changes[channel])
            want = count[net]
            other = whose.get(seen // 2) if seen % 2 == 0 else None
            got = "%s's %d pulses" % (other, seen // 2) if other else "no net's pulses"
            r.check(seen == 2 * want, [net], "%s sees its %d pulses" % (where, want),
                    "%s sees %d edges, %s, not %s's %d: its probe" % (
                        where, seen, got, net, want))


def run(bench, nets, button=True, with_analysers=False):
    """Every check, PASS when none fails."""
    pads = {pad: net for net, ps in nets.items() for pad in ps}
    names = {h: pads["J1.%d" % h] for h in HEADER}
    r = Report(nets, bench.say)
    if not host_port(bench, r):
        bench.say("FAIL")
        return False
    try:
        bench.a.let_go(8)
        pico_b(bench, r)
        shorts(bench, r, names)
        pulls = pull_ups(bench, r)
        pico_a(bench, r)
        rail_a = [eeprom(bench, r), ds18b20(bench, r), flash(bench, r)] + pulls[:4]
        rail_b = [can(bench, r), swd(bench, r), pulls[4]]
        ethernet(bench, r)
        r.line("SKIP", ["NEO_3V3", "NEO_5V", "NEO_DIN"],
               "no pin reads past U3's input: --analysers sees header 18, the stick the rest")
        if with_analysers:
            analysers(bench, r, nets, pads)
        r.check(any(rail_a), ["3V3_A"], "Pico A's 3V3 reaches the pull-ups and parts on it",
                "nothing on 3V3_A answers: Pico A's pin 36 or the rail")
        r.check(any(rail_b), ["3V3_B"], "Pico B's 3V3 reaches CAN board B and R13",
                "nothing on 3V3_B answers: Pico B's pin 36 or the rail")
        volts = bench.a.vsys()
        r.check(VSYS[0] <= volts <= VSYS[1], ["5V_A"],
                "Pico A's VSYS reads %.2f V, so its VBUS (pin 40) is up; D3 (red) says it "
                "reaches the carrier" % volts,
                "Pico A's VSYS reads %.2f V, outside %.1f to %.1f V: its USB supply" % (
                    volts, VSYS[0], VSYS[1]))
        # last, as it waits for a press
        if button:
            replug(bench, r)
        else:
            r.line("SKIP", ["REPLUG"], "--no-button: demo/carrier_check.py --button-only")
    finally:
        bench.pins.idle()
        for gp in (6, 7, 8, 9):
            bench.a.let_go(gp)
        for gp in (1, 2, 3, 6):
            bench.b.let_go(gp)
        bench.b.let_go(7, "up")
    bench.say("%d PASS, %d FAIL, %d SKIP" % (r.count("PASS"), r.count("FAIL"), r.count("SKIP")))
    bench.say("FAIL" if r.count("FAIL") else "PASS")
    return not r.count("FAIL")


class Repl:
    """A Pico's raw REPL over its USB serial port."""

    def __init__(self, serial):
        import serial as pyserial

        found = [p for p in glob.glob("/dev/serial/by-id/*")
                 if p.lower().endswith("_%s-if00" % serial.lower())]
        if not found:
            raise SystemExit("no Pico %s on USB" % serial)
        self.port = pyserial.Serial(found[0], 115200, timeout=0.1)
        self.port.write(b"\r\x03\x03")
        time.sleep(0.2)
        self.port.reset_input_buffer()
        self.port.write(b"\r\x01")
        self.until(b"raw REPL; CTRL-B to exit\r\n>", 5)

    def until(self, end, timeout):
        data, start = b"", time.monotonic()
        while not data.endswith(end):
            data += self.port.read(1)
            if time.monotonic() - start > timeout:
                raise RuntimeError("the Pico said %r, then nothing" % data[-200:])
        return data[:-len(end)]

    def exec(self, code, timeout=60):
        data = code.encode()
        for i in range(0, len(data), 256):
            self.port.write(data[i:i + 256])
            time.sleep(0.01)
        self.port.write(b"\x04")
        self.until(b"OK", 5)
        out, err = self.until(b"\x04", timeout), self.until(b"\x04", 5)
        self.until(b">", 5)
        if err:
            raise RuntimeError(err.decode(errors="replace"))
        return out.decode(errors="replace")

    def close(self):
        self.port.write(b"\x02")
        self.port.close()


class Remote:
    """An object on a Pico, its methods called through the REPL."""

    def __init__(self, repl, name):
        self.repl, self.name = repl, name

    def __getattr__(self, method):
        def call(*args):
            said = self.repl.exec("print(repr(%s.%s(*%r)))" % (self.name, method, args),
                                  CALL_S)
            return ast.literal_eval(said.strip())

        return call


def capture_with(evidence):
    def capture(analyser, action):
        """demo/capture.sh once, kept however short, while action runs."""
        path = evidence / ("analyser_%s.sr" % analyser)
        env = dict(os.environ, ANALYSER=analyser, RATE="1M", TRIES="1")
        done = subprocess.Popen(["demo/capture.sh", str(path), str(CAPTURE_MS)], cwd=ROOT,
                                env=env)
        time.sleep(0.5)
        action()
        done.wait()
        rate, _, samples = sigrok.read(path)
        return rate, samples

    return capture


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--analysers", action="store_true")
    parser.add_argument("--no-button", action="store_true")
    parser.add_argument("--button-only", action="store_true",
                        help="only SW1, on Pico A alone, any bitstream")
    parser.add_argument("--evidence", type=Path, default=Path.home() / (
        ".local/share/protocol-emulator/board-evidence/%s/carrier" % datetime.date.today()))
    args = parser.parse_args()
    serial_a = os.environ.get("PICO", "").removeprefix("id:")
    if not serial_a:
        raise SystemExit("PICO=id:<serial of Pico A>")
    serial_b = os.environ.get("PICO_B_SERIAL", PICO_B_SERIAL)
    args.evidence.mkdir(parents=True, exist_ok=True)
    source = (ROOT / "python/carrier_pins.py").read_text()
    a = Repl(serial_a)
    if args.button_only:
        a.exec(source)
        a.exec("gpio = Gpio()")
        r = Report(netlist()[0], lambda text: print(text, flush=True))
        replug(Bench(None, Remote(a, "gpio"), None, None, r.say), r)
        a.exec("gpio.let_go(9)")
        a.close()
        sys.exit(0 if r.count("PASS") else 1)
    try:
        b = Repl(serial_b)
    except RuntimeError:
        raise SystemExit("Pico B has no MicroPython REPL: demo/pico_b.sh micropython")
    try:
        a.exec(source)
        a.exec("pins = pico_a()\ngpio = Gpio()")
        b.exec(source)
        b.exec("gpio = Gpio()")
        bench = Bench(Remote(a, "pins"), Remote(a, "gpio"), Remote(b, "gpio"),
                      capture_with(args.evidence), lambda text: print(text, flush=True))
        ok = run(bench, netlist()[0], button=not args.no_button,
                 with_analysers=args.analysers)
    finally:
        a.close()
        b.close()
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
