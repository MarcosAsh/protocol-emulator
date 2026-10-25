# SPDX-License-Identifier: Apache-2.0
# The standard rates the organisers named, on the bench: SPI modes 0 to 3 and I2C at 100 kHz
# and 400 kHz, each from a fresh load of BITSTREAM. python/demo_rates.py runs one of them on
# Pico A (the flash for SPI, the EEPROM for I2C) while analyser B captures, then the capture
# is held to its protocol: SPI to its mode's sampling edge and the bytes sent, I2C to
# UM10204's Table 11 (demo/i2c_timing.py) and the EEPROM's reads and writes. Each run keeps
# its capture, Pico log, sigrok decode, verdict and SHA256SUMS in EVIDENCE/<date>/sweep-rates/
# <run>/, and adds a line to demo/ledger.tsv. Pico B, if plugged in, runs MicroPython.
# Usage: PICO=id:<serial of Pico A> python3 demo/sweep_rates.py BITSTREAM [--only RUN]...
#            [--rate 24M] [--dry-run]
#        python3 demo/sweep_rates.py --self-check    judges synthetic captures, no hardware

import argparse
import datetime
import os
import statistics
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path

import i2c_timing
import ledger
import numpy as np
import sigrok
import traffic

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "python"))
import both_roles_firmware  # noqa: E402

# the bench's 48 MHz, and test/bench.ml's spi_half: SCK is 3 MHz
CLOCK_HZ = 48_000_000
SPI_HALF = 8
# analyser B: SCK D0, MOSI D1, MISO D2, CS D3 for the flash; SDA D6, SCL D7 for the EEPROM
SCK, MOSI, MISO, CS = 0, 1, 2, 3
# the USB port analyser B sits on, unless the environment says otherwise
ANALYSER_B_PORT = "3-3.1.3.3"
# the measured clock must be within this of what the firmware makes
RATE_TOLERANCE = 0.10
# files Pico A needs, as demo/rates.sh copies them
FILES = ["python/protocol_emulator.py", "python/pico_board.py", "python/bench.py",
         "python/bench_firmware.py", "python/both_roles_firmware.py", "python/demo_eeprom.py",
         "python/demo_flash.py", "python/demo_rates.py"]
JEDEC = [0x9F, 0, 0, 0]
FLASH_ID = [0xEF, 0x40, 0x17]


@dataclass(frozen=True)
class Run:
    name: str
    # spi: the mode as a number; i2c: both_roles_firmware's name and UM10204's mode
    protocol: str
    mode: int | str
    capture_ms: int


RUNS = [Run("spi_mode%d" % n, "spi", n, 2500) for n in range(4)] + [
    Run("i2c_100k", "i2c", "standard", 4000), Run("i2c_400k", "i2c", "fast", 4000)]
NAMES = [r.name for r in RUNS]
I2C_FIRMWARE = {"standard": "i2c_standard", "fast": "i2c_fast"}


def bit(samples, channel):
    return (np.frombuffer(samples, dtype=np.uint8) >> channel) & 1


def changes(level):
    """The index of every sample whose level differs from the one before."""
    return np.flatnonzero(np.diff(level)) + 1


@dataclass
class Frame:
    mosi: list
    miso: list
    bits: int
    setup: int
    hold: int
    # the median samples between leading edges, each frame's
    period: float
    idle_ok: bool
    first_ok: bool


def frames(samples, mode):
    """Every CS-low frame of an SPI capture read at the mode's sampling edge: the bytes on
    MOSI and MISO, the least samples MOSI sat steady before and after a sampling edge, the
    samples of a clock period, and whether SCK idled at CPOL and left it first."""
    cpol, cpha = mode >> 1, mode & 1
    clk, mosi, miso, cs = (bit(samples, c) for c in (SCK, MOSI, MISO, CS))
    moves = changes(mosi)
    moved = changes(cs)
    falls = [i for i in moved if cs[i] == 0]
    out = []
    for start in falls:
        ends = [i for i in moved if i > start and cs[i] == 1]
        end = ends[0] if ends else len(cs)
        edges = [i for i in changes(clk) if start <= i < end]
        idle = clk[start] == cpol and clk[max(start - 1, 0)] == cpol
        if not edges:
            continue
        first = clk[edges[0]] != cpol
        sample = edges[cpha::2]
        before = [int(i - moves[moves <= i].max()) if (moves <= i).any() else 1 << 30
                  for i in sample]
        after = [int(moves[moves > i].min() - i) if (moves > i).any() else 1 << 30
                 for i in sample]
        # the median, as the firmware's pull between words stretches a few periods
        leading = edges[::2]
        period = statistics.median(b - a for a, b in zip(leading, leading[1:])) if len(leading) > 1 else 0
        bytes_ = []
        for line in (mosi, miso):
            bits = [int(line[i]) for i in sample]
            bytes_.append([int("".join(map(str, bits[k:k + 8])), 2)
                           for k in range(0, len(bits) - 7, 8)])
        out.append(Frame(bytes_[0], bytes_[1], len(sample), min(before), min(after), period,
                         bool(idle), bool(first)))
    return out


