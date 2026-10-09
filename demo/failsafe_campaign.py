# SPDX-License-Identifier: Apache-2.0
# The fail-safe on the board, one fault per reset: engine 0 drives wire 20 and OUT0 (D4)
# high, then misses a deadline by k cycles, underflows, overflows or fails to decode. Its
# pins must let go on the edge after the faulting instruction issues, as a pin write there
# (the controls) lands, and stay still through a start. Engine 1 stamps wire 20 and echoes
# it on OUT2 (D6), or drives a square wave there that must not miss a beat.
# Usage: PICO=id:<serial> ANALYSER_A_PORT=<port> python3 demo/failsafe_campaign.py
#            --bitstream BIT --out DIR [--generate EXE] [--plan small|full] [--only NAME...]
import argparse
import hashlib
import json
import os
import subprocess
import sys
import tempfile
import time

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
ASM = os.path.join(HERE, "failsafe_campaign")
PERIOD = 100
SQUARE_PERIOD = 480
RATE = 12_000_000
CYCLES_PER_SAMPLE = 4
CAPTURE_MS = 1600
OUT0, OUT2 = 4, 6
# the word that does not decode, in place of decode.asm's `nop side 1`
UNDECODABLE = 0xF0FF
NOP_SIDE_1 = 0xF000
FAULT_BIT = {"deadline": 0x10, "underflow": 0x04, "overflow": 0x08, "decode": 0x20}

DEADLINE = """\
; deadline.asm with {k} cycles of nop before its second wait
.side_set 1
    set pins, 0 side 0
    wait tx side 0
    pull side 0
    mov p, osr side 0
    mov t, now side 0
    add t, p side 0
    wait t+ side 0
    set pins, 1 side 1
{nops}    {last}
    set pins, 0 side 0
    halt side 0
"""


def assemble(generate, text, flags=()):
    """(words, assembler output) for the source, the timing check off if it refuses."""
    with tempfile.NamedTemporaryFile("w", suffix=".asm", delete=False) as f:
        f.write(text)
    try:
        done = subprocess.run([generate, "assemble", *flags, f.name], capture_output=True,
                              text=True)
        if done.returncode:
            again = subprocess.run([generate, "assemble", "-no-timing-check", *flags, f.name],
                                   capture_output=True, text=True, check=True)
            words = [int(w, 16) for w in again.stdout.split() if len(w) == 4]
        else:
            words = [int(w, 16) for w in done.stdout.split() if len(w) == 4]
    finally:
        os.unlink(f.name)
    return words, done.returncode == 0, (done.stdout + done.stderr).strip()


def deadline(generate, k, control=False):
    nops = ""
    left = k
    while left:
        n = min(left, 16)
        nops += "    nop side 1%s\n" % ("" if n == 1 else " [%d]" % (n - 1))
        left -= n
    last = "set pins, 0 side 0" if control else "wait t+ side 1"
    words, accepted, verdict = assemble(
        generate, DEADLINE.format(k=k, nops=nops, last=last), ["-period", str(PERIOD)])
    # on time the line falls at the deadline, P after it rose; late, the release comes the
    # edge after the wait issues, k + 1 after the rise, as a pin write there would
    late = k > PERIOD - 2
    return {"kind": "deadline", "k": k, "control": control, "words": words,
            "accepted": accepted, "verdict": verdict.splitlines()[-1] if verdict else "",
            "push": [PERIOD], "fault": late and not control,
            "expect": k + 1 if late or control else PERIOD}


def fixed(generate, kind, control=False):
    name = kind + ("_control" if control else "")
    with open(os.path.join(ASM, name + ".asm")) as f:
        words, accepted, verdict = assemble(generate, f.read())
    if kind == "decode" and not control:
        words[words.index(NOP_SIDE_1)] = UNDECODABLE
    # the rise's set issues at c and lands at c + 1, two nops of 16 run to c + 32; the fault
    # issues at c + 33, or for the overflow the ninth push at c + 41, and lands a cycle later
    return {"kind": kind, "k": None, "control": control, "words": words, "accepted": accepted,
            "verdict": verdict.splitlines()[-1], "push": [1], "fault": not control,
            "expect": 41 if kind == "overflow" else 33}


