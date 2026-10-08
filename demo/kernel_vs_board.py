# SPDX-License-Identifier: Apache-2.0
# The kernel's verdicts against the board. Runs every delay variant from
# test/python/write_kernel_variants.exe on the chip through Pico A, in batches of
# python/demo_kernel_vs_board.py, reloading the bitstream after any variant that faults, as
# faults hold until reset. A variant the kernel accepts must run on time; one it refuses
# that runs on time is the kernel's pessimism, counted. With --chip the chip checks each
# variant's certificate itself and must refuse exactly what the kernel refuses.
# Usage: PICO=id:<serial> python3 demo/kernel_vs_board.py VARIANTS --bitstream BIT --out DIR
#            [--python DIR] [--chip] [--batch N] [--only FIRMWARE...]
import argparse
import hashlib
import json
import os
import subprocess
import sys
import tempfile
import time

PICO_FILES = [
    "protocol_emulator.py", "pico_board.py", "demo_self_timing.py", "demo_sweep.py",
    "sweep_firmware.py", "demo_kernel_vs_board.py",
]


def mpremote(*args, log):
    command = ["mpremote", "connect", os.environ["PICO"], *args]
    done = subprocess.run(command, capture_output=True, text=True, timeout=1800)
    log.write("$ %s\n%s%s" % (" ".join(command[:5]), done.stdout, done.stderr))
    log.flush()
    return done.stdout


def load_bitstream(bitstream, log):
    done = subprocess.run(
        ["openFPGALoader", "-b", "icepi-zero", bitstream], capture_output=True, text=True)
    log.write("$ openFPGALoader %s\n%s%s" % (bitstream, done.stdout, done.stderr))
    if done.returncode:
        sys.exit("openFPGALoader failed: see the log")
    time.sleep(0.5)


def batch_script(batch, chip):
    rows = [
        (v["firmware"], v["k"], v["words"], v["certificate"] if chip else None)
        for v in batch
    ]
    return (
        "import demo_kernel_vs_board, pico_board\n"
        "spi = pico_board.PicoSpi()\n"
        "demo_kernel_vs_board.run(spi.transfer, %s, drain=spi.drain)\n" % json.dumps(rows)
        .replace("null", "None"))


def parse(line):
    """A RESULT line as a dict, or None."""
    fields = line.split()
    if not fields or fields[0] != "RESULT":
        return None
    name, k, what = fields[1], int(fields[2]), fields[3]
    if what == "refused":
        pc, reason, halted = map(int, fields[4:7])
        return {"firmware": name, "k": k, "board": "refused", "chip_pc": pc,
                "chip_reason": reason, "stays_halted": bool(halted)}
    exact, within, out = map(int, fields[4:7])
    fault0, fault1 = (int(f, 16) for f in fields[7:9])
    return {"firmware": name, "k": k, "board": "ran", "exact": exact, "within": within,
            "out": out, "fault0": fault0, "fault1": fault1}


def outcome(variant, result):
    """What the pair says, the first word a verdict: ok, pessimism, or a word for a bug."""
    accepted = variant["accepted"]
    if result["board"] == "refused":
        if accepted:
            return "MISMATCH the chip refused what the kernel accepts"
        if not result["stays_halted"]:
            return "BUG a refused program started"
        return "ok refused by both"
    late = result["out"] > 0 or result["fault0"] != 0
    if accepted:
        return "UNSOUND accepted but late" if late else "ok accepted, on time"
    if result["chip"]:
        return "MISMATCH the chip ran what the kernel refuses"
    return "ok refused, late" if late else "pessimism refused, on time"