def spi_problems(path, mode, decode=""):
    """What an SPI run's capture lacks: the clock's idle level and first edge, its rate, MOSI
    steady a sample either side of the sampling edge, the JEDEC command sent, and in modes
    0 and 3 the flash's ID answered."""
    rate, _, samples = sigrok.read(path)
    found = frames(samples, mode)
    if not found:
        return ["no frame: CS never fell in the capture"]
    problems = []
    for i, f in enumerate(found):
        if not f.idle_ok:
            problems.append("frame %d: SCK did not idle at CPOL %d" % (i, mode >> 1))
        if not f.first_ok:
            problems.append("frame %d: SCK's first edge did not leave CPOL %d" % (i, mode >> 1))
        if f.bits % 8:
            problems.append("frame %d: %d sampling edges, not whole bytes" % (i, f.bits))
        if f.setup < 1 or f.hold < 1:
            problems.append("frame %d: MOSI moved within a sample of the sampling edge "
                            "(%d before, %d after)" % (i, f.setup, f.hold))
    nominal = CLOCK_HZ / (2 * SPI_HALF)
    measured = statistics.median(rate / f.period for f in found if f.period)
    if abs(measured - nominal) > RATE_TOLERANCE * nominal:
        problems.append("SCK %.3f MHz, not %.3f MHz within %d%%" % (
            measured / 1e6, nominal / 1e6, RATE_TOLERANCE * 100))
    sent = [f for f in found if f.mosi == JEDEC]
    if not sent:
        problems.append("no frame sends the JEDEC command %s" % ledger_hex(JEDEC))
    elif mode in (0, 3) and not any(f.miso[1:] == FLASH_ID for f in sent):
        problems.append("the flash answers %s, not %s" % (
            " / ".join(ledger_hex(f.miso[1:]) for f in sent), ledger_hex(FLASH_ID)))
    if decode and "9F 00 00 00" not in decode.upper().replace("0X", ""):
        problems.append("sigrok's SPI decoder does not read MOSI 9F 00 00 00")
    return problems


def spi_summary(path, mode):
    rate, _, samples = sigrok.read(path)
    found = frames(samples, mode)
    ns = 1e9 / rate
    if not found:
        return "no frames"
    return ("%d frames, SCK %.3f MHz, MOSI steady %.0f ns before and %.0f ns after the "
            "sampling edge at least (%.1f ns a sample)" % (
                len(found), statistics.median(rate / f.period for f in found if f.period) / 1e6,
                min(f.setup for f in found) * ns, min(f.hold for f in found) * ns, ns))


def ledger_hex(data):
    return " ".join("%02X" % b for b in data)


def i2c_problems(path, mode, decode="", log=""):
    """What an I2C run's capture lacks: every UM10204 limit (a result within a sample of its
    limit is not a failure, but is reported), SCL near what the firmware's quarter makes,
    and the EEPROM's reads and writes the Pico logged."""
    _, results, _ = i2c_timing.check(path, mode)
    problems = []
    if not results:
        return ["no I2C transaction in the capture"]
    for r in results:
        if r.verdict == "fail":
            problems.append("%s: %s" % (r.parameter, r.text))
    clocks = [r.value for r in results if r.parameter == "fSCL"]
    nominal = CLOCK_HZ / 4 / both_roles_firmware.LOADS[I2C_FIRMWARE[mode]] / 1e3
    if not clocks:
        problems.append("no SCL clock measured")
    elif abs(statistics.median(clocks) - nominal) > RATE_TOLERANCE * nominal:
        problems.append("SCL %.1f kHz, not %.1f kHz within %d%%" % (
            statistics.median(clocks), nominal, RATE_TOLERANCE * 100))
    if decode or log:
        decoded = decode.splitlines()
        problems += traffic.eeprom(None)(decoded, log)
    return problems


