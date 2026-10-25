# SPDX-License-Identifier: Apache-2.0
"""demo/lab.py against stand-ins for the checker (test/lab's examples), openFPGALoader,
mpremote and sigrok-cli, so no board and no OCaml: what reaches the bench and what never
does, the fallbacks to the model, the limits, the seal."""

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "demo"))
import lab  # noqa: E402

EXAMPLES = ROOT / "test/lab"
# the checker: an example's files for a job whose diagram is the example's, the job as sent
GENERATE = """#!%s
import json, os, shutil, sys
from pathlib import Path
_, _, job, _, out = sys.argv
text = Path(job).read_text()
try:
    sent = json.loads(text)
except ValueError:
    sent = {}
for example in sorted(Path(%r).glob("*.job.json")):
    if set(sent) <= {"lab", "diagram", "frames", "decode"} and \\
            json.loads(example.read_text())["diagram"] == sent.get("diagram"):
        shutil.copytree(example.with_name(example.name[:-len(".job.json")]), out, dirs_exist_ok=True)
        Path(out, "job.json").write_text(text)
        verdict = json.loads(Path(out, "check.json").read_text())["verdict"]
        sys.exit({"certified": 0, "refused": 1}[verdict])
os.makedirs(out, exist_ok=True)
Path(out, "check.json").write_text(json.dumps({"verdict": "malformed", "why": "no example"}))
sys.exit(2)
""" % (sys.executable, str(EXAMPLES))
STANDINS = {
    "openFPGALoader": 'echo "$*" >> "$TMP/loads"\n',
    "mpremote": """echo "$*" >> "$TMP/mpremote"
shift 2
case $1 in
exec) [ -z "$PICO_DOWN" ] ;;
cat) printf 'ran 2 ms, faults 0x0, the model'"'"'s 0x0\\nPASS\\n' ;;
esac
""",
    "sigrok-cli": """while [ $# -gt 0 ]; do
    case $1 in
    --scan) [ -n "$NO_ANALYSER" ] || echo "fx2lafw:conn=3.4 - Saleae Logic"; exit 0 ;;
    -o) cp "$RAW" "$2"; exit 0 ;;
    -i) echo "uart-1: A3"; echo "uart-1: 5C"; exit 0 ;;
    esac
    shift
done
""",
}


