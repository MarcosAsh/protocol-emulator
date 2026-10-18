# SPDX-License-Identifier: Apache-2.0
# The remote lab's worker. A job is a WaveDrom diagram and its frames, never firmware:
# generate.exe lab compiles it for the certified table interpreter and names a refusal
# before anything reaches the chip. A job the bench takes runs on the backend (bench: Pico A
# and analyser A, the Icepi reset before and after; rtl: the same script on the RTL in
# cocotb; model: none), anything else gets the model's trace, labelled simulated. Results go
# to RESULTS/<id>/ (result.json for playground/lab.html, SHA256SUMS), a bench run's also to
# EVIDENCE/<date>/lab/. Nothing listens: queues are polled files.
# Usage: python3 demo/lab.py submit JOB --queue DIR [--as NAME]
#        python3 demo/lab.py fake --queue DIR
#        [PICO=id:<serial of Pico A>] python3 demo/lab.py work (--queue DIR | --issues FILE)
#            --backend bench|rtl|model [--from-flash | --bitstream FILE] [--once] [--dry-run]

import argparse
import datetime
import fcntl
import hashlib
import json
import os
import re
import shutil
import sys
import tempfile
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(HERE))
import bench_run  # noqa: E402
import ledger  # noqa: E402
import sigrok  # noqa: E402

RESULTS = Path.home() / ".local/share/protocol-emulator/lab"
GENERATE = ROOT / "bin/generate.exe"
PICO_FILES = ["python/protocol_emulator.py", "python/pico_board.py", "python/bench.py",
              "python/demo_lab.py"]
FLASH = ["openFPGALoader", "-b", "icepi-zero", "-r"]
# the analyser runs this long; the script waits bench.START_MS before it loads the chip
CAPTURE_MS = 2000
TIMEOUT = {"check": 30, "health": 20, "load": 120, "copy": 60, "capture": 120, "log": 30,
           "decode": 60, "rtl": 900}
# per submitter, but all_bench_hour: bench runs an hour and a day, and jobs an hour
LIMITS = {"bench_hour": 3, "bench_day": 10, "jobs_hour": 30, "all_bench_hour": 30}
# jobs taken a poll, oldest first; the rest wait
QUEUE_TAKE = 50
# bench errors in a row before it counts as down, and for how long
DOWN_AFTER = 2
DOWN_S = 1800
SUBMITTER = re.compile(r"[A-Za-z0-9][A-Za-z0-9_-]{0,38}")
# what check.json may ask sigrok-cli for, word by word
DECODE_ARG = re.compile(r"-P|-A|uart:rx=D[0-7]:baudrate=\d{3,7}|uart=rx-data"
                        r"|rgb_led_ws281x:din=D[0-7]|rgb_led_ws281x=rgb:reset")
# kept off a published result: local paths, Pico A's serial, the USB tree
PRIVATE = {"run.txt", "make.txt", "scan.txt"}
LABELS = {
    "bench": "captured on the bench, analyser A on OUT0",
    "rtl": "rehearsed on the RTL in cocotb, not the bench",
    "model": "simulated: the model of the core, not the bench",
}


def iso(t):
    return datetime.datetime.fromtimestamp(t, datetime.timezone.utc).isoformat(
        timespec="seconds").replace("+00:00", "Z")


def sha256_text(text):
    return hashlib.sha256(text.encode()).hexdigest()


class Spool:
    """A directory queue: inbox/*.json envelopes (submitter, received, job), oldest first,
    each moved to done/ once answered."""

    def __init__(self, root):
        self.root = Path(root)
        for d in ("inbox", "done"):
            (self.root / d).mkdir(parents=True, exist_ok=True)

    def submit(self, job_text, submitter, now=None):
        now = time.time() if now is None else now
        name = "%d-%d.json" % (time.time_ns(), os.getpid())
        envelope = {"submitter": submitter, "received": iso(now), "job": job_text,
                    "ref": "spool:" + name}
        tmp = self.root / ("." + name)
        tmp.write_text(json.dumps(envelope))
        tmp.rename(self.root / "inbox" / name)
        return self.root / "inbox" / name

    def pending(self):
        items = []
        for path in sorted((self.root / "inbox").glob("*.json"))[:QUEUE_TAKE]:
            try:
                envelope = json.loads(path.read_text())
            except ValueError:
                envelope = {"submitter": "?", "received": "?", "job": None}
            envelope["ref"] = "spool:" + path.name
            items.append((path, envelope))
        return items

    def done(self, item, outcome):
        path, _ = item
        shutil.move(str(path), str(self.root / "done" / path.name))


