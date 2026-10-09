# SPDX-License-Identifier: Apache-2.0
# Whether a bench demo's capture holds the traffic the demo puts on the wire. Pico A's PASS
# is only what the chip told it, and a bus nobody answers can still end in one. A check
# reads DEMO.sr, sigrok's DEMO.decode (demo/outside.sh's arguments) and Pico A's DEMO.log,
# which gives the run's own values where a demo has them.
# Usage: python3 demo/traffic.py DEMO [DIR]   prints each thing missing and then FAIL

import re
import sys
import zipfile
from pathlib import Path

import sigrok

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "python"))
import demo_can  # noqa: E402
import demo_can_node  # noqa: E402
import demo_flash  # noqa: E402
import demo_neopixel  # noqa: E402
import demo_referee  # noqa: E402
import demo_swd  # noqa: E402


def typed(text):
    """What demo_usb says it typed, a key a line."""
    return "".join(re.findall(r"^typed (.)\r?$", text, re.MULTILINE))


def line(samples, channel):
    """One channel's edge count and its first and last level."""
    levels = samples.translate(bytes((b >> channel) & 1 for b in range(256)))
    if not levels:
        return 0, None, None
    return levels.count(b"\x00\x01") + levels.count(b"\x01\x00"), levels[0], levels[-1]


def exactly(decoded, expected, what):
    """The first line where decoded is not expected, or the count when one runs out."""
    for n, (got, want) in enumerate(zip(decoded, expected)):
        if got != want:
            return ["%s: decode line %d reads %r, expected %r" % (what, n + 1, got, want)]
    if len(decoded) != len(expected):
        return ["%s: the decode has %d lines, expected %d" % (what, len(decoded), len(expected))]
    return []


def in_order(decoded, expected, what):
    """The first expected line the decode does not have after the one before it."""
    at = 0
    for want in expected:
        try:
            at = decoded.index(want, at) + 1
        except ValueError:
            return ["%s: no %r in the decode%s" % (
                what, want, " after the ones before it" if at else "")]
    return []


def crc15(bits):
    """CAN's CRC-15, x^15 + x^14 + x^10 + x^8 + x^7 + x^4 + x^3 + 1, over SOF to the data."""
    crc = 0
    for bit in bits:
        top = ((crc >> 14) & 1) ^ bit
        crc = (crc << 1) & 0x7FFF
        if top:
            crc ^= 0x4599
    return crc


def bits(value, width):
    return [(value >> (width - 1 - i)) & 1 for i in range(width)]


def can_lines(ident, rtr, dlc, data, acked):
    """sigrok's lines for a standard frame. sigrok 0.5.3 reads a remote frame's DLC of bytes
    as data (test/traces/sigrok/can_remote.trace): the CRC, its delimiter and the ACK slot
    with the recessive bits after it, so the frame's ACK lands in the CRC it reads."""
    fields = [0] + bits(ident, 11) + [rtr, 0, 0] + bits(dlc, 4)
    crc = crc15(fields + sum((bits(b, 8) for b in data), []))
    out = ["can-1: Identifier: %d (0x%x)" % (ident, ident), "can-1: Data length code: %d" % dlc]
    if rtr:
        after = bits(crc, 15) + [1, 0 if acked else 1] + [1] * 32
        data = [int("".join(map(str, after[8 * i:8 * i + 8])), 2) for i in range(dlc)]
        crc = int("".join(map(str, after[8 * dlc:8 * dlc + 15])), 2)
        acked = not after[8 * dlc + 16]
    out += ["can-1: Data byte %d: 0x%02x" % (i, b) for i, b in enumerate(data)]
    return out + ["can-1: CRC-15 sequence: 0x%04x" % crc,
                  "can-1: ACK slot: %s" % ("ACK" if acked else "NACK")]


def can_bus(levels, frames):
    """frames as (id, rtr, dlc, data), each ACKed, and the bus idle recessive around them."""
    _, first, last = levels[5]
    problems = ["D5 (CAN R) is dominant at the capture's %s: the bus does not idle recessive" % at
                for at, level in (("start", first), ("end", last)) if not level]

    def judge(decoded, _log):
        expected = sum((can_lines(*f, acked=True) for f in frames), [])
        return problems + exactly(decoded, expected, "%d frames, each ACKed" % len(frames))

    return judge


def can(levels):
    return can_bus(levels, [(i, 0, len(d), d) for i, d in demo_can.FRAMES])


def can_node(levels):
    sent = [(i, 0, len(d), d) for i, d in demo_can_node.FRAMES]
    return can_bus(levels, sent + demo_can_node.REPLIES)


def stick(frames):
    out = []
    for pixels in frames:
        out += ["rgb_led_ws281x-1: #%02x%02x%02x" % p for p in pixels] + ["rgb_led_ws281x-1: RESET"]
    return out


def neopixel(_levels):
    p = demo_neopixel.PIXELS
    return lambda decoded, _log: exactly(decoded, stick([p, p[1:] + p[:1]]), "two frames")