def i2c_summary(path, mode):
    rate, results, stray = i2c_timing.check(path, mode)
    return "\n".join(i2c_timing.report(rate, results, stray, mode).splitlines())


def pico_log(text):
    return ledger.last_verdict(text)


class Sweep:
    def __init__(self, args):
        self.args = args
        self.bench = ledger.Bench(args.dry_run)
        self.ledger = ledger.Ledger(args, self.bench)
        self.port = os.environ.get("ANALYSER_B_PORT", ANALYSER_B_PORT)

    def decode_args(self, run):
        if run.protocol == "spi":
            mode = run.mode
            return ["-P", "spi:clk=D0:mosi=D1:miso=D2:cs=D3:cpol=%d:cpha=%d" % (
                mode >> 1, mode & 1), "-A", "spi=mosi-transfer:miso-transfer"]
        return ["-P", "i2c:sda=D6:scl=D7,eeprom24xx:chip=onsemi_cat24c256",
                "-A", "eeprom24xx"]

    def demo_call(self, run):
        only = run.mode if run.protocol == "spi" else I2C_FIRMWARE[run.mode]
        return "import demo_rates; demo_rates.main(%r, only=%r)" % (run.protocol, only)

    def run(self, run, day, head, bit_hash):
        b = self.bench
        sr = run.name + ".sr"
        b.open(ledger.fresh(self.args.runs, run.name) if not b.dry_run
               else self.args.runs / run.name)
        print("%s: %s" % (run.name, "SPI mode %d" % run.mode if run.protocol == "spi"
                          else "I2C %s-mode, SCL near %.0f kHz" % (
                              run.mode, CLOCK_HZ / 4 / both_roles_firmware.LOADS[
                                  I2C_FIRMWARE[run.mode]] / 1e3)))
        result, said, held = "ERROR", None, ""
        if not self.ledger.reset():
            b.note("the bitstream did not load: not run")
        else:
            env = {"ANALYSER": "B", "ANALYSER_B_PORT": self.port,
                   "RATE": self.args.rate, "TRIES": "8"}
            ok = b.run(["mpremote", "connect", self.ledger.pico, "exec",
                        "import os\ntry:\n    os.remove('outside.log')\nexcept OSError:\n    pass"]
                       ) == 0
            if ok:
                ok = b.run(["demo/capture.sh", str(b.dir / sr), str(run.capture_ms),
                            "mpremote", "connect", self.ledger.pico, "exec", "--no-follow",
                            self.demo_call(run)], env=env) == 0
            # the run ends inside the capture, and a second more lets the Pico write its log
            b.sleep(1)
            ok = b.run(["mpremote", "connect", self.ledger.pico, "cat", ":outside.log"],
                       out=run.name + ".log") == 0 and ok
            decode = run.name + ".decode"
            if b.dry_run or (b.dir / sr).exists():
                ok = b.run(["sigrok-cli", "-i", str(b.dir / sr), *self.decode_args(run)],
                           out=decode) == 0 and ok
            if b.dry_run:
                b.note("judge: %s" % ("the clock idle level and first edge, SCK rate, MOSI "
                       "steady either side of the sampling edge, JEDEC 9F 00 00 00 sent"
                       + (", flash ID EF 40 17 answered" if run.mode in (0, 3) else "")
                       if run.protocol == "spi" else "UM10204 Table 11 for %s-mode, SCL rate "
                       "near the firmware's, the EEPROM reads and writes of the log" % run.mode))
            else:
                text = (b.dir / (run.name + ".log")).read_text(errors="replace")
                said = pico_log(text)
                b.note("Pico A says %s, every step %s" % (said, "ran" if ok else "did not"))
                problems = self.judge(run, b.dir, text) if ok else []
                for problem in problems:
                    b.note("capture: " + problem)
                held = "; ".join(problems) or "held to the capture"
                result = ledger.judged(ok, said, problems, "PASS")
                (b.dir / (run.name + ".verdict")).write_text(
                    self.verdict(run, b.dir / sr, problems, result))
                print(self.summary(run, b.dir / sr))
        b.close()
        if b.dry_run:
            return None
        demo = ledger.Demo("sweep_" + run.name, "outside", rate=self.args.rate)
        return self.ledger.seal(demo, result, said, held, day, head, bit_hash)

    def judge(self, run, directory, text):
        sr = directory / (run.name + ".sr")
        decode = (directory / (run.name + ".decode")).read_text(errors="replace")
        if run.protocol == "spi":
            return spi_problems(sr, run.mode, decode)
        return i2c_problems(sr, run.mode, decode, text)

    def summary(self, run, sr):
        return (spi_summary(sr, run.mode) if run.protocol == "spi"
                else i2c_summary(sr, run.mode))

    def verdict(self, run, sr, problems, result):
        return "%s\n%s\n%s\n" % (result, self.summary(run, sr),
                                 "\n".join(problems) or "no problems")