class Issues:
    """What `gh issue list --label lab --json number,author,createdAt,body` printed, saved
    to FILE by whatever fetched it: a job is the body's first ```json block. Read only;
    the issues answered are kept in RESULTS/issues_taken."""

    FENCE = re.compile(r"```json\s*\n(.*?)\n```", re.S)

    def __init__(self, path, results):
        self.path = Path(path)
        self.taken = Path(results) / "issues_taken"

    def seen(self):
        return set(self.taken.read_text().split()) if self.taken.exists() else set()

    def pending(self):
        seen = self.seen()
        items = []
        for issue in sorted(json.loads(self.path.read_text()), key=lambda i: i["createdAt"]):
            ref = "issue#%d" % int(issue["number"])
            if ref in seen:
                continue
            found = self.FENCE.search(issue.get("body") or "")
            items.append((ref, {"submitter": (issue.get("author") or {}).get("login", "?"),
                                "received": issue["createdAt"], "ref": ref,
                                "job": found.group(1) if found else None}))
        return items[:QUEUE_TAKE]

    def done(self, item, outcome):
        with open(self.taken, "a") as f:
            f.write(item[0] + "\n")


class Limits:
    """RESULTS/admitted.tsv: time, submitter, job id, and the run it had."""

    def __init__(self, path, limits):
        self.path = Path(path)
        self.limits = limits

    def rows(self):
        if not self.path.exists():
            return []
        rows = []
        for line in self.path.read_text().splitlines():
            t, who, ident, run = line.split("\t")
            rows.append((float(t), who, ident, run))
        return rows

    def count(self, now, seconds, who=None, bench=False):
        return sum(1 for t, w, _, run in self.rows()
                   if now - t < seconds and (who is None or w == who)
                   and (not bench or run in ("bench", "rtl")))

    def jobs(self, who, now):
        """Why the job is not checked at all, or None."""
        n = self.count(now, 3600, who)
        if n >= self.limits["jobs_hour"]:
            return "rate limited: %d jobs from %s this hour" % (n, who)
        return None

    def bench(self, who, now):
        """Why the job gets the model and not the bench, or None."""
        for seconds, key, who_ in ((3600, "bench_hour", who), (86400, "bench_day", who),
                                   (3600, "all_bench_hour", None)):
            n = self.count(now, seconds, who_, bench=True)
            if n >= self.limits[key]:
                return "rate limited: %d bench runs %s this %s" % (
                    n, "from " + who if who_ else "in all", "hour" if seconds == 3600 else "day")
        return None

    def record(self, now, who, ident, run):
        with open(self.path, "a") as f:
            f.write("%f\t%s\t%s\t%s\n" % (now, who, ident, run or "-"))


class Stages(bench_run.Runner):
    """bench_run's runner, logging to run.txt in a folder that already exists; with dry_run
    it prints each stage and says it passed."""

    def open(self, directory):
        if not self.dry_run:
            self.log = open(directory / "run.txt", "a")