def referee(_levels):
    """demo_referee.auto's frames when every cheat is caught: the score after each catch,
    and a green sweep once the honest frames pass SWEEP_EVERY."""
    r = demo_referee
    frames, honest = [], 0
    for caught in range(r.AUTO_CHEATS):
        before, honest = honest, honest + r.AUTO_FRAMES
        if honest // r.SWEEP_EVERY > before // r.SWEEP_EVERY:
            frames += r.sweep() + [r.score(caught)]
        frames.append(r.score(caught + 1))
    return lambda decoded, _log: exactly(decoded, stick(frames), "every cheat's score")


def flash(_levels):
    def judge(decoded, _log):
        ident = [re.match(r"spiflash-1: (?:Manufacturer ID|Memory type|Device ID): 0x(..)$", d)
                 for d in decoded]
        jedec = tuple(int(m.group(1), 16) for m in ident if m)
        problems = [] if jedec in demo_flash.PARTS else [
            "JEDEC ID: the decode reads %s, not a part demo_flash knows" % (jedec,)]
        at = "0x%06x" % demo_flash.SECTOR
        page = "(addr %s, %d bytes): " % (at, demo_flash.PAGE)
        blank = "spiflash-1: Read data " + page + " ".join(["ff"] * demo_flash.PAGE)
        data = " ".join("%02x" % b for b in demo_flash.pattern())
        erase = "spiflash-1: Erase sector %d (%s)" % (demo_flash.SECTOR, at)
        expected = [erase, blank, "spiflash-1: Page program " + page + data,
                    "spiflash-1: Read data " + page + data, erase, blank]
        step = re.compile(r"spiflash-1: (Erase sector|Read data \(|Page program \()")
        steps = [d for d in decoded if step.match(d)]
        return problems + exactly(steps, expected, "erase, program, read back, erase")

    return judge


def eeprom(_levels):
    """The reads and writes demo_eeprom logs, with the values it logs. sigrok warns of each
    address-only probe and each NACK of the ACK polling, which are expected."""

    def judge(decoded, log):
        byte = re.search(r"^byte write 0x(\w+): (\w\w) -> (\w\w)", log, re.M)
        page = re.search(r"^page write 0x(\w+), (\d+) bytes from (\w\w)", log, re.M)
        if not byte or not page:
            return ["Pico A's log has no byte write and page write to hold the decode to"]
        b, old, new = int(byte.group(1), 16), byte.group(2).upper(), byte.group(3).upper()
        p, count, seed = int(page.group(1), 16), int(page.group(2)), int(page.group(3), 16)
        data = " ".join("%02X" % ((seed + 13 * i) & 0xFF) for i in range(count))
        lines = ["Sequential random read (addr=%04X, 1 byte): %s" % (b, old),
                 "Page write (addr=%04X, 1 byte): %s" % (b, new),
                 "Sequential random read (addr=%04X, 1 byte): %s" % (b, new),
                 "Sequential random read (addr=%04X, 1 byte): %02X" % (p, (seed - 1) & 0xFF),
                 "Page write (addr=%04X, %d bytes): %s" % (p, count, data),
                 "Sequential random read (addr=%04X, %d bytes): %s" % (p, count, data)]
        steps = [d for d in decoded if re.search(r"\(addr=\w+, \d+ bytes?\)", d)]
        return exactly(steps, ["eeprom24xx-1: " + x for x in lines], "the logged writes and reads")

    return judge


def ds18b20(_levels):
    def judge(decoded, log):
        rom = re.search(r"^ROM ((?:\w\w ){7}\w\w):", log, re.M)
        pad = re.search(r"^scratchpad ((?:\w\w ){8}\w\w):", log, re.M)
        if not rom or not pad:
            return ["Pico A's log has no ROM and scratchpad to hold the decode to"]
        serial = sum(int(b, 16) << (8 * i) for i, b in enumerate(rom.group(1).split()))
        presence, skip = "Reset/presence: true", "ROM command: 0xcc 'Skip ROM'"
        expected = [presence, "ROM command: 0x33 'Read ROM'", "ROM: 0x%016x" % serial,
                    presence, skip, "Data: 0x44", presence, skip, "Data: 0xbe"]
        expected += ["Data: 0x%s" % b for b in pad.group(1).split()]
        return in_order(decoded, ["onewire_network-1: " + x for x in expected],
                        "READ ROM, CONVERT T, READ SCRATCHPAD")

    return judge


def swd(_levels):
    """Core 0's and core 1's DPIDR and AP 0's IDR, each read with an OK. sigrok's SWD
    decoder misreads the dormant wake and TARGETSEL, so only reads are held to it."""

    def judge(decoded, log):
        idr = re.search(r"^AP 0 IDR 0x(\w{8})", log, re.M)
        if not idr:
            return ["Pico A's log has no AP 0 IDR to hold the decode to"]
        reads = [(op, value) for op, ack, value in zip(decoded, decoded[1:], decoded[2:])
                 if ack == "swd-1: OK" and value.startswith("swd-1: 0x")]
        dpidr = ("swd-1: IDCODE", "swd-1: 0x%08x" % demo_swd.DPIDR)
        times = reads.count(dpidr)
        problems = [] if times >= 2 else [
            "DPIDR 0x%08x read OK %d times, expected one a core" % (demo_swd.DPIDR, times)]
        if ("swd-1: RDBUFF", "swd-1: 0x" + idr.group(1)) not in reads:
            problems.append("no RDBUFF read OK of AP 0's IDR 0x%s" % idr.group(1))
        return problems

    return judge


