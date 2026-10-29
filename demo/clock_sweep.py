# SPDX-License-Identifier: Apache-2.0
# The sealed clock windows (python/clock_cliffs.py) against a clock sweep on the bench.
# Stub: plan prints the clocks to run each firmware at, compare reads what the sweep saw.
# Driving the clock and capturing the pins are not here yet.
# A results file has a tab separated line per run:
#   firmware  clock_hz  words_md5  wire  device
# clock_hz is as measured on the chip's clock pin. wire is pass, fail or within (demo/edges.py's
# capture against test/measured_limits.ml). device is works, fails or - (no part).
# Usage: python3 demo/clock_sweep.py plan [--step PPM]
#        python3 demo/clock_sweep.py compare RESULTS
import argparse
import hashlib
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def predictions(root=ROOT):
    """python/clock_cliffs.py, refused unless it matches its pin in test/clock_cliffs.sha256."""
    path = os.path.join(root, "python", "clock_cliffs.py")
    with open(os.path.join(root, "test", "clock_cliffs.sha256")) as f:
        pinned = f.read().split()[0]
    with open(path, "rb") as f:
        text = f.read()
    if hashlib.sha256(text).hexdigest() != pinned:
        sys.exit("python/clock_cliffs.py does not match its seal in test/clock_cliffs.sha256")
    found = {}
    exec(compile(text, path, "exec"), found)
    return {w["firmware"]: w for w in found["WINDOWS"]}


def inside(window, hz):
    low, high = window["lowest_hz"], window["highest_hz"]
    return (low is None or hz >= low) and (high is None or hz <= high)


def plan(windows, step_ppm):
    """Each firmware at its shipped clock, at each end and a step past it."""
    for name, w in windows.items():
        clocks = {w["shipped_hz"]}
        for end, past in (("lowest_hz", -1), ("highest_hz", 1)):
            if w[end] is not None:
                clocks.add(w[end])
                clocks.add(w[end] + past * max(1, w[end] * step_ppm // 1_000_000))
        yield name, sorted(clocks)


def outcome(window, hz, md5, wire, device):
    """A word for the run: ok, cliff (seen outside), conservative (passes outside), or
    UNSOUND (fails inside), and WRONG IMAGE where the run's image is not the one sealed."""
    if window["words_md5"] is not None and md5 != window["words_md5"]:
        return "WRONG IMAGE"
    certified = inside(window, hz)
    if wire == "within":
        word = "within a sample"
    elif certified:
        word = "ok" if wire == "pass" else "UNSOUND"
    else:
        word = "cliff" if wire == "fail" else "conservative"
    if device == "works" and not certified:
        word += ", device works past the datasheet"
    elif device == "fails" and certified:
        word += ", DEVICE FAILS INSIDE"
    return word


def compare(windows, lines):
    for line in lines:
        if not line.strip() or line.startswith("#"):
            continue
        name, hz, md5, wire, device = line.split("\t")
        w = windows.get(name)
        if w is None:
            yield "%s: no sealed window" % name
            continue
        hz = int(hz)
        yield "%-18s %10.6f MHz %-11s %s" % (
            name, hz / 1e6, "inside" if inside(w, hz) else "outside",
            outcome(w, hz, md5, wire, device.strip()))


def main():
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    p = sub.add_parser("plan")
    p.add_argument("--step", type=int, default=2000, help="ppm past each end")
    c = sub.add_parser("compare")
    c.add_argument("results")
    args = parser.parse_args()
    windows = predictions()
    if args.command == "plan":
        for name, clocks in plan(windows, args.step):
            print("%-18s %s" % (name, " ".join("%d" % hz for hz in clocks)))
    else:
        with open(args.results) as f:
            for line in compare(windows, f):
                print(line)


if __name__ == "__main__":
    main()
