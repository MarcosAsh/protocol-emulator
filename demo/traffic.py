# SPDX-License-Identifier: Apache-2.0
# Checks that a bench demo's capture holds the traffic the demo puts on the wire. Pico A's
# PASS only reflects what the chip told it, and a bus nobody answers can still end in a PASS.
# Each check reads DEMO.sr, sigrok's DEMO.decode (with demo/outside.sh's arguments) and
# Pico A's DEMO.log, which has the run's own values for demos that have them.
# Usage: python3 demo/traffic.py DEMO [DIR]   prints each thing missing and then FAIL

import re
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

import ffmpeg_referee
import sigrok

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "python"))
import demo_caliper  # noqa: E402
import demo_dali  # noqa: E402
import demo_dmx512  # noqa: E402
import demo_can  # noqa: E402
import demo_can_node  # noqa: E402
import demo_ds18b20  # noqa: E402
import demo_flash  # noqa: E402
import demo_ir_nec  # noqa: E402
import demo_ir_rc6  # noqa: E402
import demo_lfast  # noqa: E402
import demo_lin  # noqa: E402
import demo_microwire  # noqa: E402
import demo_nec  # noqa: E402
import demo_neopixel  # noqa: E402
import demo_referee  # noqa: E402
import demo_spdif  # noqa: E402
import demo_spdif_ac3  # noqa: E402
import demo_swd  # noqa: E402
import demo_swd_blind  # noqa: E402
import demo_tdm_audio  # noqa: E402
import demo_usb_power_delivery  # noqa: E402
import demo_wiegand  # noqa: E402
import demo_xy2_100  # noqa: E402
import pio_firmware  # noqa: E402


def typed(text):
    """Returns what demo_usb says it typed, one key per line."""
    return "".join(re.findall(r"^typed (.)\r?$", text, re.MULTILINE))


def line(samples, channel):
    """Returns one channel's edge count and its first and last level."""
    levels = samples.translate(bytes((b >> channel) & 1 for b in range(256)))
    if not levels:
        return 0, None, None
    return levels.count(b"\x00\x01") + levels.count(b"\x01\x00"), levels[0], levels[-1]


def exactly(decoded, expected, what):
    """Returns the first line where decoded differs from expected, or the count if one runs out first."""
    for n, (got, want) in enumerate(zip(decoded, expected)):
        if got != want:
            return ["%s: decode line %d reads %r, expected %r" % (what, n + 1, got, want)]
    if len(decoded) != len(expected):
        return ["%s: the decode has %d lines, expected %d" % (what, len(decoded), len(expected))]
    return []


def crc15(bits):
    """Computes CAN's CRC-15 (x^15 + x^14 + x^10 + x^8 + x^7 + x^4 + x^3 + 1) from SOF to the data."""
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
    """Returns sigrok's lines for a standard frame. sigrok 0.5.3 reads a remote frame's DLC
    worth of bytes as data (test/traces/sigrok/can_remote.trace): the CRC, its delimiter and
    the ACK slot with the recessive bits after it, so the frame's ACK lands in the CRC it
    reads."""
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
    """Builds frames as (id, rtr, dlc, data), each ACKed, with the bus idle recessive around them."""
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
    """Returns demo_referee.auto's frames when every cheat is caught: the score after each
    catch, and a green sweep once the honest frames pass SWEEP_EVERY."""
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
    """Returns the reads and writes that demo_eeprom logs, with the values it logs. sigrok
    warns about each address-only probe and each NACK during ACK polling; both are expected."""

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


def in_order(decoded, expected, what):
    """Returns the first expected line that the decode lacks after the previous one."""
    at = 0
    for want in expected:
        try:
            at = decoded.index(want, at) + 1
        except ValueError:
            return ["%s: no %r in the decode%s" % (
                what, want, " after the ones before it" if at else "")]
    return []


def run_of(decoded, expected, what):
    """Returns the first line where the decode differs from expected, unless expected
    appears in it as one unbroken run. Ignores whatever the decoder reads before it because
    a line idled from reset."""
    starts = [i for i, got in enumerate(decoded) if got == expected[0]]
    if any(decoded[i:i + len(expected)] == expected for i in starts):
        return []
    if not starts:
        return ["%s: no %r in the decode" % (what, expected[0])]
    return exactly(decoded[starts[0]:starts[0] + len(expected)], expected, what)


