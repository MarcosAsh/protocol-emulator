# SPDX-License-Identifier: Apache-2.0
# Every bench demo in turn, each from a fresh load of BITSTREAM as its reset. A demo keeps
# its capture, decode, Pico logs and a SHA256SUMS in EVIDENCE/<date>/ledger/<demo>/, beside
# the day's other bench runs, and adds a line to demo/ledger.tsv. --keyboard adds the USB
# keyboard demo, which types into the focused window. PICO_B_SERIAL picks Pico B, as for
# demo/pico_b.sh.
# Usage: PICO=id:<serial of Pico A> python3 demo/ledger.py BITSTREAM [--keyboard]
#            [--only DEMO]... [--evidence DIR] [--results TSV] [--dry-run]

import argparse
import datetime
import hashlib
import os
import re
import shlex
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path

import traffic

ROOT = Path(__file__).resolve().parent.parent
EVIDENCE = Path.home() / ".local/share/protocol-emulator/board-evidence"
RESULTS = ROOT / "demo/ledger.tsv"
COLUMNS = ["date", "demo", "result", "expected", "commit", "bitstream_sha256",
           "capture_sha256", "sums_sha256", "evidence"]
PICO_B_SERIAL = "e66548545740ad29"
BASE = ["python/protocol_emulator.py", "python/pico_board.py"]
# how long the analyser takes to start sampling once sigrok-cli is up
ARM_S = 3
# a demo that runs until reset is stopped after this
KEYBOARD_S = 30
TEXT = "hello jane street "


@dataclass(frozen=True)
class Demo:
    name: str
    # outside: demo/outside.sh's name for it; start_hold: demo/start_hold.sh's; pico: the
    # ledger runs RUN (a script) or EXEC (a statement) on Pico A
    kind: str
    expect: str = "PASS"
    # what Pico B must run, or None when it is not part of the demo
    pico_b: str | None = None
    files: tuple = ()
    run: str | None = None
    exec: str | None = None
    # the baud pico_listener reads OUT0 at on Pico B
    listen: int | None = None
    # analyser A on D4 (OUT0) for this long, at RATE (or the environment's), and the decode
    capture_ms: int | None = None
    rate: str | None = None
    decode: str | None = None
    timeout_s: int | None = None
    why: str = ""


SMOKE = """import pico_board
s = pico_board.host().status()
print(s)
faults = [s[k] for k in ("underflow", "overflow", "missed_deadline", "decode")]
print("PASS" if s["halted"] == 1 and not any(faults) else "FAIL")"""


def outside(name, pico_b=None):
    return Demo(name, "outside", pico_b=pico_b)


DEMOS = [
    Demo("smoke", "pico", exec=SMOKE),
    # 2 MS/s is plenty for 9600 and 115200 baud and keeps a 30 s capture at 60 MB
    Demo("self_timing", "pico", pico_b="micropython",
         files=("python/demo_self_timing.py", "test/uart_tx_host_rate.hex",
                "test/edge_logger_echo.hex"),
         run="python/demo_self_timing.py", listen=9600, capture_ms=8000, rate="2M",
         decode="-P uart:rx=D4:baudrate=9600 -A uart=rx-data"),
    # OUT0 echoes wire 20 through every firmware, too many bauds for one decode
    Demo("sweep", "pico",
         files=("python/demo_self_timing.py", "python/sweep_firmware.py",
                "python/demo_sweep.py"),
         run="python/demo_sweep.py", capture_ms=8000),
    # wire 20 never leaves the chip: nothing to capture
    Demo("self_check", "pico",
         files=("python/demo_self_check.py", "test/uart_tx_host_rate.hex",
                "test/self_check_wire.hex", "test/uart_tx_host_rate_rows.hex"),
         run="python/demo_self_check.py"),
    # engine 1 sends each key the laptop took out of OUT0
    Demo("keyboard", "pico", pico_b="micropython",
         files=("python/usb_board.py", "python/usb_device_firmware.py", "python/demo_usb.py",
                "test/uart_tx_host_rate.hex"),
         run="python/demo_usb.py", listen=115_200, capture_ms=KEYBOARD_S * 1000, rate="2M",
         decode="-P uart:rx=D4:baudrate=115200 -A uart=rx-data", timeout_s=KEYBOARD_S),
    outside("flash"),
    outside("eeprom"),
    outside("eeprom_stretch"),
    outside("ds18b20"),
    outside("neopixel"),
    outside("swd"),
    outside("referee"),
    outside("can", pico_b="can_node"),
    outside("can_node", pico_b="can_node"),
    Demo("start_hold_pio", "start_hold", expect="FAIL",
         why="pico-examples' pio_i2c holds a START 3.125 us, under 4.0 (#796)"),
    Demo("start_hold_hw", "start_hold"),
]
NAMES = [d.name for d in DEMOS]


