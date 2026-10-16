# SPDX-License-Identifier: Apache-2.0
# One bench demo, unattended: loads the chip, runs demo/outside.sh (flash, capture, decode),
# measures the capture against the datasheet limits, marks demo/speed.tsv and keeps
# EVIDENCE/<date>/<protocol>/<demo>/ with a result.txt and a line in demo/runs.tsv. A stage
# past its timeout, or a run with a step missing, resets the Icepi to its flash and runs
# once more; both attempts are kept (attempt1/, attempt2/), a FAIL verdict is not retried.
# Usage: PICO=id:<serial of Pico A> python3 demo/bench_run.py DEMO [--bitstream FILE |
#            --from-flash] [--measure FIRMWARE --probe PIN=Dn...] [--dry-run]

import argparse
import csv
import datetime
import os
import shlex
import shutil
import signal
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path

import ledger
import traffic

ROOT = Path(__file__).resolve().parent.parent
EVIDENCE = ledger.EVIDENCE
RESULTS = ROOT / "demo/runs.tsv"
COLUMNS = ["date", "protocol", "demo", "result", "attempts", "commit", "bitstream_sha256",
           "capture_sha256", "measured", "evidence"]
# the protocol page a demo belongs on, as test/corpus.py names them
PROTOCOL = {
    "swd": "swd", "neopixel": "ws2812", "referee": "ws2812", "eeprom": "i2c",
    "eeprom_stretch": "i2c", "start_hold": "i2c", "flash": "spi", "ds18b20": "one_wire",
    "can": "can", "can_node": "can_node",
}
# the demos Pico B has a firmware for
PICO_B = {"can": "can_node", "can_node": "can_node"}
# a demo's datasheet limits: the library's firmware, and the engine pins on the analyser
MEASURE = {
    "eeprom": ("i2c_master", ["IO2=D7", "IO3=D6"]),
    "eeprom_stretch": ("i2c_master_stretch", ["IO2=D7", "IO3=D6"]),
}
FLASH = ["openFPGALoader", "-b", "icepi-zero", "-r"]
LIMITS = ["dune", "exec", "--root", ".", "test/measure/measure.exe", "--"]
# seconds a stage may take
TIMEOUT = {"load": 120, "pico_b": 300, "run": 240, "measure": 180}


@dataclass
class Stage:
    name: str
    status: int | None


class Runner:
    """Runs commands from the repository root, each in its own process group so a timeout
    stops what it started, and logs them to run.txt. With dry_run only prints them."""

    def __init__(self, dry_run):
        self.dry_run = dry_run
        self.log = None

    def open(self, directory):
        if not self.dry_run:
            directory.mkdir(parents=True)
            self.log = open(directory / "run.txt", "a")

    def close(self):
        if self.log:
            self.log.close()
        self.log = None

    def note(self, text):
        print(("  " if self.dry_run else "") + text, flush=True)
        if self.log:
            self.log.write(text + "\n")
            self.log.flush()

    def start(self, argv, out=None, env=None, stdin=None, sign="$"):
        env = env or {}
        words = ["%s=%s" % kv for kv in env.items()] + [str(a) for a in argv]
        self.note("%s %s%s%s" % (sign, shlex.join(words), " < " + str(stdin) if stdin else "",
                                 " > " + str(out) if out else ""))
        if self.dry_run:
            return None
        return subprocess.Popen(
            argv, cwd=ROOT, env=os.environ | env, start_new_session=True,
            stdin=open(stdin) if stdin else subprocess.DEVNULL,
            stdout=open(out, "w") if out else self.log, stderr=self.log)

    def stop(self, proc):
        try:
            os.killpg(proc.pid, signal.SIGTERM)
            proc.wait(5)
        except subprocess.TimeoutExpired:
            os.killpg(proc.pid, signal.SIGKILL)
            proc.wait()
        except ProcessLookupError:
            pass

    def run(self, name, argv, timeout, **kw):
        """The stage's exit status, or None when it ran past timeout and was stopped."""
        proc = self.start(argv, **kw)
        if proc is None:
            return Stage(name, 0)
        try:
            return Stage(name, proc.wait(timeout))
        except subprocess.TimeoutExpired:
            self.note("%s: stopped after %d s" % (name, timeout))
            self.stop(proc)
            return Stage(name, None)

    def sleep(self, seconds):
        if not self.dry_run:
            time.sleep(seconds)


