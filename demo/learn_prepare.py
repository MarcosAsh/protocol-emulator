# SPDX-License-Identifier: Apache-2.0
# Files for a learn demo on the board (CPython, no numpy):
#   logger DIR GENERATE LINE...   the edge logger for each line (IO3, or IO3 and IO2 for a
#                                 clocked bus), assembled by generate.exe, as record.json
#   replay OUT RECORDING...       Pico B's segments from recordings in demo/edges.py's form,
#                                 [--scale S] [--until SECONDS] [--line NAME]
#   clocked OUT                   Pico B's segments for a two-wire bus of made frames, a
#                                 CRC-8/AUTOSAR last, the data moving 10 us after SCL falls
#   edges CAPTURE NAME=CHANNEL... a capture's edges as demo/edges.py prints them
# Usage: python3 demo/learn_prepare.py COMMAND ...

import argparse
import json
import re
import subprocess
import sys
import zipfile
from pathlib import Path

# the chip's pin numbers: IO2 is SCL and Pico B's GP3, IO3 SDA and Pico B's GP2
PINS = {"IO3": 15, "IO2": 14}
WIRE = 20
CONFIG_FIELDS = {"in_base", "in_count", "autopush", "push_threshold", "set_base", "set_count"}


def logger(pin, prefix):
    return "\n".join(prefix + [
        "    mov x, pins              ; the line's level when the logger starts",
        "    in x, 16",
        "    jmp x--, high",
        "low:",
        "    wait 1 pin %d" % pin,
        "    mov x, now",
        "    in x, 16",
        "high:",
        "    wait 0 pin %d" % pin,
        "    mov x, now",
        "    in x, 16",
        "    jmp low",
    ]) + "\n"


def assemble(generate, path, config):
    flags = ",".join("%s=%s" % (k, "true" if v is True else v) for k, v in config.items())
    done = subprocess.run([generate, "assemble", "-config", flags, str(path)],
                          capture_output=True, text=True)
    if done.returncode:
        sys.exit("%s refused: %s" % (path, done.stderr))
    print(done.stderr.strip(), file=sys.stderr)
    return [int(w, 16) for w in done.stdout.split()]


def logger_files(directory, generate, lines, ms):
    directory = Path(directory)
    directory.mkdir(parents=True, exist_ok=True)
    engines = []
    for engine, name in enumerate(lines if len(lines) == 1 else [lines[1], lines[0]]):
        pin = PINS[name]
        config = {"in_base": pin, "in_count": 1, "autopush": True, "push_threshold": 16}
        prefix = ["; the edge logger on %s, pin %d" % (name, pin)]
        sync = len(lines) == 2 and engine == 1
        if len(lines) == 2 and engine == 0:
            # raise the wire engine 1 stamps, which puts both on one clock
            config.update(set_base=WIRE, set_count=1)
            prefix.append("    set pins, 1")
        if sync:
            prefix += ["    wait 1 pin %d" % WIRE, "    mov x, now", "    in x, 16"]
        path = directory / ("logger_%s.asm" % name)
        path.write_text(logger(pin, prefix))
        words = assemble(generate, path, config)
        engines.append({"engine": engine, "name": name, "sync": sync, "words": words,
                        "config": {k: int(v) for k, v in config.items()}})
    (directory / "record.json").write_text(json.dumps({"engines": engines, "ms": ms}) + "\n")


def read_edges(path, line=None):
    text = Path(path).read_text().splitlines()
    rate = float(next(t for t in text if t.startswith("rate")).split()[1])
    pins = [t.split() for t in text if t.startswith("pin")]
    pin = next(p for p in pins if line is None or p[1] == line)
    return rate, int(pin[2]), [int(e) for e in pin[3:]]


def segments_of(rate, first, edges, scale, until):
    """(pull low, us) runs of one line held as GP2, the level at each edge, the line's own
    level before its first edge and after its last for 5 ms."""
    edges = [e for e in edges if e / rate < until] if until else edges
    out = [(1 if first == 0 else 0, 5000)]
    level = first
    total = 0.0
    done = 0
    for a, b in zip(edges, edges[1:]):
        level ^= 1
        total += (b - a) / rate * 1e6 * scale
        us = round(total) - done
        done += us
        out.append((1 if level == 0 else 0, us))
    level ^= 1
    out.append((1 if level == 0 else 0, 5000))
    return out