def last_verdict(text):
    """The last line that is PASS or FAIL alone, as bench.run and the demos end."""
    found = [line.strip() for line in text.splitlines() if line.strip() in ("PASS", "FAIL")]
    return found[-1] if found else None


def hold_verdict(text):
    """demo_start_hold's verdict on the chip's stamps, on the line that judges them."""
    found = re.findall(r"^host, against t_HD;STA .*?: (PASS|FAIL)", text, re.MULTILINE)
    return found[-1] if found else None


def judged(ok, said, problems, expect):
    """A run with a step missing is no evidence either way, nor is a capture without the
    traffic of a demo expected to fail. Pico A's PASS on a capture without it is a FAIL."""
    if not (ok and said) or (problems and expect == "FAIL"):
        return "ERROR"
    return "FAIL" if problems else said


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


def commit():
    head = subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT, capture_output=True,
                          text=True).stdout.strip() or "unknown"
    # the ledger's own lines do not count
    dirty = subprocess.run(["git", "status", "--porcelain", "--untracked-files=no", "--", ".",
                            ":!demo/ledger.tsv"], cwd=ROOT, capture_output=True,
                           text=True).stdout.strip()
    return head + ("+dirty" if dirty else "")


def fresh(parent, name):
    """parent/name, or name.2, .3 and on: evidence is never overwritten."""
    path, n = parent / name, 1
    while path.exists():
        n += 1
        path = parent / ("%s.%d" % (name, n))
    return path


def pico_b_tty(serial):
    """Pico B's serial port: MicroPython names the serial in lower case, the SDK upper."""
    found = sorted(p for p in Path("/dev/serial/by-id").glob("*")
                   if p.name.lower().endswith("_%s-if00" % serial.lower()))
    return found[0] if found else None


class Bench:
    """Runs the commands of one demo from the repository root, logging each to run.txt, or
    with dry_run only prints them."""

    def __init__(self, dry_run):
        self.dry_run = dry_run
        self.dir = None
        self.log = None

    def open(self, path):
        self.dir = path
        if not self.dry_run:
            path.mkdir(parents=True)
            self.log = open(path / "run.txt", "a")

    def close(self):
        if self.log:
            self.log.close()
        self.log = None

    def note(self, text):
        print("  " + text if self.dry_run else text, flush=True)
        if self.log:
            self.log.write(text + "\n")
            self.log.flush()

    def _show(self, argv, env, out, sign):
        words = ["%s=%s" % kv for kv in env.items()] + [str(a) for a in argv]
        line = "%s %s" % (sign, shlex.join(words))
        if out:
            line += " > " + (out if self.dry_run else str(self.dir / out))
        self.note(line)

    def _out(self, out):
        return open(self.dir / out, "w") if out else self.log

    def run(self, argv, out=None, env=None, timeout=None):
        """The exit status, or None when it ran past timeout and was stopped."""
        env = env or {}
        self._show(argv, env, out, "$")
        if self.dry_run:
            return 0
        f = self._out(out)
        try:
            return subprocess.run(argv, cwd=ROOT, stdout=f, stderr=self.log, timeout=timeout,
                                  env=os.environ | env).returncode
        except subprocess.TimeoutExpired:
            self.note("stopped after %d s" % timeout)
            return None
        finally:
            if out:
                f.close()

    def start(self, argv, out=None, env=None):
        env = env or {}
        self._show(argv, env, out, "&")
        if self.dry_run:
            return None
        f = self._out(out)
        return subprocess.Popen(argv, cwd=ROOT, stdout=f, stderr=self.log,
                                env=os.environ | {"PYTHONUNBUFFERED": "1"} | env)

    def wait(self, proc, seconds, kill=False):
        """Waits up to seconds for proc, then stops it; kill stops it at once."""
        if self.dry_run or proc is None:
            return 0
        try:
            if not kill:
                return proc.wait(seconds)
        except subprocess.TimeoutExpired:
            self.note("still running after %d s: stopped" % seconds)
        proc.terminate()
        try:
            return proc.wait(5)
        except subprocess.TimeoutExpired:
            proc.kill()
            return proc.wait()

    def sleep(self, seconds):
        if not self.dry_run:
            time.sleep(seconds)


