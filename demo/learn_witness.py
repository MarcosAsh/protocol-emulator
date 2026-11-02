# SPDX-License-Identifier: Apache-2.0
# A learn demo kept in test/board/learn_<protocol>/ as demo/learn_board.sh left it. The check
# here is the half that needs sigrok: every file against SHA256SUMS, each capture's edges
# against the .edges file read from it, and sigrok's stock decoder on the chip's speech
# against what the run kept, with a bit of the speech flipped refused. test/test_learn_board.ml
# is the other half: it learns again from the chip's own recording, must write the same
# firmware, and reads the analyser's and Pico B's edges back as the message sent.
# Usage: python3 demo/learn_witness.py check test/board/learn_*/
#        python3 demo/learn_witness.py write RUN test/board/learn_<protocol> --decode ARGS

import argparse
import hashlib
import io
import json
import shutil
import subprocess
import sys
import tempfile
import zipfile
from contextlib import redirect_stdout
from pathlib import Path

import learn_prepare

KEPT = ["chip.edges", "record.log", "recorded.sr", "analyser_recorded.edges", "learn.txt",
        "firmware.asm", "send.json", "spoken.sr", "spoken.edges", "spoken.frames", "send.log"]
OPTIONAL = ["listen.edges", "listen.frames", "spoken.decode"]


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def sums(directory):
    return {name.lstrip("*"): sha for sha, name in
            (line.split(maxsplit=1) for line in (directory / "SHA256SUMS").read_text().splitlines())}


def edges_text(capture, probes):
    out = io.StringIO()
    with redirect_stdout(out):
        learn_prepare.edges_of(capture, probes)
    return out.getvalue()


def decode(capture, arguments):
    done = subprocess.run(["sigrok-cli", "-i", str(capture)] + arguments.split(),
                          capture_output=True)
    return done.stdout


def flipped(capture, channel, at, to, out):
    """A copy of the capture with one channel inverted from sample at up to to."""
    with zipfile.ZipFile(capture) as z:
        names = z.namelist()
        files = {n: z.read(n) for n in names}
    meta = files["metadata"].decode()
    bit = int(next(line.split("=")[0][len("probe"):] for line in meta.splitlines()
                   if line.startswith("probe") and line.split("=")[1] == channel)) - 1
    prefix = next(line.split("=")[1] for line in meta.splitlines()
                  if line.startswith("capturefile=")) + "-"
    chunks = sorted((n for n in names if n.startswith(prefix)), key=lambda n: int(n[len(prefix):]))
    samples = bytearray(b"".join(files[n] for n in chunks))
    for i in range(at, to):
        samples[i] ^= 1 << bit
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for n in names:
            if not n.startswith(prefix):
                z.writestr(n, files[n])
        z.writestr(prefix + "1", bytes(samples))


def check(directory):
    """What is wrong with the run in directory, and its tooth's verdict."""
    directory = Path(directory)
    w = json.loads((directory / "witness.json").read_text())
    problems = []
    listed = sums(directory)
    for kept in KEPT + [k for k in OPTIONAL if (directory / k).exists()]:
        if kept not in listed:
            problems.append("SHA256SUMS lists no %s" % kept)
        elif sha256((directory / kept).read_bytes()) != listed[kept]:
            problems.append("%s does not match SHA256SUMS" % kept)
    if sha256((directory / "SHA256SUMS").read_bytes()) != w["sums_sha256"]:
        problems.append("SHA256SUMS is not the one witness.json names")
    for capture, edges, probes in [("recorded.sr", "analyser_recorded.edges", w["recorded_probes"]),
                                   ("spoken.sr", "spoken.edges", w["spoken_probes"])]:
        if edges_text(directory / capture, probes) != (directory / edges).read_text():
            problems.append("%s is not the edges of %s" % (edges, capture))
    bitten = []
    if w.get("decode"):
        decoded = decode(directory / "spoken.sr", w["decode"])
        if decoded != (directory / "spoken.decode").read_bytes():
            problems.append("sigrok decodes spoken.sr otherwise than the run did")
        for line in w["expect"]:
            if line.encode() not in decoded:
                problems.append("sigrok's decode lacks %r" % line)
        channel, at, to = w["tooth"]
        with tempfile.TemporaryDirectory() as scratch:
            path = Path(scratch) / "tooth.sr"
            flipped(directory / "spoken.sr", channel, at, to, path)
            toothed = decode(path, w["decode"])
            missing = [line for line in w["expect"] if line.encode() not in toothed]
            bitten.append(("%s inverted over samples %d to %d" % (channel, at, to),
                           "sigrok's decode lacks %r" % missing[0] if missing else None))
    return problems, bitten