def summary(variants, results):
    """A line per firmware: the kernel's last accepted k against the first the board ran
    late, and the count of each verdict that is not ok."""
    lines = ["firmware           wait pc  slack  kernel accepts  board late from  "
             "unsound  pessimism  mismatches"]
    for name in dict.fromkeys(v["firmware"] for v in variants):
        mine = [v for v in variants if v["firmware"] == name]
        got = {r["k"]: r for r in results if r["firmware"] == name}
        accepted = [v["k"] for v in mine if v["accepted"]]
        late = [k for k, r in got.items()
                if r["board"] == "ran" and (r["out"] or r["fault0"])]

        def count(word):
            return sum(r["outcome"].startswith(word) for r in got.values())

        lines.append("%-18s %7d  %5d  %14s  %15s  %7d  %9d  %10d" % (
            name, mine[0]["wait_pc"], mine[0]["slack"],
            "k <= %d" % max(accepted) if accepted else "none",
            "k = %d" % min(late) if late else "none ran late",
            count("UNSOUND"), count("pessimism"), count("MISMATCH") + count("BUG")))
        missing = [v["k"] for v in mine if v["k"] not in got]
        if missing:
            lines.append("    not run: %d of %d, k from %d to %d" % (
                len(missing), len(mine), min(missing), max(missing)))
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("variants")
    parser.add_argument("--bitstream", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--python", default=os.path.join(os.path.dirname(__file__), "..",
                                                          "python"))
    parser.add_argument("--chip", action="store_true")
    parser.add_argument("--batch", type=int, default=16)
    parser.add_argument("--only", nargs="*")
    args = parser.parse_args()
    with open(args.variants) as f:
        every = variants = [json.loads(line) for line in f if line.strip()]
    if args.only:
        variants = [v for v in variants if v["firmware"] in args.only]
    if args.chip:
        # with no certificate the chip would check the firmware's own
        for v in variants:
            if v.get("certificate") is None:
                print("%s k=%d has no certificate: %s" % (v["firmware"], v["k"], v["chip_model"]))
        variants = [v for v in variants if v.get("certificate") is not None]
    os.makedirs(args.out, exist_ok=True)
    log = open(os.path.join(args.out, "board.log"), "a")
    with open(args.bitstream, "rb") as f:
        digest = hashlib.sha256(f.read()).hexdigest()
    with open(os.path.join(args.out, "run.txt"), "a") as f:
        f.write("%s bitstream %s sha256 %s chip check %s, %d variants from %s\n" % (
            time.strftime("%Y-%m-%d %H:%M:%S"), args.bitstream, digest,
            "on" if args.chip else "off", len(variants), args.variants))
    mpremote("cp", *(os.path.join(args.python, f) for f in PICO_FILES), ":", log=log)
    load_bitstream(args.bitstream, log)
    results, pending, retried, empty = [], list(variants), set(), 0
    by_key = {(v["firmware"], v["k"]): v for v in variants}
    while pending:
        batch = pending[:args.batch]
        with tempfile.NamedTemporaryFile("w", suffix=".py", delete=False) as script:
            script.write(batch_script(batch, args.chip))
        out = mpremote("run", script.name, log=log)
        os.unlink(script.name)
        got = [r for r in map(parse, out.splitlines()) if r]
        for r in got:
            variant = by_key[(r["firmware"], r["k"])]
            r["chip"] = args.chip
            r["accepted"] = variant["accepted"]
            r["outcome"] = outcome(variant, r)
            r["chip_model"] = variant.get("chip_model")
            # a logger fault alone says nothing of engine 0: run that variant again
            if r["board"] == "ran" and r["fault1"] and not r["fault0"] and not r["out"]:
                if (r["firmware"], r["k"]) not in retried:
                    retried.add((r["firmware"], r["k"]))
                    got = got[:got.index(r)]
                    break
                r["outcome"] = "inconclusive the logger faulted twice"
        for r in got:
            print("%-18s k=%-4d %s" % (r["firmware"], r["k"], r["outcome"]), flush=True)
            results.append(r)
        with open(os.path.join(args.out, "results.jsonl"), "a") as f:
            for r in got:
                f.write(json.dumps(r) + "\n")
        if any(r["outcome"].startswith("UNSOUND") for r in got):
            print("STOP: the kernel accepted a variant the board ran late")
            break
        pending = pending[len(got):]
        if "DONE" not in out or len(got) < len(batch):
            empty = 0 if got else empty + 1
            if empty == 3:
                sys.exit("no result from the Pico three times: see %s/board.log" % args.out)
            load_bitstream(args.bitstream, log)
    # every run into this directory, the last of each variant's
    with open(os.path.join(args.out, "results.jsonl")) as f:
        results = [json.loads(line) for line in f if line.strip()]
    text = summary(every, results)
    with open(os.path.join(args.out, "summary.txt"), "w") as f:
        f.write(text)
    print("\n" + text)


if __name__ == "__main__":
    main()
