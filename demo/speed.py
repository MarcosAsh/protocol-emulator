# SPDX-License-Identifier: Apache-2.0
# How long a protocol takes from its spec to a kernel certificate and a bench PASS. The tools
# append a row to demo/speed.tsv as each stage ends: generate new-protocol (spec), make -C
# formal inductive_write (file) and inductive_proof (certificate), demo/outside.sh (bench).
# The first row of a stage counts. A run on another machine is added with --at.
# Baseline to quote beside it: Englhardt et al., "Exploring and Characterizing Large Language
# Models For Embedded System Development and Debugging", arXiv 2307.03817 (v2, Nov 2023, a
# preprint with no venue): hardware in the loop, GPT-4, "In N=50 trials, GPT-4 produces
# functional I2C interfaces 66% of the time". That is a success rate over trials, not a time.
# Usage: python3 demo/speed.py mark PROTOCOL STAGE [--at ISO_TIME] [--note TEXT] [--if-started]
#        python3 demo/speed.py table [--tsv FILE]

import argparse
import csv
import sys
from datetime import datetime
from pathlib import Path

TSV = Path(__file__).resolve().parent / "speed.tsv"
COLUMNS = ["protocol", "stage", "time", "note"]
# spec: the scaffold exists; file: the protocol file is final; certificate: the kernel's
# inductive proof and its teeth passed; bench: the bench demo's PASS with its traffic
STAGES = ["spec", "file", "certificate", "bench"]


def rows(tsv):
    if not tsv.exists():
        return []
    with open(tsv, newline="") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def mark(tsv, protocol, stage, at, note, if_started):
    if stage not in STAGES:
        sys.exit("stage is one of " + " ".join(STAGES))
    if if_started and not any(r["protocol"] == protocol for r in rows(tsv)):
        return
    when = datetime.fromisoformat(at) if at else datetime.now().astimezone()
    new = not tsv.exists() or tsv.stat().st_size == 0
    with open(tsv, "a", newline="") as f:
        out = csv.writer(f, delimiter="\t", lineterminator="\n")
        if new:
            out.writerow(COLUMNS)
        out.writerow([protocol, stage, when.isoformat(timespec="seconds"), note])


def minutes(a, b):
    return "-" if a is None or b is None else "%.1f" % ((b - a).total_seconds() / 60)


def table(tsv):
    first = {}
    for r in rows(tsv):
        first.setdefault(r["protocol"], {}).setdefault(
            r["stage"], datetime.fromisoformat(r["time"]))
    head = ["protocol", "spec>file", "file>cert", "cert>bench", "spec>cert", "spec>bench"]
    lines = [head]
    for p, t in first.items():
        s, f, c, b = (t.get(k) for k in STAGES)
        lines.append([p, minutes(s, f), minutes(f, c), minutes(c, b), minutes(s, c),
                      minutes(s, b)])
    widths = [max(len(l[i]) for l in lines) for i in range(len(head))]
    print("minutes, from demo/speed.tsv")
    for l in lines:
        print("  ".join(x.ljust(w) for x, w in zip(l, widths)).rstrip())


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tsv", type=Path, default=TSV)
    sub = ap.add_subparsers(dest="cmd", required=True)
    m = sub.add_parser("mark")
    m.add_argument("protocol")
    m.add_argument("stage")
    m.add_argument("--at")
    m.add_argument("--note", default="")
    m.add_argument("--if-started", action="store_true")
    sub.add_parser("table")
    a = ap.parse_args()
    if a.cmd == "mark":
        mark(a.tsv, a.protocol, a.stage, a.at, a.note, a.if_started)
    else:
        table(a.tsv)


if __name__ == "__main__":
    main()