class Ledger:
    def __init__(self, args, bench):
        self.args = args
        self.bench = bench
        self.pico = os.environ.get("PICO", "$PICO")
        self.serial = os.environ.get("PICO_B_SERIAL", PICO_B_SERIAL)
        self.pico_b = None
        tty = None if args.dry_run else pico_b_tty(self.serial)
        if tty and "micropython" in tty.name.lower():
            self.pico_b = "micropython"

    def mpremote(self, *words, pico=None):
        return ["mpremote", "connect", pico or self.pico, *words]

    def reset(self):
        """A fresh load of the bitstream, as faults hold until reset."""
        return self.bench.run(["openFPGALoader", "-b", "icepi-zero", self.args.bitstream]) == 0

    def load_pico_b(self, firmware):
        """Pico B onto firmware unless it runs it already, which a run remembers."""
        if firmware is None or firmware == self.pico_b:
            return True
        self.pico_b = None
        if self.bench.dry_run:
            self.bench.note("unless Pico B runs %s already:" % firmware)
        if self.bench.run(["demo/pico_b.sh", firmware],
                          env={"PICO_B_SERIAL": self.serial}) != 0:
            return False
        self.pico_b = firmware
        return True

    def run_pico(self, demo):
        """Copies demo's files, starts Pico B's listener and the analyser, runs the demo on
        Pico A, then decodes. The name of Pico A's log and whether every step ran."""
        b, d = self.bench, demo.name
        ok = b.run(self.mpremote("cp", *BASE, *demo.files, ":")) == 0
        listener = capture = None
        if ok and demo.listen:
            pico_b = "id:" + self.serial
            ok = b.run(self.mpremote("cp", "python/pico_listener.py", ":", pico=pico_b)) == 0
            # keys as text, the self-timing bytes in hex
            listen = "import pico_listener; pico_listener.listen(%d, %s)" % (
                demo.listen, demo.name == "keyboard")
            listener = b.start(self.mpremote("exec", listen, pico=pico_b), out="pico_b.log")
        if ok and demo.capture_ms:
            env = {"ANALYSER": "A", "TRIES": "1"}
            if demo.rate:
                env["RATE"] = demo.rate
            capture = b.start(["demo/capture.sh", str(b.dir / ("%s.sr" % d)),
                               str(demo.capture_ms)], env=env)
            b.sleep(ARM_S)
        status, since = 1, int(time.time())
        if ok:
            script = ("run", demo.run) if demo.run else ("exec", demo.exec)
            status = b.run(self.mpremote(*script), out=d + ".log", timeout=demo.timeout_s)
        ok = ok and b.wait(capture, (demo.capture_ms or 0) / 1000 + 60) == 0
        b.wait(listener, 0, kill=True)
        # the demo that runs until reset is stopped, which is how it ends
        ok = ok and (status == 0 or (status is None and demo.timeout_s is not None))
        sr = b.dir / ("%s.sr" % d)
        if demo.decode and (b.dry_run or sr.exists()):
            ok = b.run(["sigrok-cli", "-i", str(sr), *demo.decode.split()],
                       out=d + ".decode") == 0 and ok
        if d == "keyboard":
            # the laptop's own account of the device it enumerated
            b.run(["journalctl", "-k", "-o", "short-iso-precise", "--since", "@%d" % since,
                   "--grep", "usb|hid|input"], out="keyboard.kernel")
        return d + ".log", ok

    def run_outside(self, demo):
        tty = None if self.bench.dry_run else pico_b_tty(self.serial)
        reader = None
        # the C firmwares print what they receive on their USB serial port
        if demo.pico_b == "can_node" and (tty or self.bench.dry_run):
            reader = self.bench.start(
                ["sh", "-c", 'stty -F "$0" raw -echo && exec cat "$0"', tty or "PICO_B_PORT"],
                out="pico_b.log")
        status = self.bench.run(["demo/outside.sh", demo.name],
                                env={"CAPTURES": str(self.bench.dir), "PICO": self.pico},
                                out="outside.txt")
        self.bench.sleep(1)
        self.bench.wait(reader, 0, kill=True)
        return demo.name + ".log", status == 0

    def run_start_hold(self, demo):
        how = demo.name.removeprefix("start_hold_")
        self.pico_b = None
        env = {"CAPTURES": str(self.bench.dir), "PICO": self.pico,
               "PICO_B_SERIAL": self.serial}
        status = self.bench.run(["demo/start_hold.sh", how], env=env, out="start_hold.txt")
        # demo/start_hold.sh reads Pico B's port once the master is in
        self.pico_b = "start_hold_" + how if status == 0 else None
        return "start_hold.log", status == 0

    def demo(self, demo, day, head, bit_hash):
        b = self.bench
        b.open(fresh(self.args.runs, demo.name) if not b.dry_run
               else self.args.runs / demo.name)
        print("%s, expect %s%s" % (demo.name, demo.expect, ": " + demo.why if demo.why else ""))
        result, said, held = "ERROR", None, ""
        if not self.reset():
            b.note("the bitstream did not load: not run")
        elif not self.load_pico_b(demo.pico_b):
            b.note("Pico B did not take %s: not run" % demo.pico_b)
        else:
            run = {"pico": self.run_pico, "outside": self.run_outside,
                   "start_hold": self.run_start_hold}[demo.kind]
            log, ok = run(demo)
            if not b.dry_run:
                text = (b.dir / log).read_text(errors="replace") if (b.dir / log).exists() else ""
                said = (("PASS" if traffic.typed(text) == TEXT else "FAIL")
                        if demo.name == "keyboard"
                        else hold_verdict(text) if demo.kind == "start_hold"
                        else last_verdict(text))
                b.note("Pico A says %s, every step %s" % (said, "ran" if ok else "did not"))
                problems = traffic.check(demo.name, b.dir) if ok else []
                for problem in problems:
                    b.note("traffic: " + problem)
                name = traffic.stem(demo.name)
                if ok and name in traffic.CHECKS:
                    held = "; ".join(problems) or "held to the capture"
                elif ok and name in traffic.UNSEEN:
                    # a PASS here rests on Pico A's readback alone, which the reader must see
                    held = "; ".join(["none (no analyser channel)"] + problems)
                result = judged(ok, said, problems, demo.expect)
        b.close()
        if b.dry_run:
            return None
        return self.seal(demo, result, said, held, day, head, bit_hash)

    def seal(self, demo, result, said, held, day, head, bit_hash):
        """ledger.txt and SHA256SUMS in the demo's directory, and its line for the TSV."""
        d = self.bench.dir
        info = [("demo", demo.name), ("result", result), ("pico_a_says", said),
                ("traffic", held),
                ("expected", demo.expect),
                ("why", demo.why), ("time", datetime.datetime.now().isoformat(timespec="seconds")),
                ("commit", head), ("bitstream", os.path.abspath(self.args.bitstream)),
                ("bitstream_sha256", bit_hash), ("pico_a", self.pico),
                ("pico_b", "%s %s" % (self.serial, self.pico_b or "unknown")),
                ("rate", (demo.rate or os.environ.get("RATE", "24M"))
                 if demo.kind != "pico" or demo.capture_ms else "")]
        (d / "ledger.txt").write_text("".join("%s: %s\n" % kv for kv in info if kv[1]))
        files = sorted(p for p in d.rglob("*") if p.is_file() and p.name != "SHA256SUMS")
        (d / "SHA256SUMS").write_text(
            "".join("%s  %s\n" % (sha256(p), p.relative_to(d)) for p in files))
        captures = [p for p in files if p.suffix == ".sr"]
        return {"date": day, "demo": demo.name, "result": result, "expected": demo.expect,
                "commit": head, "bitstream_sha256": bit_hash,
                "capture_sha256": sha256(captures[0]) if captures else "-",
                "sums_sha256": sha256(d / "SHA256SUMS"),
                "evidence": str(d.relative_to(self.args.evidence))}