def ds18b20(_levels):
    """Rechecks Pico A's readback from its log: both CRCs, the family, and a temperature
    the part can read that isn't its power-on 85 C. Then checks the same ROM and scratchpad
    appear in the decode of DQ, after READ ROM, CONVERT T and READ SCRATCHPAD."""

    def judge(decoded, log):
        t = demo_ds18b20
        rom = re.search(r"^ROM ((?:\w\w ){7}\w\w):", log, re.M)
        pad = re.search(r"^scratchpad ((?:\w\w ){8}\w\w):", log, re.M)
        if not rom or not pad:
            return ["Pico A's log has no ROM and scratchpad read back"]
        rom = [int(b, 16) for b in rom.group(1).split()]
        pad = [int(b, 16) for b in pad.group(1).split()]
        raw = t.temperature(pad)
        problems = []
        if t.crc8(rom) or rom[0] != t.FAMILY:
            problems.append("ROM %s: not a DS18B20's with a good CRC" % t.bench.hexs(rom))
        if t.crc8(pad) or pad[4] & t.CONFIG_MASK != t.CONFIG_FIXED:
            problems.append("scratchpad %s: bad CRC or configuration" % t.bench.hexs(pad))
        if raw == t.POWER_ON or not -55 * 16 <= raw <= 125 * 16:
            problems.append("scratchpad reads %.4f C, the power-on value or out of range"
                            % (raw / 16))
        serial = sum(b << (8 * i) for i, b in enumerate(rom))
        presence, skip = "Reset/presence: true", "ROM command: 0xcc 'Skip ROM'"
        expected = [presence, "ROM command: 0x33 'Read ROM'", "ROM: 0x%016x" % serial,
                    presence, skip, "Data: 0x44", presence, skip, "Data: 0xbe"]
        expected += ["Data: 0x%02x" % b for b in pad]
        return problems + in_order(decoded, ["onewire_network-1: " + x for x in expected],
                                   "READ ROM, CONVERT T, READ SCRATCHPAD")

    return judge


def swd(_levels):
    """Expects core 0's and core 1's DPIDR and AP 0's IDR, each read with an OK. sigrok's
    SWD decoder misreads the dormant wake and TARGETSEL, so only reads are checked."""

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


def pio_ws2812(_levels):
    frames = pio_firmware.WS2812["data"]
    return lambda decoded, _log: exactly(decoded, stick(frames), "two frames")


def pio_spi(_levels):
    def judge(decoded, _log):
        jedec = re.compile(r"spiflash-1: (Manufacturer ID|Memory type|Device ID): ")
        ident = [d for d in decoded if jedec.match(d)]
        expected = ["spiflash-1: Manufacturer ID: 0xef", "spiflash-1: Memory type: 0x40",
                    "spiflash-1: Device ID: 0x17"]
        return exactly(ident, expected, "a W25Q64JV's JEDEC ID")

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


def pio_uart_tx(_levels):
    data = pio_firmware.UART_TX["data"].encode()
    return lambda decoded, _log: uart(data, "uart_tx.c's string")(decoded)


def keyboard(_levels):
    def judge(decoded, log):
        keys = typed(log)
        if not keys:
            return ["Pico A's log has no keys typed to hold the decode to"]
        return uart(keys.encode(), "the keys typed")(decoded)

    return judge


def nec(_levels):
    expected = demo_nec.lines(demo_nec.KEYS)
    return lambda decoded, _log: exactly(decoded, expected, "the keys sent")


def microwire(_levels):
    expected = demo_microwire.lines(demo_microwire.FRAMES)
    return lambda decoded, _log: exactly(decoded, expected, "the frames' DI")


