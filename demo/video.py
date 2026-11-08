# SPDX-License-Identifier: Apache-2.0
# The video's four shots on the real board, each from a fresh load of the frozen bitstream
# (faults stick until reset). A shot prints a heading, its essential lines and PASS or FAIL;
# full logs go to RUN/<shot>/. Run it through demo/video.sh, which takes the bench lock.
#   late      test/uart_tx.asm with `out pins, 1 [13]`, the sed of docs/getting-started.md: the
#             chip's check refuses it and the engine stays halted
#   fixed     the same with [12], which the assembler accepts at slack 0: it runs and sigrok
#             decodes OUT0
#   heldout, keyboard  DALI and the USB keyboard, through demo/ledger.py
# Both programs are assembled from test/uart_tx.asm by generate.exe, on the machine with the
# OxCaml switch (demo/video.sh does it), into a PROGRAMS json the bench machine reads.
# Usage: python3 demo/video.py assemble GENERATE.EXE --programs PROGRAMS
#        PICO=id:<serial> python3 demo/video.py late|fixed|heldout|keyboard|all --run DIR
#            --bitstream BIT --programs PROGRAMS

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
# reason numbers are the index of the failed check
REASONS = {0: "a deadline wait may be missed"}
FILES = ["python/protocol_emulator.py", "python/pico_board.py", "python/demo_video.py"]
DETACH = "from machine import Pin; Pin(8, Pin.OUT, value=1)"
# 16 cycles a bit at 48 MHz
SENT = b"video"
BAUD = 3_000_000
# the `out` delay of the late copy, and the most the assembler accepts
LATE_K, FIXED_K = 13, 12
SOURCE = "test/uart_tx.asm"
# the analyser needs this long to start sampling
ARM_S = 3


def run(argv, log, **kw):
    """Runs argv from the repository root, appends its output to log and returns it."""
    log.write("$ %s\n" % " ".join(map(str, argv)))
    done = subprocess.run(argv, cwd=ROOT, capture_output=True, text=True, **kw)
    log.write(done.stdout + done.stderr)
    log.flush()
    return done


def reset(args, log):
    """Loads the bitstream fresh, with the USB port detached meanwhile."""
    run(["mpremote", "connect", os.environ["PICO"], "exec", DETACH], log)
    return run(["openFPGALoader", "-b", "icepi-zero", args.bitstream], log).returncode == 0


def hex_words(text):
    return [int(line, 16) for line in text.split() if re.fullmatch(r"[0-9a-f]{4}", line)]


def assemble(generate, k, check):
    """Returns the words, certificate and the assembler's summary line for test/uart_tx.asm
    with `out pins, 1 [k]`. Without check the timing check is off, as the late copy needs."""
    source = re.sub(r"out pins, 1", "out pins, 1 [%d]" % k, (ROOT / SOURCE).read_text())
    with tempfile.NamedTemporaryFile("w", suffix=".asm") as f:
        f.write(source)
        f.flush()
        flags = [] if check else ["-no-timing-check"]
        words, certificate = (subprocess.run([generate, "assemble", *flags, *more, f.name],
                                             capture_output=True, text=True)
                              for more in ([], ["-certificate"]))
        summary = subprocess.run([generate, "assemble", f.name], capture_output=True, text=True)
    said = (summary.stdout + summary.stderr).splitlines()
    line = next((x for x in said if "deadline waits" in x), "")
    return {"words": hex_words(words.stdout), "certificate": hex_words(certificate.stdout),
            "summary": line.replace(f.name + ": ", "")}


def programs(generate):
    return {"late": assemble(generate, LATE_K, False), "fixed": assemble(generate, FIXED_K, True)}


def upload(log):
    run(["mpremote", "connect", os.environ["PICO"], "cp", *FILES, ":"], log)


def on_pico(args, log, which, data):
    """Loads the late or fixed program and returns the RESULT line's fields."""
    v = json.load(open(args.programs))[which]
    script = ("import demo_video, pico_board\n"
              "demo_video.run(pico_board.PicoSpi().transfer, %s, %s, %s)\n"
              % (v["words"], v["certificate"], list(data)))
    pico = ["mpremote", "connect", os.environ["PICO"]]
    with tempfile.NamedTemporaryFile("w", suffix=".py") as f:
        f.write(script)
        f.flush()
        out = run(pico + ["run", f.name], log).stdout
    found = [line.split()[1:] for line in out.splitlines() if line.startswith("RESULT")]
    return found[-1] if found else None


def shot_late(args, log, shot_dir):
    print("== 1. a late program, refused by the chip itself ==", flush=True)
    v = json.load(open(args.programs))["late"]
    print("test/uart_tx.asm with `out pins, 1 [13]`, its own certificate (%d words)"
          % len(v["certificate"]))
    print("assembler: %s" % v["summary"])
    upload(log)
    got = reset(args, log) and on_pico(args, log, "late", [])
    if not got or got[0] != "refused":
        print("the chip did not refuse it" if got else "no answer from the board")
        return False
    pc, reason, halted = int(got[1]), int(got[2]), int(got[3])
    print("chip check: REFUSED at pc %d, reason %d (%s)" % (
        pc, reason, REASONS.get(reason, "check %d failed" % reason)))
    print("engine 0 after a start: %s" % ("still halted" if halted else "RUNNING"))
    return bool(halted)