def synthetic_spi(path, mode, rate=24_000_000):
    """An SPI capture as the chip's masters make it: JEDEC in each mode, the flash answering
    in modes 0 and 3, half a period of 4 samples at 24 MS/s."""
    cpol, cpha = mode >> 1, mode & 1
    half = max(round(rate * SPI_HALF / CLOCK_HZ), 1)
    clk, mosi, miso, cs = [], [], [], []
    answer = [0] + FLASH_ID

    def hold(c, m, o, s, n):
        for _ in range(n):
            clk.append(c), mosi.append(m), miso.append(o), cs.append(s)

    hold(cpol, 0, 0, 1, 8)
    flat = lambda data: [(b >> (7 - k)) & 1 for b in data for k in range(8)]  # noqa: E731
    out, back = flat(JEDEC), flat(answer if mode in (0, 3) else [0] * 4)
    # each bit sits on MOSI a half period around its sampling edge: cpha 0 changes it before
    # the leading edge, cpha 1 on the leading edge
    hold(cpol, out[0] if not cpha else 0, back[0], 0, half)
    for n in range(len(out)):
        m, o = out[n], back[n]
        if cpha:
            hold(1 - cpol, m, o, 0, half)
            hold(cpol, m, o, 0, half)
        else:
            hold(cpol, m, o, 0, 0)
            hold(1 - cpol, m, o, 0, half)
            nxt = out[n + 1] if n + 1 < len(out) else m
            hold(cpol, nxt, back[n + 1] if n + 1 < len(back) else o, 0, half)
    hold(cpol, 0, 0, 0, 4)
    hold(cpol, 0, 0, 1, 40)
    samples = bytes(c | m << 1 | o << 2 | s << 3 for c, m, o, s in zip(clk, mosi, miso, cs))
    sigrok.write(path, rate, samples)


def synthetic_i2c(path, quarter, rate=24_000_000):
    """START, address 0xA0, ACK, one data byte, STOP with SCL and SDA moving on quarters of
    `quarter` samples."""
    scl, sda = [], []

    def put(c, d, n=1):
        for _ in range(n * quarter):
            scl.append(c), sda.append(d)

    put(1, 1, 8)
    put(1, 0, 2)
    put(0, 0)
    bits = [(0xA0 >> (7 - k)) & 1 for k in range(8)] + [0] + [1, 0, 1, 0, 1, 0, 1, 0] + [0]
    for d in bits:
        put(0, d)
        put(1, d, 2)
        put(0, d)
    put(0, 0)
    put(1, 0, 2)
    put(1, 1, 8)
    samples = bytes(c << 7 | d << 6 for c, d in zip(scl, sda))
    sigrok.write(path, rate, samples)