def xy2_100(_levels):
    """Returns the setpoints in order, then the last one again, because SENDCK keeps running until the halt."""
    expected = demo_xy2_100.lines(demo_xy2_100.WORDS)
    last = demo_xy2_100.frame(demo_xy2_100.WORDS[-1])

    def judge(decoded, _log):
        again = max(1, (len(decoded) - len(expected)) // len(last))
        return exactly(decoded, expected + last * again, "the setpoints")

    return judge


def caliper(_levels):
    expected = demo_caliper.lines(demo_caliper.FRAMES)
    return lambda decoded, _log: exactly(decoded, expected, "the positions sent")


def lfast(_levels):
    expected = demo_lfast.lines(demo_lfast.WORDS)
    return lambda decoded, _log: exactly(decoded, expected, "the payloads sent")


def ir_rc6(_levels):
    expected = demo_ir_rc6.lines(demo_ir_rc6.FRAMES)
    return lambda decoded, _log: exactly(decoded, expected, "the frames sent")


def tdm_audio(_levels):
    """Returns the frame of samples, then silence one channel at a time until the halt."""
    words = demo_tdm_audio.WORDS

    def judge(decoded, _log):
        expected = demo_tdm_audio.lines(words, max(0, len(decoded) - len(words)))
        return exactly(decoded, expected, "the samples sent")

    return judge


# the held-out protocols (test/heldout.txt): each demo's own values, as sigrok prints them
def dali(_levels):
    expected = demo_dali.lines(demo_dali.FRAMES)
    return lambda decoded, _log: exactly(decoded, expected, "the frames sent")


def dmx512(_levels):
    expected = demo_dmx512.lines(demo_dmx512.CHANNELS)
    return lambda decoded, _log: run_of(decoded, expected, "the packet sent")


def spdif(_levels):
    expected = demo_spdif.lines(demo_spdif.WORDS)
    return lambda decoded, _log: run_of(decoded, expected, "the samples sent")


def spdif_ac3(_levels):
    """The words of OWN's reader hold the burst, and FFmpeg finds the frame sent in them."""
    expected = ffmpeg_referee.lines(demo_spdif_ac3.BURST)

    def judge(decoded, _log):
        return (run_of(decoded, expected, "the burst sent")
                or ffmpeg_referee.problems([int(word, 16) for word in decoded]))

    return judge


def usb_power_delivery(_levels):
    m = demo_usb_power_delivery
    expected = m.lines(m.HEADER, m.PDOS)
    return lambda decoded, _log: exactly(decoded, expected, "the message sent")


def wiegand(_levels):
    expected = demo_wiegand.lines(demo_wiegand.WORDS)
    return lambda decoded, _log: run_of(decoded, expected, "the card sent")


def ir_nec(_levels):
    expected = demo_ir_nec.lines()
    return lambda decoded, _log: exactly(decoded, expected, "the frame and repeat code sent")


def lin(_levels):
    expected = demo_lin.lines(demo_lin.WORDS[1])
    return lambda decoded, _log: exactly(decoded, expected, "the header sent")


def swd_blind(_levels):
    expected = demo_swd_blind.lines(0x0BC12477)
    return lambda decoded, _log: in_order(decoded, expected, "the DPIDR read")


def sweep(levels):
    """OUT0 echoes wire 20, so it has at least every edge the chip stamped."""
    edges = levels[4][0]

    def judge(_decoded, log):
        # the fields: firmware, watch, edges, exact, within, out, faults of both engines, verdict
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
# the 74AHCT125's input, which is not DIN
NEO = {4: "NEO_3V3"}
OUT0 = {4: "OUT0"}
# each demo's analyser channels on the bench (all must move), and its check
CHECKS = {
    "can": (CAN_R, can),
    "can_node": (CAN_R, can_node),
    "neopixel": (NEO, neopixel),
    "referee": (NEO, referee),
    "flash": ({0: "SCK", 1: "MOSI", 2: "MISO", 3: "CS"}, flash),
    "eeprom": (I2C, eeprom),
    "eeprom_stretch": (I2C, eeprom),
    "ds18b20": ({5: "DQ"}, ds18b20),
    "swd": ({6: "SWCLK", 7: "SWDIO"}, swd),
    "start_hold": (I2C, start_hold),
    "self_timing": (OUT0, self_timing),
    "keyboard": (OUT0, keyboard),
    "nec": (OUT0, nec),
    "sweep": (OUT0, sweep),
    "pio_ws2812": (NEO, pio_ws2812),
    "pio_uart_tx": (OUT0, pio_uart_tx),
    "pio_spi": ({0: "SCK", 1: "MOSI", 2: "MISO", 3: "CS"}, pio_spi),
    "microwire": ({0: "SK", 1: "DI", 3: "CS"}, microwire),
    "xy2_100": ({4: "SENDCK", 1: "SYNC", 3: "DATA"}, xy2_100),
    "caliper": ({4: "CLK", 6: "DATA"}, caliper),
    "lfast": (OUT0, lfast),
    "ir_rc6": (OUT0, ir_rc6),
    "tdm_audio": ({4: "SCLK", 1: "FSYNC", 3: "SDATA"}, tdm_audio),
    "dali": (OUT0, dali),
    "dmx512": (OUT0, dmx512),
    "spdif": (OUT0, spdif),
    "spdif_ac3": (OUT0, spdif_ac3),
    "usb_power_delivery": (OUT0, usb_power_delivery),
    "wiegand": ({4: "DATA0", 5: "DATA1, CAN board A's R"}, wiegand),
    "ir_nec": (OUT0, ir_nec),
    "lin": ({7: "LIN, IO5"}, lin),
    "swd_blind": ({6: "SWCLK", 7: "SWDIO"}, swd_blind),
}


# sigrok's spdif takes its clock from the first pulses it sees, and a line that stays low
# from reset until the firmware starts throws it off for good. So we decode these the way
# demo/decode.py joins their traces: starting once the channel has idled high for the
# trace's joins_after (in 48 MHz cycles, see test/traces/spdif.trace). Saved as
# DEMO.joined.decode.
JOINED = {"spdif": (4, 34)}


def joined(name, rate, samples):
    """Returns sigrok's decode of the capture, using the demo's outside: arguments, starting
    once channel JOINED[name] has idled high long enough, or None if it never does."""
    bit, cycles = JOINED[name]
    count = round(cycles * rate / 48e6)
    levels = samples.translate(bytes((b >> bit) & 1 for b in range(256)))
    at = levels.find(b"\x01" * count)
    if at < 0:
        return None
    script = Path(__file__).resolve().parent.parent / "python" / ("demo_%s.py" % name)
    args = re.search(r"^# outside: .*decode=(.*)$", script.read_text(), re.M).group(1)
    with tempfile.TemporaryDirectory() as scratch:
        path = Path(scratch) / "joined.sr"
        sigrok.write(path, rate, samples[at + count:])
        return subprocess.run(["sigrok-cli", "-i", str(path), *args.split()],
                              capture_output=True, text=True).stdout


def joined_decode(name, d, rate, samples):
    """Returns joined()'s lines, saving them beside the capture."""
    out = joined(name, rate, samples)
    if out is None:
        return []
    (d / (name + ".joined.decode")).write_text(out)
    return out.splitlines()


# sigrok's spdif misreads the AC-3 burst, so demo/ffmpeg_referee.py reads these by run
# length, one word a line. Saved as DEMO.words.
OWN = {"spdif_ac3": ffmpeg_referee.captured}


def own(name, rate, samples):
    return ffmpeg_referee.lines(OWN[name](samples, rate))


def stem(demo):
    """Returns the name of a demo's files (both start hold demos write start_hold.*)."""
    return "start_hold" if demo.startswith("start_hold") else demo


def check(demo, directory):
    """Returns what the demo's capture in directory lacks. Empty if it holds the demo's
    traffic, or if the demo puts none on a wire the analyser sees."""
    name = stem(demo)
    d = Path(directory)
    if name not in CHECKS:
        return []
    if not (d / (name + ".sr")).exists():
        return ["no capture %s" % (d / (name + ".sr"))]
    try:
        rate, _, samples = sigrok.read(d / (name + ".sr"))
    except (OSError, KeyError, ValueError, zipfile.BadZipFile) as e:
        return ["the capture %s does not read: %s" % (d / (name + ".sr"), e)]
    levels = lines(name, samples)
    decode, log = d / (name + ".decode"), d / (name + ".log")
    decoded = decode.read_text(errors="replace").splitlines() if decode.exists() else []
    if name in JOINED:
        decoded = joined_decode(name, d, rate, samples)
    if name in OWN:
        decoded = own(name, rate, samples)
        (d / (name + ".words")).write_text("".join(line + "\n" for line in decoded))
    del samples
    return judge(name, levels, decoded, log.read_text(errors="replace") if log.exists() else "")


def lines(name, samples):
    """Returns line() for each of the demo's analyser channels."""
    return {c: line(samples, c) for c in CHECKS[name][0]}


def judge(name, levels, decoded, log):
    """Returns what the demo's traffic lacks, judging by its channels' lines(), sigrok's
    decode and Pico A's log."""
    channels, make = CHECKS[name]
    # a line that never moves explains everything the decode lacks
    stuck = ["D%d (%s) never changes in the capture: %s throughout" % (
        c, what, "no samples" if first is None else "high" if first else "low")
        for c, what in channels.items() for edges, first, _ in [levels[c]] if not edges]
    if stuck:
        return stuck
    return make(levels)(decoded, log)


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