def pico_b_idle(log):
    """Puts Pico B on MicroPython unless it is: its GP1 shares OUT0's net."""
    ports = os.listdir("/dev/serial/by-id") if os.path.isdir("/dev/serial/by-id") else []
    serial = os.environ["PICO_B_SERIAL"].lower()
    if not any("micropython" in p.lower() and serial in p.lower() for p in ports):
        run(["demo/pico_b.sh", "micropython"], log)


def decode(sr, log):
    """Returns the bytes sigrok's UART decoder finds in the capture."""
    out = run(["sigrok-cli", "-i", str(sr), "-P", "uart:rx=D4:baudrate=%d" % BAUD,
               "-A", "uart=rx-data"], log).stdout
    return bytes(int(h, 16) for h in re.findall(r"^uart-1: ([0-9A-F]{2})$", out, re.M))


def shot_fixed(args, log, shot_dir):
    print("== 2. the same with [12], running, decoded by sigrok ==", flush=True)
    v = json.load(open(args.programs))["fixed"]
    print("test/uart_tx.asm with `out pins, 1 [12]`, its own certificate (%d words)"
          % len(v["certificate"]))
    print("assembler: %s" % v["summary"])
    pico_b_idle(log)
    if not reset(args, log):
        print("the bitstream did not load")
        return False
    upload(log)
    sr = shot_dir / "fixed.sr"
    env = os.environ | {"ANALYSER": "A", "TRIES": "1", "RATE": "24M"}
    capture = subprocess.Popen(["demo/capture.sh", str(sr), "7000"], cwd=ROOT, env=env,
                               stdout=log, stderr=log)
    time.sleep(ARM_S)
    got = on_pico(args, log, "fixed", SENT)
    print("waiting for the capture...", flush=True)
    capture.wait()
    if not got or got[0] != "ran":
        print("the chip refused the 12-cycle program" if got else "no answer from the board")
        return False
    print("chip check: accepted, engine %s, faults 0x%s" % (
        "running" if got[1] == "0" else "halted", got[2]))
    heard = decode(sr, log) if sr.exists() else b""
    print("sigrok uart %d baud on OUT0: %s = %r" % (
        BAUD, " ".join("%02X" % b for b in heard), heard.decode(errors="replace")))
    return got[1] == "0" and int(got[2], 16) == 0 and heard == SENT


def ledger(args, log, shot_dir, demo):
    """Runs one demo through demo/ledger.py and returns its directory and verdict."""
    evidence = shot_dir / "ledger"
    argv = [sys.executable, "demo/ledger.py", args.bitstream, "--only", demo,
            "--evidence", str(evidence), "--results", str(shot_dir / "results.tsv")]
    if demo == "keyboard":
        argv.append("--keyboard")
    print("waiting for the capture...", flush=True)
    (shot_dir / "ledger.out").write_text(run(argv, log).stdout)
    found = sorted(evidence.glob("*/ledger/%s*/ledger.txt" % demo))
    if not found:
        return None, "ERROR"
    fields = dict(line.split(": ", 1) for line in found[-1].read_text().splitlines()
                  if ": " in line)
    return found[-1].parent, fields.get("result", "ERROR")


def shot_heldout(args, log, shot_dir):
    print("== 3. a held-out protocol: DALI, decoded by sigrok ==", flush=True)
    where, result = ledger(args, log, shot_dir, "dali")
    if where is None:
        print("the ledger run left nothing")
        return False
    print((where / "dali.decode").read_text().rstrip())
    print("capture checked against the frames sent: %s" % result)
    return result == "PASS"


def shot_keyboard(args, log, shot_dir):
    print("== 4. the USB keyboard, as the host sees it ==", flush=True)
    where, result = ledger(args, log, shot_dir, "keyboard")
    if where is None:
        print("the ledger run left nothing")
        return False
    keys = (where / "keyboard.keys").read_text() if (where / "keyboard.keys").exists() else ""
    grabbed = re.findall(r"^grab \S+ \S+ (.*)$", keys, re.M)
    typed = "".join(re.findall(r"^key \S+ (.)$", keys, re.M))
    print("host enumerated: %s" % (grabbed[0] if grabbed else "nothing"))
    print("host received keys: %r" % typed)
    return result == "PASS"


def main():
    p = argparse.ArgumentParser()
    p.add_argument("shot", choices=["assemble", "late", "fixed", "heldout", "keyboard", "all"])
    p.add_argument("generate", nargs="?", help="generate.exe, for assemble")
    p.add_argument("--run", type=Path)
    p.add_argument("--bitstream")
    p.add_argument("--programs", required=True)
    args = p.parse_args()
    if args.shot == "assemble":
        Path(args.programs).write_text(json.dumps(programs(args.generate)))
        return
    if not (args.run and args.bitstream):
        sys.exit("--run and --bitstream are needed")
    if "PICO" not in os.environ:
        sys.exit("PICO=id:<serial of Pico A> is unset")
    shots = {"late": shot_late, "fixed": shot_fixed, "heldout": shot_heldout,
             "keyboard": shot_keyboard}
    ok = True
    for name in list(shots) if args.shot == "all" else [args.shot]:
        shot_dir = args.run / name
        shot_dir.mkdir(parents=True, exist_ok=True)
        start = time.monotonic()
        with open(shot_dir / "board.log", "a") as log:
            passed = shots[name](args, log, shot_dir)
        print("PASS" if passed else "FAIL", flush=True)
        print()
        with open(args.run / "times.txt", "a") as f:
            f.write("%s %s %.0f s\n" % (name, "PASS" if passed else "FAIL",
                                       time.monotonic() - start))
        ok = ok and passed
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