def start_hold(_levels):
    def judge(decoded, log):
        stamped = re.search(r"^chip, engine 1: (\d+) STARTs", log, re.M)
        if not stamped:
            return ["Pico A's log has no STARTs the chip stamped to hold the decode to"]
        seen = sum(d in ("i2c-1: Start", "i2c-1: Start repeat") for d in decoded)
        if seen < int(stamped.group(1)):
            return ["the decode has %d STARTs, fewer than the %s the chip stamped" % (
                seen, stamped.group(1))]
        return []

    return judge


def uart(data, what):
    return lambda decoded: exactly(decoded, ["uart-1: %02X" % b for b in data], what)


def self_timing(_levels):
    def judge(decoded, log):
        sent = [int(b, 16) for b in re.findall(r"^'.' 0x(\w\w) ", log, re.M)]
        if not sent:
            return ["Pico A's log has no bytes sent to hold the decode to"]
        return uart(sent, "the bytes of both tables")(decoded)

    return judge


def keyboard(_levels):
    def judge(decoded, log):
        keys = typed(log)
        if not keys:
            return ["Pico A's log has no keys typed to hold the decode to"]
        return uart(keys.encode(), "the keys typed")(decoded)

    return judge


def sweep(levels):
    """OUT0 echoes wire 20, so it has at least every edge the chip stamped."""
    edges = levels[4][0]

    def judge(_decoded, log):
        # firmware, watch, edges, exact, within, out, the faults of both engines, verdict
        row = r"^\w+\s+\w+\s+(\d+)\s+\d+\s+\d+\s+\d+\s+\d+ \d+\s+(?:PASS|FAIL)$"
        rows = re.findall(row, log, re.M)
        if not rows:
            return ["Pico A's log has no sweep table to hold the capture to"]
        stamped = sum(map(int, rows))
        return [] if edges >= stamped else [
            "D4 (OUT0) has %d edges, fewer than the %d the chip stamped" % (edges, stamped)]

    return judge


CAN_R = {5: "CAN R, low is dominant"}
I2C = {6: "SDA", 7: "SCL"}
DIN = {4: "the stick's DIN"}
OUT0 = {4: "OUT0"}
# each demo's analyser channels, all of which must move, and its check
CHECKS = {
    "can": (CAN_R, can),
    "can_node": (CAN_R, can_node),
    "neopixel": (DIN, neopixel),
    "referee": (DIN, referee),
    "flash": ({0: "SCK", 1: "MOSI", 2: "MISO", 3: "CS"}, flash),
    "eeprom": (I2C, eeprom),
    "eeprom_stretch": (I2C, eeprom),
    "ds18b20": ({5: "1-Wire DQ"}, ds18b20),
    "swd": ({6: "SWCLK", 7: "SWDIO"}, swd),
    "start_hold": (I2C, start_hold),
    "self_timing": (OUT0, self_timing),
    "keyboard": (OUT0, keyboard),
    "sweep": (OUT0, sweep),
}


def stem(demo):
    """The name of a demo's files: both start hold demos write start_hold.*."""
    return "start_hold" if demo.startswith("start_hold") else demo


def check(demo, directory):
    """What the demo's capture in directory lacks, empty when it holds the demo's traffic or
    the demo puts none on a wire the analyser sees."""
    name = stem(demo)
    if name not in CHECKS:
        return []
    channels, make = CHECKS[name]
    d = Path(directory)
    if not (d / (name + ".sr")).exists():
        return ["no capture %s" % (d / (name + ".sr"))]
    try:
        _, _, samples = sigrok.read(d / (name + ".sr"))
    except (OSError, KeyError, ValueError, zipfile.BadZipFile) as e:
        return ["the capture %s does not read: %s" % (d / (name + ".sr"), e)]
    levels = {c: line(samples, c) for c in channels}
    del samples
    # a line that never moves explains whatever the decode lacks
    stuck = ["D%d (%s) never changes in the capture: %s throughout" % (
        c, what, "no samples" if first is None else "high" if first else "low")
        for c, what in channels.items() for edges, first, _ in [levels[c]] if not edges]
    if stuck:
        return stuck
    judge = make(levels)
    decode, log = d / (name + ".decode"), d / (name + ".log")
    decoded = decode.read_text(errors="replace").splitlines() if decode.exists() else []
    return judge(decoded, log.read_text(errors="replace") if log.exists() else "")


def main():
    if len(sys.argv) not in (2, 3):
        sys.exit("usage: %s DEMO [DIR]" % sys.argv[0])
    demo, directory = sys.argv[1], sys.argv[2] if len(sys.argv) == 3 else "."
    problems = check(demo, directory)
    for problem in problems:
        print("traffic: " + problem)
    if problems:
        print("FAIL")
    elif stem(demo) in CHECKS:
        print("traffic: the capture holds the demo's")


if __name__ == "__main__":
    main()