class Bench:
    """Pico A and analyser A as demo/outside.sh drives them, the Icepi reset to its flash
    (or BITSTREAM loaded) before and after every job, so faults never carry over and the
    pins go back to idle."""

    name = "bench"

    def __init__(self, runner, pico, bitstream):
        self.runner, self.pico, self.bitstream = runner, pico, bitstream
        self.bitstream_sha256 = ledger.sha256(bitstream) if bitstream else "flash"

    def mpremote(self, *args):
        return ["mpremote", "connect", self.pico, *args]

    def reset(self):
        argv = (["openFPGALoader", "-b", "icepi-zero", str(self.bitstream)] if self.bitstream
                else FLASH)
        stage = self.runner.run("load", argv, TIMEOUT["load"])
        self.runner.sleep(2)
        return stage.status == 0

    def healthy(self, folder):
        """Why the bench cannot take a job now, or None."""
        r = self.runner
        r.open(folder)
        try:
            if r.run("health", self.mpremote("exec", "print('lab')"), TIMEOUT["health"]).status:
                return "Pico A does not answer"
            out = folder / "scan.txt"
            if r.run("scan", ["sigrok-cli", "--scan"], TIMEOUT["health"], out=out).status or (
                    not r.dry_run and "fx2lafw" not in out.read_text()):
                return "no analyser"
            return None
        finally:
            r.close()

    def run(self, folder, firmware):
        """Whether every stage ran; the capture is folder/lab.sr, Pico A's log lab.log."""
        r = self.runner
        r.open(folder)
        try:
            ok = self.reset()
            stages = [
                ("copy", self.mpremote("cp", *PICO_FILES, ":"), {}),
                ("copy", self.mpremote("cp", str(firmware), ":lab.json"), {}),
                ("copy", self.mpremote("exec", "import os\ntry:\n    os.remove('outside.log')"
                                       "\nexcept OSError:\n    pass"), {}),
                ("capture", ["demo/capture.sh", str(folder / "lab.sr"), str(CAPTURE_MS),
                             *self.mpremote("run", "--no-follow", "python/demo_lab.py")],
                 {"env": {"ANALYSER": "A"}}),
            ]
            for name, argv, kw in stages:
                ok = ok and r.run(name, argv, TIMEOUT[name], **kw).status == 0
            r.sleep(1)
            ok = ok and r.run("log", self.mpremote("cat", ":outside.log"), TIMEOUT["log"],
                              out=folder / "lab.log").status == 0
            return ok
        finally:
            # the pins back to idle whatever happened
            self.reset()
            r.close()


class Rtl:
    """test/test_lab_rtl.py through make lab: the script Pico A runs, on the RTL."""

    name = "rtl"
    bitstream_sha256 = "-"

    def __init__(self, runner):
        self.runner = runner

    def healthy(self, folder):
        return None

    def run(self, folder, firmware):
        r = self.runner
        r.open(folder)
        try:
            env = {"LAB_FIRMWARE": str(firmware), "LAB_OUT": str(folder)}
            return r.run("rtl", ["make", "-C", "test", "lab"], TIMEOUT["rtl"], env=env,
                         out=folder / "make.txt").status == 0
        finally:
            r.close()


def changes(edges, ns_a_step):
    """[t, level] pairs, the first the starting level, as (ns, level) of each change."""
    return [(t * ns_a_step, level) for t, level in edges[1:]]


def captured(sr, channel):
    """The capture's rate, its starting level and each change on channel, (ns, level)."""
    rate, names, samples = sigrok.read(sr)
    bit = {name: b for b, name in names.items()}[channel]
    at, levels = sigrok.edges(samples, bit)
    first = (samples[0] >> bit) & 1 if samples else 0
    return rate, first, [(int(a) * 1e9 / rate, int(level)) for a, level in zip(at, levels)]


def compare(model, capture, rate):
    """The capture against the model's changes, aligned on whichever of the capture's first
    64 changes lines the most of them up: each interval within two samples and 200 ppm, the
    two crystals'."""
    if not model:
        return {"verdict": "matches the model" if not capture else "differs",
                "why": "the model's lane never changes", "changes": len(capture)}
    sample = 1e9 / rate
    best = (-1, None, 0.0)
    for start in range(min(64, len(capture))):
        if capture[start][1] != model[0][1]:
            continue
        lined, worst = 1, 0.0
        for i in range(1, len(model)):
            if start + i >= len(capture) or capture[start + i][1] != model[i][1]:
                break
            want = model[i][0] - model[i - 1][0]
            got = capture[start + i][0] - capture[start + i - 1][0]
            if abs(got - want) > 2 * sample + 2e-4 * want:
                break
            lined, worst = i + 1, max(worst, abs(got - want))
        if lined > best[0]:
            best = (lined, start, worst)
        if lined == len(model):
            break
    lined, start, worst = best
    out = {"model_changes": len(model), "lined_up": max(lined, 0), "worst_ns": round(worst, 1),
           "tolerance": "two samples (%.1f ns) and 200 ppm an interval" % (2 * sample)}
    if lined == len(model):
        out.update(verdict="matches the model", start=start,
                   extra=len(capture) - start - len(model))
    elif start is None:
        out.update(verdict="differs", why="no change on the capture to the model's first level")
    else:
        i = lined
        want = model[i][0] - model[i - 1][0]
        got = (capture[start + i][0] - capture[start + i - 1][0]
               if start + i < len(capture) else None)
        out.update(verdict="differs", start=start,
                   why="change %d: the model %.1f ns after the last, the capture %s" % (
                       i, want, "has no more" if got is None else "%.1f ns" % got))
    return out


