# SPDX-License-Identifier: Apache-2.0
# The glitch map on the board. Runs every image from test/python/write_glitch_images.exe
# on the chip through Pico A, in batches of python/demo_glitch_map.py, and holds each
# frame's bytes and framing error to what the receiver's rows say. Nothing touches a pad:
# both engines meet on wire 20.
# Usage: PICO=id:<serial> python3 demo/glitch_map.py IMAGES --bitstream BIT --out DIR
#            [--frames N] [--batch N]
import argparse
import hashlib
import json
import os
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))


def mpremote(*args, log):
    command = ["mpremote", "connect", os.environ["PICO"], *args]
    done = subprocess.run(command, capture_output=True, text=True, timeout=600)
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


def batch_script(head, batch, frames):
    """The Pico side inline, so nothing is copied to the Pico's flash."""
    with open(os.path.join(HERE, "..", "python", "demo_glitch_map.py")) as f:
        source = f.read()
    images = [(i["k"], i["words"], i["config"]) for i in batch]
    return source + (
        "\nimport pico_board\n"
        "spi = pico_board.PicoSpi()\n"
        "run(spi.transfer, %s, %s, %s, frames=%d)\n"
        % (json.dumps(head["receiver"]), json.dumps(head["config"]), json.dumps(images),
           frames))


def parse(line):
    """A RESULT line as a dict, or None."""
    fields = line.split()
    if not fields or fields[0] != "RESULT":
        return None
    k, frame, irq, faults = int(fields[1]), int(fields[2]), int(fields[3]), int(fields[4], 16)
    words = [int(w, 16) for w in fields[5:]]
    return {"k": k, "frame": frame, "framing_error": bool(irq), "faults": faults,
            "words": words}


def verdict(image, result):
    if result["faults"]:
        return "FAULT %x" % result["faults"]
    same = (result["words"] == image["predict"]
            and result["framing_error"] == image["framing_error"])
    return "ok" if same else "DIFFERS"


def show(words, framing_error):
    text = " ".join("%02x" % w for w in words) or "nothing"
    return text + (" framing error" if framing_error else "")


def summary(images, results):
    """Runs of k with one outcome, rows against board, and the counts."""
    by_k = {}
    for r in results:
        by_k.setdefault(r["k"], []).append(r)
    rows = []
    for image in images:
        got = by_k.get(image["k"], [])
        seen = sorted({show(r["words"], r["framing_error"]) for r in got}) or ["not run"]
        rows.append((image["k"], show(image["predict"], image["framing_error"]),
                     " | ".join(seen)))
    lines = ["k         rows                board"]
    start = 0
    for n in range(1, len(rows) + 1):
        if n == len(rows) or rows[n][1:] != rows[start][1:]:
            first, last = rows[start][0], rows[n - 1][0]
            ks = str(first) if first == last else "%d-%d" % (first, last)
            lines.append("%-9s %-19s %s" % (ks, rows[start][1], rows[start][2]))
            start = n
    frames = len(results)
    ok = sum(r["verdict"] == "ok" for r in results)
    ks = len({r["k"] for r in results})
    lines.append("%d frames over %d of %d k: %d as the rows say, %d not" % (
        frames, ks, len(images), ok, frames - ok))
    # each data bit: the k whose frames cleared it
    for bit in range(8):
        cleared = sorted({r["k"] for r in results
                          if r["words"] and not r["words"][0] >> bit & 1})
        lines.append("bit %d cleared at k = %s" % (bit, " ".join(map(str, cleared)) or "none"))
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("images")
    parser.add_argument("--bitstream", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--frames", type=int, default=2)
    parser.add_argument("--batch", type=int, default=25)
    args = parser.parse_args()
    with open(args.images) as f:
        head, *images = [json.loads(line) for line in f if line.strip()]
    os.makedirs(args.out, exist_ok=True)
    log = open(os.path.join(args.out, "board.log"), "a")
    with open(args.bitstream, "rb") as f:
        digest = hashlib.sha256(f.read()).hexdigest()
    with open(os.path.join(args.out, "run.txt"), "a") as f:
        f.write("%s bitstream %s sha256 %s, %d images from %s, %d frames each\n" % (
            time.strftime("%Y-%m-%d %H:%M:%S"), args.bitstream, digest, len(images),
            args.images, args.frames))
    load_bitstream(args.bitstream, log)
    by_k = {i["k"]: i for i in images}
    results, pending, empty = [], list(images), 0
    while pending:
        batch = pending[:args.batch]
        with tempfile.NamedTemporaryFile("w", suffix=".py", delete=False) as script:
            script.write(batch_script(head, batch, args.frames))
        out = mpremote("run", script.name, log=log)
        os.unlink(script.name)
        got = [r for r in map(parse, out.splitlines()) if r]
        for r in got:
            r["verdict"] = verdict(by_k[r["k"]], r)
            print("k=%-4d frame %d  %-20s %s" % (
                r["k"], r["frame"], show(r["words"], r["framing_error"]), r["verdict"]),
                flush=True)
        results += got
        with open(os.path.join(args.out, "results.jsonl"), "a") as f:
            for r in got:
                f.write(json.dumps(r) + "\n")
        done_ks = {r["k"] for r in got
                   if sum(g["k"] == r["k"] for g in got) == args.frames}
        pending = [i for i in pending if i["k"] not in done_ks]
        if "DONE" not in out:
            empty = 0 if got else empty + 1
            if empty == 3:
                sys.exit("no result from the Pico three times: see %s/board.log" % args.out)
            # faults hold until reset
            load_bitstream(args.bitstream, log)
    text = summary(images, results)
    with open(os.path.join(args.out, "summary.txt"), "w") as f:
        f.write(text)
    print("\n" + text)


if __name__ == "__main__":
    main()