def plan(generate, which):
    """(case, neighbour) in run order."""
    cases = []
    if which == "small":
        ks = [97, 98, 99, 100, 150]
        repeats = 2
        neighbour_ks = [99, 120]
    else:
        ks = list(range(95, 601)) + list(range(700, 2001, 100)) + list(range(3000, 7001, 1000))
        repeats = 40
        neighbour_ks = list(range(99, 149))
    for k in ks:
        cases.append((deadline(generate, k), "logger"))
    for k in (99, 100, 150, 600, 2000):
        cases.append((deadline(generate, k, control=True), "logger"))
    for kind in ("underflow", "overflow", "decode"):
        cases.append((fixed(generate, kind, control=True), "logger"))
        cases += [(fixed(generate, kind), "logger")] * repeats
    for k in neighbour_ks:
        cases.append((deadline(generate, k), "square"))
    for kind in ("underflow", "overflow", "decode"):
        cases += [(fixed(generate, kind), "square")] * max(2, repeats * 5 // 8)
    return cases


def name(case, neighbour):
    k = "" if case["k"] is None else "_k%d" % case["k"]
    return "%s%s%s_%s" % (case["kind"], k, "_control" if case["control"] else "", neighbour)


def run(command, log, timeout=60, check=True):
    done = subprocess.run(command, capture_output=True, text=True, timeout=timeout)
    log.write("$ %s\n%s%s" % (" ".join(command[:6]), done.stdout, done.stderr))
    log.flush()
    if check and done.returncode:
        raise RuntimeError("%s failed: %s" % (command[0], done.stderr.strip()[-200:]))
    return done


def analyser():
    port = os.environ["ANALYSER_A_PORT"]
    bus = open("/sys/bus/usb/devices/%s/busnum" % port).read().strip()
    dev = open("/sys/bus/usb/devices/%s/devnum" % port).read().strip()
    return "fx2lafw:conn=%s.%s" % (bus, dev)


def edges(samples, bit):
    """(sample, new level) for each change of the bit."""
    line = (samples >> bit) & 1
    at = np.flatnonzero(np.diff(line)) + 1
    return [(int(n), int(line[n])) for n in at], int(line[0]), int(line[-1])


def read_capture(path):
    raw = subprocess.run(["sigrok-cli", "-i", path, "-O", "binary"], capture_output=True,
                         check=True).stdout
    return np.frombuffer(raw, dtype=np.uint8)


def parse(line):
    f = line.split()
    held = (int(f[2], 16), int(f[3], 16))
    first = (int(f[5], 16), int(f[6]), int(f[7], 16), int(f[8]))
    second = (int(f[10], 16), int(f[11]), int(f[12], 16), int(f[13]))
    stamps = [] if f[15] == "-" else [int(s) for s in f[15].split(",")]
    later = [] if f[17] == "-" else [int(s) for s in f[17].split(",")]
    return {"held": held, "first": first, "second": second, "stamps": stamps, "later": later}


def judge(case, neighbour, r, cap):
    """The checks on one injection; escapes are a pin moving after the release, a fault
    not latched, or an engine 0 that ran again; bound is the release landing anywhere but
    the edge after the faulting instruction."""
    notes, escapes = [], []
    s0, pc0, s1, pc1 = r["first"]
    t0, tpc0, t1, tpc1 = r["second"]
    if any(r["held"]):
        notes.append("faults held before the run: no reset")
        return "invalid", notes, escapes
    if case["fault"]:
        bit = FAULT_BIT[case["kind"]]
        if s0 & 0x3C != bit:
            escapes.append("engine 0 faults 0x%x, want 0x%x" % (s0 & 0x3C, bit))
        if not s0 & 1 or not t0 & 1 or tpc0 != pc0:
            escapes.append("engine 0 not held halted through a start: pc %d then %d" % (pc0, tpc0))
    elif s0 & 0x3C:
        notes.append("control faulted 0x%x" % (s0 & 0x3C))
    if s1 & 0x3D or t1 & 0x3D:
        escapes.append("neighbour faulted or halted: 0x%x then 0x%x" % (s1, t1))
    # on the die: the logger's stamps of the rise and the release
    if neighbour == "logger":
        st = r["stamps"]
        if len(st) != 2:
            (escapes if case["fault"] else notes).append("%d stamps, want 2" % len(st))
        else:
            r["die_cycles"] = (st[1] - st[0]) & 0xFFFF
        if r["later"]:
            escapes.append("stamps after the release, through a start: %s" % r["later"])
    # on the analyser
    out0, start0, end0 = edges(cap, OUT0)
    out2, start2, end2 = edges(cap, OUT2)
    r["out0_edges"] = len(out0)
    if start0 != 0 or len(out0) < 2 or out0[0][1] != 1 or out0[1][1] != 0:
        notes.append("OUT0 not low, rise, fall: start %d, %s" % (start0, out0[:4]))
    else:
        r["pad_cycles"] = (out0[1][0] - out0[0][0]) * CYCLES_PER_SAMPLE
        r["release_sample"] = out0[1][0]
        r["after_release_ms"] = (len(cap) - out0[1][0]) / RATE * 1000
        if len(out0) > 2:
            escapes.append("OUT0 moved %d times after the release" % (len(out0) - 2))
        if "die_cycles" in r and abs(r["pad_cycles"] - r["die_cycles"]) > CYCLES_PER_SAMPLE + 1:
            notes.append("pad %d cycles against the die's %d" % (r["pad_cycles"], r["die_cycles"]))
    if neighbour == "logger":
        r["out2_edges"] = len(out2)
        if len(out2) != 2:
            notes.append("OUT2 echo made %d edges, want 2" % len(out2))
    else:
        gaps = np.diff([n for n, _ in out2]) * CYCLES_PER_SAMPLE
        r["out2_edges"] = len(out2)
        if len(out2) < 10:
            escapes.append("neighbour square made %d edges" % len(out2))
        else:
            r["square_gap_min"], r["square_gap_max"] = int(gaps.min()), int(gaps.max())
            r["square_mean"] = float(gaps.mean())
            if gaps.min() < SQUARE_PERIOD - 5 or gaps.max() > SQUARE_PERIOD + 5:
                escapes.append("neighbour square gaps %d..%d cycles" % (gaps.min(), gaps.max()))
            if "release_sample" in r:
                r["square_edges_after_release"] = sum(n > r["release_sample"] for n, _ in out2)
                if out2[-1][0] < len(cap) - 2 * SQUARE_PERIOD // CYCLES_PER_SAMPLE:
                    escapes.append("neighbour square stopped before the capture's end")
    die = r.get("die_cycles", r.get("pad_cycles"))
    if die is not None and case["fault"]:
        exact = die == case["expect"] if "die_cycles" in r else (
            abs(die - case["expect"]) <= CYCLES_PER_SAMPLE + 1)
        r["release_latency"] = die - case["expect"] + 1 if "die_cycles" in r else None
        if not exact:
            escapes.append("release %d cycles after the rise, want %d" % (die, case["expect"]))
    elif die is not None and "die_cycles" in r and die != case["expect"]:
        notes.append("edge %d cycles after the rise, want %d" % (die, case["expect"]))
    if escapes:
        return "ESCAPE", notes, escapes
    return ("ok" if not notes else "check"), notes, escapes


def summary(results):
    """Counts, escapes, and the release's latency from the faulting instruction's issue: on
    the die from the logger's stamps, exact; on the pads from the analyser, in samples of
    four cycles."""
    from collections import Counter

    lines = []
    faults = [r for r in results if r["fault"]]
    lines.append("injections %d: %d faults, %d controls and on-time deadline variants" % (
        len(results), len(faults), len(results) - len(faults)))
    lines.append("verdicts: %s" % dict(Counter(r["verdict"] for r in results)))
    lines.append("escapes: %d" % sum(bool(r["escapes"]) for r in results))
    for r in results:
        if r["escapes"] or r["notes"]:
            lines.append("    %d %s: %s" % (r["n"], r["name"], "; ".join(r["escapes"] + r["notes"])))
    lines.append("")
    lines.append("kind       neighbour  faults  latency on the die (cycles: count)  pad minus expected"
                 " (cycles: count)")
    for kind in ("deadline", "underflow", "overflow", "decode"):
        for neighbour in ("logger", "square"):
            mine = [r for r in faults if r["kind"] == kind and r["neighbour"] == neighbour]
            if not mine:
                continue
            die = Counter(r.get("release_latency") for r in mine if "die_cycles" in r)
            pad = Counter(r["pad_cycles"] - r["expect"] for r in mine if "pad_cycles" in r)
            lines.append("%-10s %-9s  %6d  %-35s  %s" % (
                kind, neighbour, len(mine), dict(sorted(die.items())) or "-",
                dict(sorted(pad.items()))))
    lines.append("")
    deadline = [r for r in results if r["kind"] == "deadline" and not r["control"]]
    if deadline:
        accepted = [r["k"] for r in deadline if r["accepted"]]
        late = [r["k"] for r in deadline if r["first"][0] & 0x10]
        lines.append("deadline variants k = %d..%d (%d): kernel accepts k <= %s, board faults from"
                     " k = %s, accepted but faulted %d, refused but on time %d" % (
                         min(r["k"] for r in deadline), max(r["k"] for r in deadline),
                         len(deadline), max(accepted) if accepted else "none",
                         min(late) if late else "none",
                         sum(r["accepted"] and r["first"][0] & 0x10 != 0 for r in deadline),
                         sum(not r["accepted"] and not r["first"][0] & 0x10 for r in deadline)))
    controls = [r for r in results if r["control"]]
    lines.append("controls (the pin write where the fault would be): %d, die cycles equal to the"
                 " fault's expected in %d" % (
                     len(controls), sum(r.get("die_cycles") == r["expect"] for r in controls)))
    after = [r["after_release_ms"] for r in faults if "after_release_ms" in r]
    if after:
        lines.append("watched after each release, through a start: %.0f to %.0f ms, OUT0 edges"
                     " after the release: %d" % (
                         min(after), max(after),
                         sum(max(0, r.get("out0_edges", 2) - 2) for r in faults)))
    squares = [r for r in faults if r["neighbour"] == "square" and "square_gap_min" in r]
    if squares:
        lines.append("neighbour square (%d cycles): gaps %d..%d over %d injections, mean %.3f,"
                     " %d edges after the releases, neighbour faults %d" % (
                         SQUARE_PERIOD, min(r["square_gap_min"] for r in squares),
                         max(r["square_gap_max"] for r in squares), len(squares),
                         np.mean([r["square_mean"] for r in squares if "square_mean" in r] or [0]),
                         sum(r.get("square_edges_after_release", 0) for r in squares),
                         sum(bool(r["first"][2] & 0x3C or r["second"][2] & 0x3C) for r in squares)))
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--bitstream", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--generate", default=os.path.join(ROOT, "_build/default/bin/generate.exe"))
    parser.add_argument("--plan", default="small")
    parser.add_argument("--only", nargs="*")
    parser.add_argument("--summary", action="store_true", help="summarise --out's results only")
    parser.add_argument("--keep", type=int, default=10_000, help="captures kept per case kind")
    args = parser.parse_args()
    if args.summary:
        with open(os.path.join(args.out, "results.jsonl")) as f:
            text = summary([json.loads(l) for l in f if l.strip()])
        with open(os.path.join(args.out, "summary.txt"), "w") as f:
            f.write(text)
        print(text)
        return
    os.makedirs(os.path.join(args.out, "captures"), exist_ok=True)
    log = open(os.path.join(args.out, "board.log"), "a")
    with open(args.bitstream, "rb") as f:
        digest = hashlib.sha256(f.read()).hexdigest()
    cases = plan(args.generate, args.plan)
    if args.only:
        cases = [c for c in cases if any(o in name(*c) for o in args.only)]
    with open(os.path.join(args.out, "run.txt"), "a") as f:
        f.write("%s bitstream %s sha256 %s plan %s, %d injections\n" % (
            time.strftime("%Y-%m-%d %H:%M:%S"), args.bitstream, digest, args.plan, len(cases)))
    pico = os.environ["PICO"]
    run(["mpremote", "connect", pico, "cp", os.path.join(ROOT, "python/protocol_emulator.py"),
         os.path.join(ROOT, "python/pico_board.py"),
         os.path.join(ROOT, "python/demo_failsafe_campaign.py"), ":"], log)
    done = set()
    results_path = os.path.join(args.out, "results.jsonl")
    if os.path.exists(results_path):
        with open(results_path) as f:
            done = {json.loads(l)["n"] for l in f if l.strip()}
    kept = {}
    for n, (case, neighbour) in enumerate(cases):
        if n in done:
            continue
        label = name(case, neighbour)
        for attempt in range(3):
            run(["openFPGALoader", "-b", "icepi-zero", args.bitstream], log)
            spec = {"name": label, "words": case["words"], "push": case["push"],
                    "neighbour": neighbour, "period": SQUARE_PERIOD}
            with tempfile.NamedTemporaryFile("w", suffix=".py", delete=False) as s:
                s.write("import demo_failsafe_campaign as c\nc.run(%s)\n" % json.dumps(spec))
            run(["mpremote", "connect", pico, "run", "--no-follow", s.name], log)
            os.unlink(s.name)
            sr = os.path.join(args.out, "captures", "%04d_%s.sr" % (n, label))
            cap = run(["sigrok-cli", "-d", analyser(), "-c", "samplerate=12M", "--time",
                       str(CAPTURE_MS), "-o", sr], log, check=False)
            if "only sent" in cap.stdout + cap.stderr or cap.returncode:
                log.write("capture short, again\n")
                time.sleep(1)
                continue
            line = run(["mpremote", "connect", pico, "cat", ":result.txt"], log).stdout.strip()
            break
        else:
            sys.exit("three short captures in a row: see board.log")
        r = parse(line)
        samples = read_capture(sr)
        r.update({"n": n, "name": label, "kind": case["kind"], "k": case["k"],
                  "control": case["control"], "neighbour": neighbour,
                  "accepted": case["accepted"], "fault": case["fault"],
                  "expect": case["expect"], "pico": line, "samples": len(samples)})
        verdict, notes, escapes = judge(case, neighbour, r, samples)
        r.update({"verdict": verdict, "notes": notes, "escapes": escapes})
        key = (case["kind"], case["control"], neighbour)
        kept[key] = kept.get(key, 0) + 1
        if kept[key] > args.keep and verdict == "ok":
            os.unlink(sr)
            r["capture"] = None
        else:
            r["capture"] = os.path.basename(sr)
        with open(results_path, "a") as f:
            f.write(json.dumps(r) + "\n")
        print("%4d %-34s %-6s die %s pad %s %s" % (
            n, label, verdict, r.get("die_cycles"), r.get("pad_cycles"),
            "; ".join(escapes + notes)), flush=True)


if __name__ == "__main__":
    main()