def crc8_autosar(data):
    crc = 0xFF
    for byte in data:
        crc ^= byte
        for _ in range(8):
            crc = ((crc << 1) ^ 0x2F) & 0xFF if crc & 0x80 else (crc << 1) & 0xFF
    return crc ^ 0xFF


# address, then command and value: a sensor bus nobody documented
FRAMES = [(0xA5, c, v) for c, v in [(0x01, 0x10), (0x02, 0x20), (0x03, 0x33), (0x01, 0x47),
                                    (0x04, 0x05), (0x02, 0x99), (0x05, 0xC8), (0x03, 0x0E),
                                    (0x06, 0x71), (0x01, 0xEE)]]
HALF_US = 100


def clocked_segments():
    """SCL is bit 1 (GP3, IO2), SDA bit 0 (GP2, IO3), each 1 when pulled low. SCL idles
    high; SDA moves only while SCL is low, so no I2C part on the bus sees a START."""
    out = [(0, 5000)]
    for frame in FRAMES:
        bits = []
        for byte in list(frame) + [crc8_autosar(frame)]:
            bits += [(byte >> (7 - i)) & 1 for i in range(8)]
        sda = 0
        for bit in bits:
            out.append((2 | sda, 10))
            sda = 0 if bit else 1
            out.append((2 | sda, HALF_US - 10))
            out.append((sda, HALF_US))
        out.append((sda, 10))
        out.append((0, 5000))
    return out


def edges_of(capture, probes):
    with zipfile.ZipFile(capture) as z:
        meta = z.read("metadata").decode()
        rate_text = re.search(r"samplerate=(\S+) (\w*Hz)", meta)
        scale = {"Hz": 1, "kHz": 1e3, "MHz": 1e6, "GHz": 1e9}[rate_text.group(2)]
        rate = float(rate_text.group(1)) * scale
        names = dict(re.findall(r"probe(\d+)=(\S+)", meta))
        prefix = re.search(r"capturefile=(\S+)", meta).group(1) + "-"
        chunks = sorted((n for n in z.namelist() if n.startswith(prefix)),
                        key=lambda n: int(n[len(prefix):]))
        samples = b"".join(z.read(n) for n in chunks)
    bits = {name: int(k) - 1 for k, name in names.items()}
    print("rate %d" % rate)
    print("length %d" % len(samples))
    for probe in probes:
        name, channel = probe.split("=")
        bit = bits[channel]
        table = bytes(((i >> bit) & 1) for i in range(256))
        levels = samples.translate(table)
        at = [m.start() + 1 for m in re.finditer(b"(?=\x00\x01|\x01\x00)", levels)]
        print("pin %s %d %s" % (name, levels[0] if levels else 0, " ".join(map(str, at))))


def main():
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    p = sub.add_parser("logger")
    p.add_argument("directory")
    p.add_argument("generate")
    p.add_argument("lines", nargs="+")
    p.add_argument("--ms", type=int, default=6000)
    p = sub.add_parser("replay")
    p.add_argument("out")
    p.add_argument("recordings", nargs="+")
    p.add_argument("--scale", type=float, default=1.0)
    p.add_argument("--until", type=float)
    p.add_argument("--line")
    p = sub.add_parser("clocked")
    p.add_argument("out")
    p = sub.add_parser("edges")
    p.add_argument("capture")
    p.add_argument("probes", nargs="+")
    args = parser.parse_args()
    if args.command == "logger":
        logger_files(args.directory, args.generate, args.lines, args.ms)
    elif args.command == "replay":
        segs = []
        for recording in args.recordings:
            rate, first, edges = read_edges(recording, args.line)
            segs += segments_of(rate, first, edges, args.scale, args.until)
        Path(args.out).write_text(json.dumps({"segments": segs}) + "\n")
        print("%d segments, %.2f s" % (len(segs), sum(us for _, us in segs) / 1e6))
    elif args.command == "clocked":
        segs = clocked_segments()
        Path(args.out).write_text(json.dumps({"segments": segs}) + "\n")
        print("%d segments, %.2f s" % (len(segs), sum(us for _, us in segs) / 1e6))
    else:
        edges_of(args.capture, args.probes)


if __name__ == "__main__":
    main()
