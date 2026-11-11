# SPDX-License-Identifier: Apache-2.0
# Checks a learn demo kept in test/board/learn_<protocol>/ as demo/learn_board.sh left it.
# This is the half that needs sigrok: every file against SHA256SUMS, each capture's edges
# against the .edges file made from it, and sigrok's stock decoder on what the chip sent
# against what the run kept, once for each frame sent. A bit flipped in one frame must be
# refused. The other half is test/test_learn_board.ml, which learns again from the chip's
# own recording, must write the same firmware, and reads the analyser's and Pico B's edges
# back as the message sent.
# Usage: python3 demo/learn_witness.py check test/board/learn_*/
#        python3 demo/learn_witness.py write RUN test/board/learn_<protocol> --decode ARGS
#            --expect LINE... --tooth CHANNEL FIRST-LAST[,FIRST-LAST...] WHAT...
#            [--commit HASH --commit-from HOW]

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
from datetime import datetime, timezone
from pathlib import Path

import learn_prepare

ROOT = Path(__file__).resolve().parent.parent
KEPT = ["chip.edges", "record.log", "recorded.sr", "analyser_recorded.edges", "learn.txt",
        "firmware.asm", "send.json", "spoken.sr", "spoken.edges", "spoken.frames", "send.log"]
OPTIONAL = ["listen.edges", "listen.frames", "spoken.decode"]
# what demo/learn_board.sh runs, on the pc and on Picos A and B
SCRIPTS = ["demo/learn_board.sh", "demo/learn_prepare.py", "demo/capture.sh",
           "python/learn_record.py", "python/learn_send.py", "python/learn_replay.py",
           "python/learn_listen.py", "python/protocol_emulator.py", "python/pico_board.py",
           "python/bench.py"]
LIMITS = ["the run recorded no time, so the time is that of the bitstream's hash, which the "
          "run wrote as it loaded the bitstream",
          "the host scripts are hashed at the commit, and CI does not hold them to HEAD, "
          "where some have changed since"]


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


def flipped(capture, channel, ranges, out):
    """Copies the capture with one channel inverted over each [first, last) sample range."""
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
    for at, to in ranges:
        for i in range(at, to):
            samples[i] ^= 1 << bit
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for n in names:
            if not n.startswith(prefix):
                z.writestr(n, files[n])
        z.writestr(prefix + "1", bytes(samples))


def sent(directory):
    """Returns how many frames send.log says the chip was given to send."""
    return sum(line.startswith("sent ") for line in
               (directory / "send.log").read_text().splitlines())


def short(decoded, expect, frames):
    """Returns each expected line the decode has fewer times than frames were sent."""
    return ["sigrok's decode reads %r in %d of the %d frames sent" % (
        line, decoded.count(line.encode()), frames)
            for line in expect if decoded.count(line.encode()) < frames]


def check(directory):
    """Returns what is wrong with the run in directory, and its teeth's verdicts."""
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
    if w["firmware"] != {"firmware.asm": listed.get("firmware.asm")}:
        problems.append("witness.json's firmware is not the firmware.asm SHA256SUMS lists")
    for capture, edges, probes in [("recorded.sr", "analyser_recorded.edges", w["recorded_probes"]),
                                   ("spoken.sr", "spoken.edges", w["spoken_probes"])]:
        if edges_text(directory / capture, probes) != (directory / edges).read_text():
            problems.append("%s is not the edges of %s" % (edges, capture))
    bitten = []
    if w.get("decode"):
        decoded = decode(directory / "spoken.sr", w["decode"])
        if decoded != (directory / "spoken.decode").read_bytes():
            problems.append("sigrok decodes spoken.sr otherwise than the run did")
        frames = sent(directory)
        problems += short(decoded, w["expect"], frames)
        for tooth in w["teeth"]:
            with tempfile.TemporaryDirectory() as scratch:
                path = Path(scratch) / "tooth.sr"
                flipped(directory / "spoken.sr", tooth["channel"], tooth["invert"], path)
                missing = short(decode(path, w["decode"]), w["expect"], frames)
            bitten.append(("%s, %s inverted over %s" % (
                tooth["what"], tooth["channel"],
                ", ".join("%d-%d" % tuple(r) for r in tooth["invert"])),
                missing[0] if missing else None))
    return problems, bitten


def at_commit(commit, path):
    return subprocess.run(["git", "-C", str(ROOT), "show", "%s:%s" % (commit, path)],
                          capture_output=True, check=True).stdout


def write(run, directory, decode_args, expect, teeth, commit, commit_from):
    """Copies a learn run into directory and writes its witness. The run records no commit,
    so it is given with how it was found."""
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
    loaded = (run / "bitstream.sha256").stat().st_mtime
    w = {
        "demo": "learn_" + directory.name.removeprefix("learn_"),
        "time": datetime.fromtimestamp(loaded, timezone.utc).strftime("%Y-%m-%dT%H:%M:%S"),
        "commit": commit or "not recorded",
        "commit_from": commit_from if commit else "not recorded",
        "bitstream_sha256": (run / "bitstream.sha256").read_text().split()[0],
        "sums_sha256": sha256((directory / "SHA256SUMS").read_bytes()),
        "firmware": {"firmware.asm": sha256((directory / "firmware.asm").read_bytes())},
        "host_scripts": ({f: sha256(at_commit(commit, f)) for f in SCRIPTS} if commit
                         else "not recorded"),
        "recorded_probes": ["IO3=D6", "IO2=D7"] if clocked else ["IO3=D6"],
        "spoken_probes": ["IO2=D0", "IO3=D1"] if clocked else ["OUT0=D4"],
        "decode": decode_args,
        "expect": expect,
        "teeth": teeth,
        "bench": "an Icepi Zero running the chip at 48 MHz on bench carrier v1.2, Pico A as the "
                 "host, Pico B replaying the recording and listening on OUT0, analyser B on "
                 "IO3/IO2 while the chip records and A on OUT0 (B on OUT5/OUT4 for a clocked "
                 "bus) while it speaks, both fx2lafw",
        "scope": "the chip's recording of a transmitter it was not told about, what was learned "
                 "from it, the firmware written for a message never recorded, and that message "
                 "on the wire",
        "limits": LIMITS if commit else LIMITS[:1],
    }
    (directory / "witness.json").write_text(json.dumps(w, indent=2) + "\n")
    problems, bitten = check(directory)
    for p in problems:
        print("problem: %s" % p)
    for what, why in bitten:
        print("tooth: %s: %s" % (what, why))
    return not problems and bool(bitten) and all(why for _, why in bitten)


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
    p.add_argument("--tooth", nargs=3, action="append", default=[],
                   metavar=("CHANNEL", "RANGES", "WHAT"),
                   help="samples to invert, as FIRST-LAST[,FIRST-LAST...]")
    p.add_argument("--commit", help="the commit the run's tree was at")
    p.add_argument("--commit-from", default="", help="how the commit was found")
    args = parser.parse_args()
    if args.command == "write":
        teeth = [{"what": what, "channel": channel,
                  "invert": [[int(x) for x in r.split("-")] for r in ranges.split(",")]}
                 for channel, ranges, what in args.tooth]
        sys.exit(0 if write(args.run, args.directory, args.decode, args.expect, teeth,
                            args.commit, args.commit_from) else 1)
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