class Job:
    def __init__(self, args, runner):
        self.args = args
        self.runner = runner
        self.demo = args.demo
        self.protocol = PROTOCOL.get(args.demo, args.demo)
        self.pico = os.environ.get("PICO", "$PICO")
        self.serial = os.environ.get("PICO_B_SERIAL", ledger.PICO_B_SERIAL)
        firmware, probes = MEASURE.get(args.demo, (None, []))
        self.firmware = args.measure or firmware
        self.probes = args.probe or probes
        self.timeout = TIMEOUT | {k[2:]: v for k, v in vars(args).items()
                                  if k.startswith("t_") and v}

    def load(self, recovery):
        """The chip from a bitstream, or from its flash, which is also the recovery."""
        r = self.runner
        if recovery or not self.args.bitstream:
            stage = r.run("load", FLASH, self.timeout["load"])
            r.sleep(2)
            return stage
        return r.run("load", ["openFPGALoader", "-b", "icepi-zero", self.args.bitstream],
                     self.timeout["load"])

    def attempt(self, directory, recovery):
        """The stages' outcomes and the verdict of one pass, in directory."""
        r = self.runner
        r.open(directory)
        stages, verdict, notes = [], "ERROR", []
        stages.append(self.load(recovery))
        firmware = PICO_B.get(self.demo)
        if stages[-1].status == 0 and firmware:
            stages.append(r.run("pico_b", ["demo/pico_b.sh", firmware], self.timeout["pico_b"],
                                env={"PICO_B_SERIAL": self.serial}))
        if all(s.status == 0 for s in stages):
            stages.append(r.run(
                "run", ["demo/outside.sh", self.demo], self.timeout["run"],
                env={"CAPTURES": str(directory), "PICO": self.pico}, out=directory / "outside.txt"))
        if all(s.status == 0 for s in stages):
            verdict = self.judge(directory, stages, notes)
        if not r.dry_run:
            r.note("attempt: %s" % " ".join(
                "%s=%s" % (s.name, "timeout" if s.status is None else s.status) for s in stages))
        r.close()
        return stages, verdict, notes

    def judge(self, directory, stages, notes):
        """Pico A's PASS held to the capture's traffic and the datasheet limits."""
        r = self.runner
        if r.dry_run:
            self.measure(directory, stages, notes)
            return "DRY"
        log = directory / (self.demo + ".log")
        said = ledger.last_verdict(log.read_text(errors="replace")) if log.exists() else None
        problems = traffic.check(self.demo, directory)
        notes += ["traffic: " + p for p in problems]
        verdict = ledger.judged(True, said, problems, "PASS")
        measured = self.measure(directory, stages, notes)
        if measured and verdict == "PASS":
            verdict = "FAIL"
        if measured is None:
            verdict = "ERROR"
        return verdict

    def measure(self, directory, stages, notes):
        """True when a datasheet limit fails, False when all hold or none names the demo,
        None when the tooling broke."""
        r = self.runner
        if not self.firmware:
            notes.append("measured: no datasheet limits wired for %s" % self.demo)
            return False
        sr, edges = directory / (self.demo + ".sr"), directory / "edges.txt"
        probes = ["python3", "demo/edges.py", str(sr), *self.probes]
        e = r.run("edges", probes, self.timeout["measure"], out=edges)
        m = r.run("measure", [*LIMITS, self.firmware], self.timeout["measure"], stdin=edges,
                  out=directory / "measure.txt")
        stages += [e, m]
        if e.status != 0 or m.status not in (0, 1):
            notes.append("measured: the tooling failed")
            return None
        notes.append("measured: %s" % ("a datasheet limit fails" if m.status else "limits hold"))
        return m.status == 1

    def seal(self, folder, attempts, day, head, bit_hash):
        """result.txt and SHA256SUMS in folder, the last attempt's files copied up, and the
        row for the TSV."""
        stages, verdict, notes = attempts[-1]
        final = folder / ("attempt%d" % len(attempts))
        for p in sorted(final.iterdir()):
            if p.name != "run.txt":
                shutil.copy(p, folder / p.name)
        captures = sorted(folder.glob("*.sr"))
        measure = folder / "measure.txt"
        info = [("protocol", self.protocol), ("demo", self.demo), ("verdict", verdict),
                ("attempts", str(len(attempts))), ("final", final.name),
                ("time", datetime.datetime.now().isoformat(timespec="seconds")),
                ("commit", head), ("bitstream", str(self.args.bitstream or "flash")),
                ("bitstream_sha256", bit_hash), ("pico_a", self.pico),
                ("rate", os.environ.get("RATE", "24M"))]
        info += [("attempt%d" % n, "%s: %s" % (v, " ".join(
            "%s=%s" % (s.name, "timeout" if s.status is None else s.status) for s in st)))
            for n, (st, v, _) in enumerate(attempts, 1)]
        info += [("note", n) for n in notes]
        (folder / "result.txt").write_text("".join("%s: %s\n" % kv for kv in info))
        files = sorted(p for p in folder.rglob("*") if p.is_file() and p.name != "SHA256SUMS")
        (folder / "SHA256SUMS").write_text(
            "".join("%s  %s\n" % (ledger.sha256(p), p.relative_to(folder)) for p in files))
        return {"date": day, "protocol": self.protocol, "demo": self.demo, "result": verdict,
                "attempts": str(len(attempts)), "commit": head, "bitstream_sha256": bit_hash,
                "capture_sha256": ledger.sha256(captures[0]) if captures else "-",
                "measured": ("-" if not self.firmware else "fail" if verdict == "FAIL" and
                             measure.exists() else "hold" if measure.exists() else "error"),
                "evidence": str(folder.relative_to(self.args.evidence))}

    def go(self):
        a, r = self.args, self.runner
        day = datetime.date.today().isoformat()
        head = ledger.commit()
        bit_hash = ("-" if a.dry_run else ledger.sha256(a.bitstream)) if a.bitstream else "flash"
        folder = a.evidence / day / self.protocol / self.demo
        if not a.dry_run:
            folder = ledger.fresh(folder.parent, self.demo)
            folder.mkdir(parents=True)
        print("%s (%s), commit %s, evidence %s" % (self.demo, self.protocol, head, folder))
        attempts = []
        for n in (1, 2):
            attempts.append(self.attempt(folder / ("attempt%d" % n), recovery=n == 2))
            stages, verdict, _ = attempts[-1]
            if verdict != "ERROR":
                break
            if n == 1:
                r.note("no verdict: the Icepi back to its flash, once more")
        if a.dry_run:
            print("and if an attempt has no verdict, once more after the Icepi's flash:")
            r.note("$ " + shlex.join(FLASH))
            print("then speed.py mark on a PASS, result.txt, SHA256SUMS and a line in %s"
                  % a.results)
            return 0
        verdict = attempts[-1][1]
        if verdict == "PASS":
            subprocess.run([sys.executable, "demo/speed.py", "mark", self.demo, "bench",
                            "--if-started"], cwd=ROOT)
        row = self.seal(folder, attempts, day, head, bit_hash)
        append(a.results, row)
        print("%s %s, %d attempt(s): %s" % (self.demo, verdict, len(attempts), folder))
        return 0 if verdict == "PASS" else 1