def write(run, directory, decode_args, expect, tooth):
    run, directory = Path(run), Path(directory)
    directory.mkdir(parents=True, exist_ok=True)
    for kept in KEPT + OPTIONAL:
        source = run / kept if (run / kept).exists() else run / "learned" / kept
        if source.exists():
            shutil.copy(source, directory / kept)
    lines = [(sha256((directory / k).read_bytes()), k)
             for k in KEPT + OPTIONAL if (directory / k).exists()]
    (directory / "SHA256SUMS").write_text("".join("%s  %s\n" % line for line in lines))
    clocked = "IO2" in (directory / "chip.edges").read_text()
    w = {
        "demo": "learn_" + directory.name.removeprefix("learn_"),
        "bitstream_sha256": (run / "bitstream.sha256").read_text().split()[0],
        "sums_sha256": sha256((directory / "SHA256SUMS").read_bytes()),
        "recorded_probes": ["IO3=D6", "IO2=D7"] if clocked else ["IO3=D6"],
        "spoken_probes": ["IO2=D0", "IO3=D1"] if clocked else ["OUT0=D4"],
        "decode": decode_args,
        "expect": expect,
        "tooth": tooth,
        "bench": "an Icepi Zero running the chip at 48 MHz on bench carrier v1.2, Pico A as the "
                 "host, Pico B replaying the recording and listening on OUT0, analyser B on "
                 "IO3/IO2 while the chip records and A on OUT0 (B on OUT5/OUT4 for a clocked "
                 "bus) while it speaks, both fx2lafw",
        "scope": "the chip's recording of a transmitter it was not told about, what was learned "
                 "from it, the firmware written for a message never recorded, and that message "
                 "on the wire",
    }
    (directory / "witness.json").write_text(json.dumps(w, indent=2) + "\n")
    problems, bitten = check(directory)
    for p in problems:
        print("problem: %s" % p)
    for what, why in bitten:
        print("tooth: %s: %s" % (what, why))
    return not problems and all(why for _, why in bitten)


def main():
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    p = sub.add_parser("check")
    p.add_argument("directories", nargs="+")
    p = sub.add_parser("write")
    p.add_argument("run")
    p.add_argument("directory")
    p.add_argument("--decode", default="")
    p.add_argument("--expect", action="append", default=[])
    p.add_argument("--tooth", nargs=3, help="CHANNEL FIRST LAST samples to invert")
    args = parser.parse_args()
    if args.command == "write":
        tooth = [args.tooth[0], int(args.tooth[1]), int(args.tooth[2])] if args.tooth else None
        sys.exit(0 if write(args.run, args.directory, args.decode, args.expect, tooth) else 1)
    ok = True
    for directory in args.directories:
        problems, bitten = check(directory)
        for p in problems:
            print("FAIL %s: %s" % (Path(directory).name, p))
        for what, why in bitten:
            print("TOOTH %s: %s refused: %s" % (Path(directory).name, what, why) if why else
                  "MISSED %s: %s passed" % (Path(directory).name, what))
        if not problems:
            print("PASS %s" % Path(directory).name)
        ok = ok and not problems and all(why for _, why in bitten)
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