class Worker:
    def __init__(self, args, queue, backend, runner, clock=time.time):
        self.args, self.queue, self.backend, self.runner, self.clock = (
            args, queue, backend, runner, clock)
        self.results = Path(args.results)
        self.limits = Limits(self.results / "admitted.tsv", args.limits)
        self.errors, self.down_until = 0, 0.0

    def check(self, job_text, out):
        """generate.exe lab's exit status and check.json, the binary called directly so no
        dune runs beside anything else."""
        job = out / "submitted.json"
        job.write_text(job_text)
        stage = self.runner.run("check", [str(self.args.generate), "lab", str(job), "-out",
                                          str(out)], TIMEOUT["check"],
                                out=out / "check.txt")
        job.unlink()
        path = out / "check.json"
        return stage.status, (json.loads(path.read_text()) if path.exists() else None)

    def choose(self, check, who, now, folder):
        """The run, the backend's name or "model", and why it is not the backend."""
        bench = check["bench"]
        if not bench["takes"]:
            return "model", "the bench declines it: " + bench["why"]
        if self.backend is None:
            return "model", "this worker runs the model alone"
        why = self.limits.bench(who, now)
        if why:
            return "model", why
        if now < self.down_until:
            return "model", "the bench is down until %s" % iso(self.down_until)
        why = self.backend.healthy(folder)
        if why:
            return "model", "the bench is down: " + why
        return self.backend.name, None

    def process(self, item):
        r, a = self.runner, self.args
        _, envelope = item
        who = envelope.get("submitter") or "?"
        who = who if SUBMITTER.fullmatch(who) else "unnamed"
        now = self.clock()
        result = {"lab": 1, "received": envelope.get("received"), "started": iso(now),
                  "commit": ledger.commit(), "verdict": None, "run": None}
        why = self.limits.jobs(who, now)
        work = Path(tempfile.mkdtemp(prefix=".work-", dir=self.results))
        job_text = envelope.get("job")
        if why or not isinstance(job_text, str):
            result.update(verdict="rate limited" if why else "malformed",
                          why=why or "no job in the submission")
            status, check = None, None
        else:
            status, check = self.check(job_text, work)
        if check is not None:
            result["verdict"] = check["verdict"]
            result["check"] = check
        elif status is not None:
            result.update(verdict="malformed", why="the checker failed, status %s" % status)
        job_file = work / "job.json"
        ident = (ledger.sha256(job_file) if job_file.exists() else
                 sha256_text(job_text if isinstance(job_text, str) else json.dumps(envelope)))
        result["id"] = ident[:16]
        result["job_sha256"] = ident
        folder = self.results / result["id"]
        if (folder / "result.json").exists() and result["verdict"] not in ("rate limited",):
            shutil.rmtree(work)
            self.limits.record(now, who, result["id"], "duplicate")
            self.queue.done(item, "duplicate")
            print("%s %s: duplicate of %s" % (envelope.get("ref"), who, folder))
            return folder
        if folder.exists():
            shutil.rmtree(folder)
        work.rename(folder)
        run, why = (None, None)
        if result["verdict"] == "certified":
            run, why = self.choose(check, who, now, folder)
            if run != "model":
                ok = (self.backend.run(folder, folder / "firmware.json")
                      and (self.backend.runner.dry_run or (folder / "lab.sr").exists()))
                self.errors = 0 if ok else self.errors + 1
                if self.errors >= DOWN_AFTER:
                    self.down_until = now + DOWN_S
                if not ok:
                    run, why = "model", "the %s run failed, see run.txt" % self.backend.name
            result.update(run=run, label=LABELS[run], why=why)
            self.finish(folder, result, run)
        self.limits.record(now, who, result["id"], run)
        result["finished"] = iso(self.clock())
        seal(folder, result)
        if run == "bench" and not r.dry_run:
            evidence = ledger.fresh(a.evidence / now_date(now) / "lab", result["id"])
            shutil.copytree(folder, evidence)
        append(self.results / "lab.tsv", [result["finished"], result["id"], who,
                                          result["verdict"], run or "-",
                                          result.get("match", {}).get("verdict", "-")])
        self.queue.done(item, result["verdict"])
        print("%s %s: %s, %s: %s" % (envelope.get("ref"), who, result["verdict"],
                                     result.get("label", "not run"), folder))
        return folder

    def finish(self, folder, result, run):
        """The model's trace beside the capture, the two compared, and sigrok's decode."""
        simulated = json.loads((folder / "simulated.json").read_text())
        result["simulated"] = simulated
        result["certificate"] = (folder / "certificate.txt").read_text()
        firmware = folder / "firmware.json"
        if firmware.exists():
            words = json.loads(firmware.read_text())["words"]
            result["interpreter_sha256"] = sha256_text(json.dumps(words))
            result["firmware_sha256"] = ledger.sha256(firmware)
        if run == "model":
            return
        result["bitstream_sha256"] = self.backend.bitstream_sha256
        sr, log = folder / "lab.sr", folder / "lab.log"
        result["pico_log"] = log.read_text() if log.exists() else None
        if not sr.exists():
            result["match"] = {"verdict": "differs", "why": "no capture"}
            return
        bench = result["check"]["bench"]
        rate, first, capture = captured(sr, bench["channel"])
        lane = simulated["lanes"][0]
        model = changes(lane["edges"], 1e9 / simulated["clock_hz"])
        result["match"] = compare(model, capture, rate)
        start = result["match"].get("start") or 0
        result["captured"] = {
            "rate": rate, "channel": bench["channel"], "pin": bench["pin"],
            "first": first, "capture_sha256": ledger.sha256(sr),
            # from the change the model lines up with, at most the model's and a few more
            "changes": [[round(t, 1), level] for t, level in
                        capture[start:start + len(model) + 64]],
        }
        args = bench.get("decode") or []
        if args and all(DECODE_ARG.fullmatch(w) for w in args):
            out = folder / "decode.txt"
            self.runner.open(folder)
            self.runner.run("decode", ["sigrok-cli", "-i", str(sr), *args], TIMEOUT["decode"],
                            out=out)
            self.runner.close()
            result["decode"] = out.read_text() if out.exists() else None

    def work(self):
        while True:
            for item in self.queue.pending():
                self.process(item)
            if self.args.once:
                return
            time.sleep(self.args.poll)