def append(results, row):
    new = not results.exists() or results.stat().st_size == 0
    with open(results, "a", newline="") as f:
        out = csv.writer(f, delimiter="\t", lineterminator="\n")
        if new:
            out.writerow(COLUMNS)
        out.writerow([row[c] for c in COLUMNS])


def main():
    p = argparse.ArgumentParser()
    p.add_argument("demo", choices=sorted(PROTOCOL), metavar="DEMO",
                   help=" ".join(sorted(PROTOCOL)))
    p.add_argument("--bitstream", type=Path)
    p.add_argument("--from-flash", action="store_true", help="the chip as its flash holds it")
    p.add_argument("--measure", metavar="FIRMWARE", help="the library firmware whose limits "
                   "to hold the capture to, if not the demo's own")
    p.add_argument("--probe", action="append", metavar="PIN=Dn", help="with --measure")
    p.add_argument("--evidence", type=Path, default=EVIDENCE)
    p.add_argument("--results", type=Path, default=RESULTS)
    for stage, seconds in TIMEOUT.items():
        p.add_argument("--timeout-" + stage, dest="t_" + stage, type=int,
                       help="seconds for the %s stage, %d unless set" % (stage, seconds))
    p.add_argument("--dry-run", action="store_true", help="print the commands and run nothing")
    args = p.parse_args()
    if bool(args.bitstream) == args.from_flash:
        sys.exit("one of --bitstream FILE and --from-flash")
    if args.measure and not args.probe:
        sys.exit("--measure needs --probe PIN=Dn")
    args.evidence = args.evidence.resolve()
    if args.bitstream:
        args.bitstream = args.bitstream.resolve()
    if not args.dry_run:
        if "PICO" not in os.environ:
            sys.exit("PICO=id:<serial of Pico A> is unset")
        if args.bitstream and not args.bitstream.is_file():
            sys.exit("no bitstream %s" % args.bitstream)
    sys.exit(Job(args, Runner(args.dry_run)).go())


if __name__ == "__main__":
    main()
