# SPDX-License-Identifier: Apache-2.0
# demo/margins.py on captures made from test/measure's predictions at 100 MHz, 10 ns a
# sample, in the CSV LogicAnalyzer's TerminalCapture saves: exact edges, edges a sample
# either way at random, one edge 300 ns late that must fail its limit, a drifting
# analyser clock, and the same read back from a sigrok session file. Then
# python/demo_predicted.py's feed of a prediction's words, on a stand-in for the chip.
# Usage: python3 test/test_margins.py

import os
import random
import re
import subprocess
import sys
import tempfile

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEMO = os.path.join(ROOT, "demo")
sys.path[:0] = [DEMO, os.path.join(ROOT, "python")]
import demo_predicted  # noqa: E402
import logic_analyzer  # noqa: E402
import margins  # noqa: E402

RATE = 100_000_000
SAMPLE_NS = 1e9 / RATE


def prediction(name):
    return os.path.join(ROOT, "test", "measure", name + ".predicted")


def capture(path, predicted, channels, start, jitter=0, late=None, ppm=0.0, seed=0):
    """The prediction's pins on channels from 1, the line held as it is before cycle
    start, as on a bench whose line idled before the capture; 2 us of it first. late:
    (pin, edge from start, samples) moves one edge later."""
    p = margins.read_prediction(predicted)
    rng = random.Random(seed)
    cycle_ns = 1e9 / p["rate"]
    t0 = start * cycle_ns - 2_000
    changes, idle, last = [], [], 0
    for pin in channels:
        first, at = p["lines"][pin]
        kept = [c for c in at if c >= start]
        level = (first + len(at) - len(kept)) % 2
        idle.append(level)
        for n, c in enumerate(kept):
            k = int(-(-((c * cycle_ns - t0) * (1 + ppm * 1e-6)) // SAMPLE_NS))
            k += rng.choice([-1, 0, 1]) if jitter else 0
            if late and late[0] == pin and late[1] == n:
                k += late[2]
            level ^= 1
            changes.append((k, len(idle) - 1, level))
            last = max(last, k)
    samples = np.full(last + 2000, sum(v << b for b, v in enumerate(idle)), dtype=np.uint8)
    for k, bit, level in sorted(changes):
        samples[k:] = (samples[k:] & ~np.uint8(1 << bit)) | np.uint8(level << bit)
    logic_analyzer.write(path, ["Channel %d" % (i + 1) for i in range(len(channels))],
                         samples.tobytes())


def run(*args):
    done = subprocess.run([sys.executable, os.path.join(DEMO, "margins.py"), *args],
                          capture_output=True, text=True)
    if done.stderr.strip() and "Traceback" in done.stderr:
        raise SystemExit(done.stderr)
    return done.returncode, done.stdout


def summary(out):
    """matched, expected, missing, extra, off; the ppm."""
    m = re.search(r"edges: (\d+) of (\d+) matched, (\d+) missing, (\d+) extra, (\d+) off", out)
    ppm = float(re.search(r"clock ([-+][\d.]+) ppm", out).group(1))
    return tuple(map(int, m.groups())), ppm


def errors(out):
    return [float(m.group(1)) for m in re.finditer(r"^\s+\d+\s+\S+\s+(?:rise|fall)\s+\d+"
                                                   r"\s+\S+\s+\S+\s+([-+][\d.]+)", out, re.M)]


failures = []


class Chip:
    """The host side of an engine that takes a word from its fifo at each status read."""

    def __init__(self):
        self.fifo, self.taken, self.most = [], [], 0

    def select(self, engine):
        pass

    def read(self, reg, count=1):
        return [0]

    def stop(self):
        pass

    flush = start = stop

    def configure(self, config):
        pass

    def load(self, words):
        pass

    def push(self, words):
        self.fifo += words
        self.most = max(self.most, len(self.fifo))

    def status(self):
        level = len(self.fifo)
        if self.fifo:
            self.taken.append(self.fifo.pop(0))
        return {"tx_level": level}


def check(what, ok, out):
    print("%s %s" % ("PASS" if ok else "FAIL", what))
    if not ok:
        failures.append(what)
        print(out)


def main():
    uart = prediction("uart_tx_115200")
    i2c = prediction("i2c_standard")
    # OUT0 is pin 5; SCL on IO2 is 14 and SDA on IO3 15
    i2c_start = min(at[0] for _, at in margins.read_prediction(i2c)["lines"].values())
    with tempfile.TemporaryDirectory() as scratch:
        def path(name):
            return os.path.join(scratch, name)

        capture(path("exact.csv"), uart, [5], start=8)
        status, out = run(uart, path("exact.csv"), "--rate", "100M", "OUT0=1")
        (matched, expected, missing, extra, off), _ = summary(out)
        check("uart exact: every edge matched within a sample, no limit fails",
              status == 0 and matched == expected == 20 and missing == extra == off == 0
              and all(abs(e) <= SAMPLE_NS for e in errors(out)) and "FAIL" not in out, out)

        capture(path("jitter.csv"), uart, [5], start=8, jitter=1, seed=3)
        status, out = run(uart, path("jitter.csv"), "--rate", "100M", "OUT0=1")
        (matched, expected, missing, extra, off), _ = summary(out)
        check("uart a sample either way: matched, within two samples, nothing fails",
              status == 0 and matched == expected and off == 0
              and all(abs(e) <= 2 * SAMPLE_NS for e in errors(out)), out)

        # the fourth edge from the start ends the second low bit: 300 ns later stretches it
        # past 2% of the bit
        try:
            import matplotlib  # noqa: F401
            plot = ["-o", path("late.png")]
        except ImportError:
            plot = []
        capture(path("late.csv"), uart, [5], start=8, late=(5, 3, 30))
        status, out = run(uart, path("late.csv"), "--rate", "100M", "OUT0=1", *plot)
        line = next((x for x in out.splitlines() if "LATE" in x), "")
        margin = re.search(r"bit <= 8854.17: ([-+][\d.]+) FAIL", line)
        check("uart one edge 300 ns late: flagged LATE and fails bit <= 8854.17 by ~133 ns",
              status == 1 and margin is not None and abs(float(margin.group(1)) + 133.3) < 15
              and re.search(r"bit <= 8854.17\s+FAIL", out) is not None, out)
        if not plot:
            print("SKIP the plot: no matplotlib")
        else:
            with open(path("late.png"), "rb") as f:
                check("the plot is a PNG", f.read(8) == b"\x89PNG\r\n\x1a\n", out)

        capture(path("drift.csv"), i2c, [14, 15], start=i2c_start, ppm=40)
        status, out = run(i2c, path("drift.csv"), "--rate", "100M", "IO2=1", "IO3=2")
        (matched, expected, missing, extra, off), ppm = summary(out)
        check("i2c, the analyser 40 ppm fast: found as such, every edge within a sample",
              status == 0 and matched == expected > 100 and off == 0 and abs(ppm - 40) < 5
              and all(abs(e) <= SAMPLE_NS for e in errors(out)), out)

        capture(path("i2c.csv"), i2c, [14, 15], start=i2c_start, jitter=1, seed=5)
        subprocess.run([sys.executable, os.path.join(DEMO, "logic_analyzer.py"),
                        path("i2c.csv"), "100M", path("i2c.sr")], check=True)
        status, out = run(i2c, path("i2c.sr"), "IO2=Channel 1", "IO3=Channel 2")
        (matched, expected, missing, extra, off), _ = summary(out)
        check("i2c a sample either way, from a sigrok session file: nothing fails",
              status == 0 and matched == expected and off == 0 and "FAIL" not in out, out)
    name, bursts, length = demo_predicted.read(i2c)
    chip = Chip()
    demo_predicted.run(chip, {"config": {}, "words": []}, bursts)
    check("the feed: the load then i2c_standard's burst, in order, the fifo never past 8",
          name == "i2c_standard" and length == 48400 and chip.most <= 8
          and chip.taken == [121] + [int(w) for w in open(i2c).read().split("burst ")[1]
                                     .split("\n")[0].split()], str(chip.taken))
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