def now_date(t):
    return datetime.datetime.fromtimestamp(t).date().isoformat()


def seal(folder, result):
    """result.json with every other file's hash in it, then SHA256SUMS over them all."""
    files = sorted(p for p in folder.rglob("*")
                   if p.is_file() and p.name not in ("result.json", "SHA256SUMS"))
    result["files"] = {str(p.relative_to(folder)): ledger.sha256(p) for p in files}
    result["public"] = sorted(["result.json"] + [n for n in result["files"] if n not in PRIVATE])
    (folder / "result.json").write_text(json.dumps(result, indent=1) + "\n")
    files.append(folder / "result.json")
    (folder / "SHA256SUMS").write_text("".join(
        "%s  %s\n" % (ledger.sha256(p), p.relative_to(folder)) for p in sorted(files)))


def append(path, row):
    with open(path, "a") as f:
        f.write("\t".join(str(c) for c in row) + "\n")


def fake(queue):
    """test/diagrams' host-fed diagrams with their playground frames, ws2812 with T1H drawn
    too long, a receiver, a malformed job, and one submitter past the hourly cap."""
    frames = {"uart_tx": "11000101\n00111010", "dshot": "1000001011000110",
              "ws2812": "000100001111111100000000", "uart_rx": "11000101\n00111010"}
    decode = {"uart_tx": "uart:1846154", "ws2812": "ws281x"}

    def job(diagram, frames, decode="none"):
        return json.dumps({"lab": 1, "diagram": diagram, "frames": frames, "decode": decode})

    def diagram(name):
        return (ROOT / "test/diagrams" / (name + ".json")).read_text()

    for name, f in frames.items():
        queue.submit(job(diagram(name), f, decode.get(name, "none")), "judge-" + name)
    slow = diagram("ws2812").replace("[0, 26, 19, 28, 2496]", "[0, 26, 21, 28, 2496]")
    queue.submit(job(slow, frames["ws2812"]), "judge-slow")
    queue.submit('{"lab": 1, "firmware": [1, 2, 3]}', "judge-firmware")
    for i in range(4):
        queue.submit(job(diagram("uart_tx"), format(i, "08b")), "spammer")