def append(results, rows):
    new = not results.exists() or results.stat().st_size == 0
    with open(results, "a") as f:
        if new:
            f.write("\t".join(COLUMNS) + "\n")
        for row in rows:
            f.write("\t".join(row[c] for c in COLUMNS) + "\n")


def plan(args):
    chosen = [d for d in DEMOS if (d.name != "keyboard" or args.keyboard)
              and (not args.only or d.name in args.only)]
    if args.only and "keyboard" in args.only and not args.keyboard:
        sys.exit("keyboard types into the focused window: add --keyboard")
    return chosen


def main():
    p = argparse.ArgumentParser()
    p.add_argument("bitstream")
    p.add_argument("--keyboard", action="store_true",
                   help="also the USB keyboard demo, which types into the focused window")
    p.add_argument("--only", action="append", choices=NAMES, metavar="DEMO",
                   help="this demo, again for more: " + " ".join(NAMES))
    p.add_argument("--evidence", type=Path, default=EVIDENCE)
    p.add_argument("--results", type=Path, default=RESULTS)
    p.add_argument("--dry-run", action="store_true", help="print the plan and run nothing")
    args = p.parse_args()
    # every command runs from the repository root
    args.bitstream = os.path.abspath(args.bitstream)
    args.evidence = args.evidence.resolve()
    if not args.dry_run:
        if "PICO" not in os.environ:
            sys.exit("PICO=id:<serial of Pico A> is unset")
        if not Path(args.bitstream).is_file():
            sys.exit("no bitstream %s" % args.bitstream)
    demos = plan(args)
    day = datetime.date.today().isoformat()
    args.runs = args.evidence / day / "ledger"
    head = commit()
    bit_hash = "-" if args.dry_run else sha256(args.bitstream)
    if not args.dry_run:
        # the bitstream itself, so its hash can be checked once the build is gone
        kept = args.runs / "bitstreams" / (bit_hash[:16] + ".bit")
        kept.parent.mkdir(parents=True, exist_ok=True)
        if not kept.exists():
            shutil.copyfile(args.bitstream, kept)
    print("commit %s, bitstream %s, evidence %s" % (head, args.bitstream, args.runs))
    ledger = Ledger(args, Bench(args.dry_run))
    rows = []
    for demo in demos:
        row = ledger.demo(demo, day, head, bit_hash)
        if row:
            rows.append(row)
            append(args.results, [row])
    if args.dry_run:
        print("then a line a demo in %s" % args.results)
        return
    ledger.reset()
    print()
    for row in rows:
        mark = "" if row["result"] == row["expected"] else "  (expected %s)" % row["expected"]
        print("%-16s %s%s" % (row["demo"], row["result"], mark))
    sys.exit(0 if all(r["result"] == r["expected"] for r in rows) else 1)


if __name__ == "__main__":
    main()