def raw(stretch=0):
    """Analyser A's samples of OUT0 at 24 MS/s for the uart_tx example: idle, two glitches,
    then the model's changes, the fifth interval stretch samples long."""
    simulated = json.loads((EXAMPLES / "uart_tx/simulated.json").read_text())
    edges = simulated["lanes"][0]["edges"]
    lead = 5000
    changes = [(1000, 1), (1003, 0)] + [
        (lead + c // 2 + (stretch if i >= 5 else 0), level) for i, (c, level) in enumerate(edges[1:])]
    samples, level, at = bytearray(), 0, 0
    for t, new in changes:
        samples += bytes([level << 4]) * (t - at)
        level, at = new, t
    samples += bytes([level << 4]) * 4000
    return bytes(samples)


def job(name, frames=None):
    j = json.loads((EXAMPLES / (name + ".job.json")).read_text())
    if frames is not None:
        j["frames"] = frames
    return json.dumps(j)


class Worker(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        bin = self.tmp / "bin"
        bin.mkdir()
        for name, body in STANDINS.items():
            (bin / name).write_text("#!/bin/sh\n" + body)
            (bin / name).chmod(0o755)
        self.generate = bin / "generate.exe"
        self.generate.write_text(GENERATE)
        self.generate.chmod(0o755)
        (self.tmp / "raw.bin").write_bytes(raw())
        self.env = {k: v for k, v in os.environ.items() if not k.startswith("ANALYSER")}
        self.env.update(PATH="%s:%s" % (bin, os.environ["PATH"]), PICO="id:a",
                        TMP=str(self.tmp), RAW=str(self.tmp / "raw.bin"), TRIES="1")
        self.queue = lab.Spool(self.tmp / "queue")
        self.results = self.tmp / "results"

    def work(self, *args, backend="bench", **env):
        run = subprocess.run(
            [sys.executable, str(ROOT / "demo/lab.py"), "work", "--queue", str(self.tmp / "queue"),
             "--backend", backend, "--once", "--results", str(self.results),
             "--evidence", str(self.tmp / "evidence"), "--generate", str(self.generate),
             *(["--from-flash"] if backend == "bench" else []), *args],
            env=self.env | env, capture_output=True, text=True, timeout=120)
        self.assertEqual(run.returncode, 0, run.stdout + run.stderr)
        return run

    def results_of(self):
        return [json.loads(p.read_text()) for p in sorted(self.results.glob("*/result.json"),
                                                          key=lambda p: p.stat().st_mtime)]

    def lines(self, name):
        path = self.tmp / name
        return path.read_text().splitlines() if path.exists() else []

    def test_a_bench_run_matches_the_model_and_is_sealed(self):
        self.queue.submit(job("uart_tx"), "judge")
        self.work()
        (r,) = self.results_of()
        self.assertEqual((r["verdict"], r["run"]), ("certified", "bench"))
        self.assertEqual(r["match"]["verdict"], "matches the model", r["match"])
        self.assertEqual(r["decode"], "uart-1: A3\nuart-1: 5C\n")
        self.assertIn("PASS", r["pico_log"])
        self.assertEqual(r["bitstream_sha256"], "flash")
        # reset before and after, and only lab.json and the scripts copied over
        self.assertEqual(self.lines("loads"), ["-b icepi-zero -r"] * 2)
        copies = [line for line in self.lines("mpremote") if " cp " in line]
        self.assertEqual(copies[1].split()[-2:], [str(self.results / r["id"] / "firmware.json"),
                                                  ":lab.json"])
        folder = self.results / r["id"]
        subprocess.run(["sha256sum", "--quiet", "-c", "SHA256SUMS"], cwd=folder, check=True)
        self.assertNotIn("run.txt", r["public"])
        self.assertTrue(list((self.tmp / "evidence").glob("*/lab/" + r["id"] + "/lab.sr")))
        self.assertEqual(list((self.tmp / "queue/inbox").iterdir()), [])

    def test_a_refusal_never_reaches_the_bench(self):
        self.queue.submit(job("ws2812_slow"), "judge")
        self.work()
        (r,) = self.results_of()
        self.assertEqual((r["verdict"], r["run"]), ("refused", None))
        self.assertIn("T1H", r["check"]["certificate"])
        self.assertEqual((self.lines("loads"), self.lines("mpremote")), ([], []))

    def test_firmware_is_not_a_job(self):
        self.queue.submit('{"lab": 1, "firmware": [1, 2, 3]}', "judge")
        self.work()
        (r,) = self.results_of()
        self.assertEqual(r["verdict"], "malformed")
        self.assertEqual((self.lines("loads"), self.lines("mpremote")), ([], []))

    def test_what_the_bench_declines_gets_the_model(self):
        self.queue.submit(job("uart_rx"), "judge")
        self.work()
        (r,) = self.results_of()
        self.assertEqual(r["run"], "model")
        self.assertTrue(r["label"].startswith("simulated"))
        self.assertTrue(r["why"].startswith("the bench declines it"), r["why"])
        self.assertIn("simulated", r)
        self.assertEqual(self.lines("loads"), [])

    def test_a_bench_that_is_down_gives_the_model(self):
        self.queue.submit(job("uart_tx"), "judge")
        self.work(PICO_DOWN="1")
        (r,) = self.results_of()
        self.assertEqual((r["run"], r["why"]), ("model", "the bench is down: Pico A does not answer"))
        self.assertEqual(self.lines("loads"), [])

    def test_a_capture_that_strays_differs(self):
        (self.tmp / "raw.bin").write_bytes(raw(stretch=4))
        self.queue.submit(job("uart_tx"), "judge")
        self.work()
        (r,) = self.results_of()
        self.assertEqual(r["run"], "bench")
        self.assertEqual(r["match"]["verdict"], "differs")
        self.assertIn("change 5", r["match"]["why"])

    def test_limits_and_duplicates(self):
        for frames in ("11000101", "00111010", "11000101"):
            self.queue.submit(job("uart_tx", frames), "same")
        self.work("--limits", "bench_hour=1")
        first, second = self.results_of()
        self.assertEqual(first["run"], "bench")
        self.assertEqual((second["run"], second["why"]),
                         ("model", "rate limited: 1 bench runs from same this hour"))
        self.assertEqual(len(self.lines("loads")), 2)
        self.assertIn("duplicate", (self.results / "admitted.tsv").read_text())
        for frames in ("10000000", "01000000"):
            self.queue.submit(job("uart_tx", frames), "same")
        self.work("--limits", "jobs_hour=4")
        self.assertEqual([r["verdict"] for r in self.results_of()][-1], "rate limited")

    def test_issues(self):
        issues = self.tmp / "issues.json"
        issues.write_text(json.dumps([
            {"number": 7, "author": {"login": "judge"}, "createdAt": "2026-10-18T10:00:00Z",
             "body": "please\n```json\n%s\n```\n" % job("uart_rx")},
            {"number": 8, "author": {"login": "bad name!"}, "createdAt": "2026-10-18T10:01:00Z",
             "body": "no job here"}]))
        args = ["--issues", str(issues), "--backend", "model", "--once", "--results",
                str(self.results), "--generate", str(self.generate)]
        for _ in range(2):
            subprocess.run([sys.executable, str(ROOT / "demo/lab.py"), "work", *args],
                           env=self.env, check=True, capture_output=True, timeout=60)
        rows = (self.results / "admitted.tsv").read_text().splitlines()
        self.assertEqual([r.split("\t")[1] for r in rows], ["judge", "unnamed"])
        self.assertEqual({r["verdict"] for r in self.results_of()}, {"certified", "malformed"})


class Compare(unittest.TestCase):
    def test_aligns_past_glitches(self):
        model = [(100.0, 1), (600.0, 0), (1100.0, 1)]
        capture = [(5.0, 1), (7.0, 0), (2000.0, 1), (2500.0, 0), (3000.0, 1), (3500.0, 0)]
        m = lab.compare(model, capture, 24e6)
        self.assertEqual((m["verdict"], m["start"], m["extra"]), ("matches the model", 2, 1))

    def test_past_the_tolerance(self):
        model = [(0.0, 1), (10_000.0, 0)]
        capture = [(0.0, 1), (10_000.0 + 2 * 1e9 / 24e6 + 3, 0)]
        self.assertEqual(lab.compare(model, capture, 24e6)["verdict"], "differs")


if __name__ == "__main__":
    unittest.main()