def self_check():
    """Judges synthetic captures: each right one passes, a wrong phase or a clock off by a
    third fails."""
    failed = []

    def expect(what, got, want):
        ok = bool(got) == want
        print("%-44s %s" % (what, "ok" if ok else "WRONG: %s" % (got,)))
        if not ok:
            failed.append(what)

    with tempfile.TemporaryDirectory() as d:
        for mode in range(4):
            path = Path(d) / ("spi%d.sr" % mode)
            synthetic_spi(path, mode)
            expect("spi mode %d, as the chip makes it" % mode, spi_problems(path, mode), False)
            expect("spi mode %d read as mode %d" % (mode, mode ^ 1),
                   spi_problems(path, mode ^ 1), True)
        # the flash not answering in mode 0 is a failure
        path = Path(d) / "silent.sr"
        synthetic_spi(path, 1)
        expect("spi mode 1 capture read for the ID in mode 0", spi_problems(path, 0), True)
        for mode, quarter in (("standard", 121), ("fast", 32)):
            path = Path(d) / ("i2c_%s.sr" % mode)
            samples = max(round(24_000_000 * quarter / CLOCK_HZ), 1)
            synthetic_i2c(path, samples)
            expect("i2c %s, as the firmware makes it" % mode,
                   i2c_problems(path, mode), False)
        # an SCL a third too slow for its mode's quarter
        path = Path(d) / "slow.sr"
        synthetic_i2c(path, round(24_000_000 * 121 / CLOCK_HZ * 1.4))
        expect("i2c standard 40% slow", i2c_problems(path, "standard"), True)
        # 100 kHz firmware held to Fast-mode's tLOW would pass; 400 kHz under Standard's fails
        path = Path(d) / "fast_as_standard.sr"
        synthetic_i2c(path, round(24_000_000 * 32 / CLOCK_HZ))
        expect("i2c 400 kHz held to Standard-mode", i2c_problems(path, "standard"), True)
    if failed:
        sys.exit("self-check failed: " + ", ".join(failed))
    print("self-check passed")


def older_than_sources(bitstream):
    """Why a bitstream is older than the RTL and pins in its own checkout, or None. A
    10-01 build met 10-10's firmware, which had moved SCL and SDA, and crossed them."""
    repo = Path(bitstream).resolve().parent
    last = subprocess.run(["git", "-C", str(repo), "log", "-1", "--format=%ct %h", "--",
                           ":/src/protocol_emulator.v", ":/icepi/"],
                          capture_output=True, text=True).stdout.split()
    if not last or Path(bitstream).stat().st_mtime >= int(last[0]):
        return None
    return "%s is older than %s, which changed the RTL or the Icepi's pins: rebuild it" % (
        bitstream, last[1])


def main():
    p = argparse.ArgumentParser()
    p.add_argument("bitstream", nargs="?")
    p.add_argument("--only", action="append", choices=NAMES, metavar="RUN",
                   help="this run, again for more: " + " ".join(NAMES))
    p.add_argument("--rate", default="24M", help="the analyser's sample rate, 24M unless set")
    p.add_argument("--evidence", type=Path, default=ledger.EVIDENCE)
    p.add_argument("--results", type=Path, default=ledger.RESULTS)
    p.add_argument("--dry-run", action="store_true", help="print every step and run nothing")
    p.add_argument("--self-check", action="store_true",
                   help="judge synthetic captures and stop, no hardware")
    args = p.parse_args()
    if args.self_check:
        return self_check()
    if not args.bitstream:
        p.error("BITSTREAM is needed")
    args.bitstream = os.path.abspath(args.bitstream)
    args.evidence = args.evidence.resolve()
    if not args.dry_run:
        if "PICO" not in os.environ:
            sys.exit("PICO=id:<serial of Pico A> is unset")
        if not Path(args.bitstream).is_file():
            sys.exit("no bitstream %s" % args.bitstream)
        stale = older_than_sources(args.bitstream)
        if stale:
            sys.exit(stale)
    runs = [r for r in RUNS if not args.only or r.name in args.only]
    day = datetime.date.today().isoformat()
    args.runs = args.evidence / day / "sweep-rates"
    head = ledger.commit()
    bit_hash = "-" if args.dry_run else ledger.sha256(args.bitstream)
    if not args.dry_run:
        ledger.keep_bitstream(args.bitstream, args.runs, bit_hash)
    print("commit %s, bitstream %s, evidence %s, analyser B at %s S/s" % (
        head, args.bitstream, args.runs, args.rate))
    sweep = Sweep(args)
    if args.dry_run:
        sweep.bench.note("once: " + " ".join(["mpremote", "connect", sweep.ledger.pico, "cp",
                                              *FILES, ":"]))
    else:
        subprocess.run(["mpremote", "connect", sweep.ledger.pico, "cp", *FILES, ":"],
                       cwd=ledger.ROOT, check=True)
    rows = []
    for run in runs:
        row = sweep.run(run, day, head, bit_hash)
        if row:
            rows.append(row)
            ledger.append(args.results, [row])
    if args.dry_run:
        print("then a line a run in %s" % args.results)
        return
    sweep.ledger.reset()
    print()
    for row in rows:
        print("%-22s %s" % (row["demo"], row["result"]))
    sys.exit(0 if all(r["result"] == "PASS" for r in rows) else 1)


if __name__ == "__main__":
    main()