def limits(text):
    out = dict(LIMITS)
    for pair in filter(None, (text or "").split(",")):
        key, value = pair.split("=")
        if key not in out:
            raise argparse.ArgumentTypeError("no limit %s" % key)
        out[key] = int(value)
    return out


def main():
    p = argparse.ArgumentParser()
    sub = p.add_subparsers(dest="command", required=True)
    s = sub.add_parser("submit")
    s.add_argument("job", type=Path)
    s.add_argument("--queue", type=Path, required=True)
    s.add_argument("--as", dest="submitter", default="local")
    f = sub.add_parser("fake")
    f.add_argument("--queue", type=Path, required=True)
    w = sub.add_parser("work")
    w.add_argument("--queue", type=Path)
    w.add_argument("--issues", type=Path, help="gh issue list's JSON, fetched by something else")
    w.add_argument("--backend", choices=["bench", "rtl", "model"], required=True)
    w.add_argument("--bitstream", type=Path)
    w.add_argument("--from-flash", action="store_true")
    w.add_argument("--results", type=Path, default=RESULTS / "results")
    w.add_argument("--evidence", type=Path, default=ledger.EVIDENCE)
    w.add_argument("--generate", type=Path, default=GENERATE)
    w.add_argument("--limits", type=limits, default=dict(LIMITS),
                   help="key=n,... over %s" % ",".join(LIMITS))
    w.add_argument("--poll", type=float, default=30)
    w.add_argument("--once", action="store_true")
    w.add_argument("--dry-run", action="store_true", help="print the bench's commands")
    a = p.parse_args()
    if a.command == "submit":
        print(Spool(a.queue).submit(a.job.read_text(), a.submitter))
        return
    if a.command == "fake":
        fake(Spool(a.queue))
        return
    if bool(a.queue) == bool(a.issues):
        sys.exit("one of --queue DIR and --issues FILE")
    if a.backend == "bench":
        if bool(a.bitstream) == a.from_flash:
            sys.exit("the bench needs one of --bitstream FILE and --from-flash")
        if "PICO" not in os.environ and not a.dry_run:
            sys.exit("PICO=id:<serial of Pico A> is unset")
    if not a.generate.exists():
        sys.exit("no %s: dune build --root . bin/generate.exe first" % a.generate)
    a.results.mkdir(parents=True, exist_ok=True)
    # one worker a results folder, so two never drive the bench at once
    lock = open(a.results / "worker.lock", "w")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        sys.exit("another worker holds %s" % (a.results / "worker.lock"))
    backend = {"bench": lambda: Bench(Stages(a.dry_run), os.environ.get("PICO", "$PICO"),
                                      a.bitstream and a.bitstream.resolve()),
               "rtl": lambda: Rtl(Stages(False)),
               "model": lambda: None}[a.backend]()
    queue = Spool(a.queue) if a.queue else Issues(a.issues, a.results)
    Worker(a, queue, backend, Stages(False)).work()


if __name__ == "__main__":
    main()
