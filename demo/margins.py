#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# The parts' timing margins on the bench: every point test/python/write_margins.exe lists
# run on Pico A by python/demo_margins.py while analyser B captures, each repeat judged by
# what the part did, and the capture measured for what the chip drove and the part answered.
# A point already in OUT is kept, so a stopped run resumes.
# Usage:
#   PICO=id:<Pico A> ANALYSER_B_PORT=<port> demo/margins.py run MARGINS.json OUT
#       [--part P] [--parameter X] [--repeats N] [--cycles C,...]
#   demo/margins.py analyse MARGINS.json OUT [--part P] [--parameter X] [--again]
#   demo/margins.py table MARGINS.json OUT

import argparse
import collections
import json
import os
import re
import statistics
import subprocess
import sys
import time
from pathlib import Path

import sigrok

ROOT = Path(__file__).resolve().parent.parent
FILES = ["protocol_emulator.py", "pico_board.py", "bench.py", "bench_firmware.py",
         "demo_neopixel.py", "demo_eeprom.py", "demo_ds18b20.py", "demo_margins.py"]
RESET = ["openFPGALoader", "-b", "icepi-zero", "-r"]
# analyser B's channels, src/bench_wiring.ml
CHANNEL = {"SK6812": 4, "DS18B20": 5, "SDA": 6, "SCL": 7}
# A repeat passes when the step from its white frame's reading of ADC channel 3 to the
# next frame's is within this share of the references' lit-to-dark step: the reading
# drifts by about that much over a point, the same way for both frames.
VSYS_SHARE = 0.3
# below this step in volts the references cannot tell a lit pixel from a dark one
VSYS_LEAST_STEP = 0.0006
PATTERNS = [(0x0F, 0xF0, 0x7F), (0xF0, 0x0F, 0x1F)]
CONFIG_BITS = 0x60
# python/demo_margins.py's run, milliseconds: START_MS, then a point's work and the
# references, generous. The capture starts some 0.8 s after mpremote returns and covers
# the first repeats.
START_MS = 1000
CAPTURE_MS = 3000


def kind(sweep):
    """How demo_margins.py runs a sweep's points."""
    part, parameter = sweep["part"], sweep["parameter"]
    if part == "SK6812":
        return "pair" if parameter == "reset" else "single"
    if part == "DS18B20":
        if parameter in ("tRSTL", "presence sample"):
            return "reset"
        return "read" if parameter == "read sample" else "write"
    return None


def run_ms(sweep, repeats):
    """The longest a point takes on Pico A from its start, generous."""
    part = sweep["part"]
    if part == "SK6812":
        return START_MS + 1500 + repeats * 120
    if part == "24LC256":
        return START_MS + 2000 + repeats * 40
    return START_MS + 2500 + repeats * 120


def slug(text):
    return re.sub(r"[^A-Za-z0-9]+", "_", text).strip("_")


def point_dir(out, sweep, point):
    cycles = "%06d" % point["cycles"]
    return Path(out) / slug(sweep["part"]) / slug(sweep["parameter"]) / cycles


def mpremote(pico, *args, timeout=60):
    return subprocess.run(["mpremote", "connect", pico, *args], capture_output=True,
                          text=True, timeout=timeout)


def reset_chip():
    subprocess.run(RESET, capture_output=True, timeout=60, check=True)
    time.sleep(2)


def code(sweep, point, repeats):
    firmware = {"config": point["config"], "words": point["words"], "load": point["load"]}
    words = point["model_words"] if sweep["part"] == "24LC256" else None
    return ("import os\ntry:\n    os.remove('margins.log')\nexcept OSError:\n    pass\n"
            "import demo_margins\ndemo_margins.main(%r, %r, %d, %r, %r)\n"
            % (sweep["part"], firmware, repeats, kind(sweep), words))


def read_log(pico):
    got = mpremote(pico, "exec", "print(open('margins.log').read())")
    if got.returncode:
        return None
    return json.loads(got.stdout.strip().splitlines()[-1])


def run_point(args, sweep, point, where):
    """Runs one point under a capture, the chip reset and the point run again once if the
    run stopped; returns the Pico's dict."""
    where.mkdir(parents=True, exist_ok=True)
    sr = where / "capture.sr"
    env = dict(os.environ, ANALYSER="B", RATE="24M")
    for attempt in (1, 2):
        started = time.monotonic()
        capture = subprocess.run(
            [str(ROOT / "demo/capture.sh"), str(sr), str(CAPTURE_MS),
             "mpremote", "connect", args.pico, "exec", "--no-follow",
             code(sweep, point, args.repeats)],
            env=env, capture_output=True, text=True, timeout=300)
        (where / "capture.txt").write_text(capture.stdout + capture.stderr)
        left = run_ms(sweep, args.repeats) / 1000 - (time.monotonic() - started)
        if left > 0:
            time.sleep(left)
        out = read_log(args.pico)
        if out is not None and "error" not in out:
            out["attempts"] = attempt
            return out
        (where / ("attempt%d.txt" % attempt)).write_text(json.dumps(out))
        reset_chip()
    return out or {"error": "no log"}


def crc8(data):
    crc = 0
    for byte in data:
        for _ in range(8):
            mix = (crc ^ byte) & 1
            crc >>= 1
            if mix:
                crc ^= 0x8C
            byte >>= 1
    return crc


def judge(sweep, out, repeats):
    """Each repeat's pass, and a line on each, from the part's own answers."""
    part = sweep["part"]
    if "error" in out:
        return [False] * repeats, ["stopped: %s" % out["error"]]
    if part == "SK6812":
        lit_ref = statistics.median(out["ref_lit"])
        dark_ref = statistics.median(out["ref_dark"])
        step = dark_ref - lit_ref
        if step < VSYS_LEAST_STEP:
            return [False] * repeats, ["references %.2f mV apart: no contrast" % (step * 1e3)]
        ok, lines = [], []
        for lit, dark in zip(out["lit"], out["dark"]):
            good = abs((dark - lit) - step) < VSYS_SHARE * step
            ok.append(good)
            lines.append("white %+.2f mV, then %+.2f mV against dark, references %+.2f: %s" % (
                (lit - dark_ref) * 1e3, (dark - dark_ref) * 1e3, -step * 1e3,
                "pass" if good else "FAIL"))
        return ok + [False] * (repeats - len(ok)), lines
    replies = out["replies"]
    if part == "24LC256":
        expected = [0] * 5 + out["before"]
        ok = [r == expected for r in replies]
        lines = ["acks %s, bytes %s: %s" % (r[:5], " ".join("%02x" % b for b in r[5:]),
                                            "pass" if r == expected else "FAIL")
                 for r in replies]
    else:
        rom = out["before"][1]
        ok, lines = [], []
        for i, r in enumerate(replies):
            if kind(sweep) == "reset":
                good = r[1] == 0 and r[3:11] == rom
                text = "presence %s, ROM %s" % ("yes" if r[1] == 0 else "NO",
                                                " ".join("%02x" % b for b in r[3:11]))
            elif kind(sweep) == "read":
                good = r[2:10] == rom
                text = "ROM %s" % " ".join("%02x" % b for b in r[2:10])
            else:
                th, tl, config = PATTERNS[i % 2]
                pad = r[-9:]
                good = (crc8(pad) == 0 and pad[2] == th and pad[3] == tl
                        and pad[4] & CONFIG_BITS == config & CONFIG_BITS)
                text = "wrote %02x %02x %02x, read %s" % (
                    th, tl, config, " ".join("%02x" % b for b in pad))
            ok.append(good)
            lines.append("%s: %s" % (text, "pass" if good else "FAIL"))
    if out.get("stopped"):
        lines.append("stopped: %s" % out["stopped"])
    return ok + [False] * (repeats - len(ok)), lines


def runs(sr, channel):
    """Each level the channel held from its first change to its last, as (level, samples)."""
    rate, _, samples = sigrok.read(str(sr))
    at, to = sigrok.edges(samples, channel)
    return rate, [(int(to[i]), int(at[i + 1] - at[i])) for i in range(len(at) - 1)]


def near(widths, ns, rate, slack=1.5):
    """The widths within slack samples of ns, in ns."""
    s = ns * rate / 1e9
    return [w * 1e9 / rate for w in widths if abs(w - s) <= slack]


# A pulled-up line rises slowly past the analyser's threshold, so a low reads up to a few
# hundred ns long: on DQ and the I2C pair a width is looked for this far either side.
OPEN_DRAIN_SLACK = 12


def summary(values):
    if not values:
        return "none"
    return "n=%d %.0f..%.0f ns" % (len(values), min(values), max(values))


def wire(sweep, point, sr):
    """What the capture shows: the swept timing's widths near the design, and for the
    DS18B20 its own presence pulses and held zeros."""
    part, parameter, ns = sweep["part"], sweep["parameter"], point["ns"]
    if not sr.exists():
        return {"capture": "missing"}
    if part == "SK6812":
        rate, levels = runs(sr, CHANNEL["SK6812"])
        level = 1 if parameter in ("T0H", "T1H") else 0
        widths = [w for v, w in levels if v == level]
        return {"designed": ns, "on_wire": summary(near(widths, ns, rate))}
    if part == "DS18B20":
        rate, levels = runs(sr, CHANNEL["DS18B20"])
        to_ns = 1e9 / rate
        found = {"designed": ns}
        if parameter in ("tRSTL", "tLOW0", "tLOW1"):
            found["on_wire"] = summary(
                near([w for v, w in levels if v == 0], ns, rate, OPEN_DRAIN_SLACK))
        elif parameter in ("tREC", "tSLOT + tREC"):
            pairs = [(levels[i][1], levels[i + 1][1]) for i in range(len(levels) - 1)
                     if levels[i][0] == 0]
            widths = [hi if parameter == "tREC" else lo + hi for lo, hi in pairs]
            found["on_wire"] = summary(near(widths, ns, rate, OPEN_DRAIN_SLACK))
        # a presence: a low under 300 us that follows a high under 70 us after a low of
        # 400 us or more
        presence = [(levels[i + 1][1] * to_ns, levels[i + 2][1] * to_ns)
                    for i in range(len(levels) - 2)
                    if levels[i][0] == 0 and levels[i][1] * to_ns >= 400_000
                    and levels[i + 1][1] * to_ns < 70_000 and levels[i + 2][1] * to_ns < 300_000]
        if presence:
            found["presence_after"] = summary([a for a, _ in presence])
            found["presence_low"] = summary([b for _, b in presence])
        # a read zero: the master's 6 us low that the part holds on, in the sweeps whose
        # lows are all the library's
        zeros = [w * to_ns for v, w in levels if v == 0 and 6_500 < w * to_ns < 55_000]
        if zeros and parameter in ("presence sample", "read sample"):
            found["read_zero_low"] = summary(zeros)
        return found
    rate, _, samples = sigrok.read(str(sr))
    import i2c_timing

    _, results, _ = i2c_timing.check(str(sr), "fast")
    name = {"THD:STA": "tHD;STA", "TSU:DAT": "tSU;DAT", "TBUF": "tBUF"}.get(parameter)
    found = {"designed": ns}
    if name:
        values = [r.value for r in results if r.parameter == name]
        found["on_wire"] = summary(
            [v for v in values if abs(v - ns) <= OPEN_DRAIN_SLACK * 1e9 / rate])
        found["least"] = "%.0f ns" % min(values) if values else "none"
    else:
        at, to = sigrok.edges(samples, CHANNEL["SCL"])
        rises = [int(a) for a, v in zip(at, to) if v]
        periods = [b - a for a, b in zip(rises, rises[1:])]
        found["on_wire"] = summary(near(periods, ns, rate, OPEN_DRAIN_SLACK))
    return found


def decode(sweep, sr):
    args = {"SK6812": ["-P", "rgb_led_ws281x:din=D4", "-A", "rgb_led_ws281x=rgb:reset"],
            "24LC256": ["-P", "i2c:sda=D6:scl=D7", "-A",
                        "i2c=start:repeat-start:stop:ack:nack:address-read:address-write:"
                        "data-read:data-write"],
            "DS18B20": ["-P", "onewire_link:owr=D5"]}[sweep["part"]]
    got = subprocess.run(["sigrok-cli", "-i", str(sr)] + args, capture_output=True,
                         text=True, timeout=300)
    return got.stdout + got.stderr


def sigrok_says(sweep, text, out):
    """What sigrok's decoder made of the capture, to set beside the Pico's view: the
    colours it read, the EEPROM reads that returned the reference bytes, or its 1-Wire
    events by kind."""
    lines = [line.split(": ", 1)[1] for line in text.splitlines() if ": " in line]
    if sweep["part"] == "SK6812":
        return dict(collections.Counter(lines).most_common(6))
    if sweep["part"] == "24LC256":
        reads, current = [], None
        for line in lines:
            if line in ("Start", "Start repeat"):
                current = []
            elif line.startswith("Data read: ") and current is not None:
                current.append(int(line.split(": ")[1], 16))
            elif line == "Stop" and current is not None:
                reads.append(current)
                current = None
        before = out.get("before") or []
        return {"reads": len([r for r in reads if r]),
                "reads_equal_to_reference": len([r for r in reads if r and r == before]),
                "nacks": lines.count("NACK")}
    kinds = collections.Counter(re.sub(r"[0-9]+", "#", line) for line in lines)
    return dict(kinds.most_common(6))


def run(args):
    margins = json.loads(Path(args.margins).read_text())
    out = Path(args.out)
    for f in FILES:
        mpremote(args.pico, "cp", str(ROOT / "python" / f), ":")
    reset_chip()
    # the first capture after the analyser takes its firmware can miss
    subprocess.run([str(ROOT / "demo/capture.sh"), str(out / "prime.sr"), "200"],
                   env=dict(os.environ, ANALYSER="B"), capture_output=True, timeout=120)
    cycles = args.cycles and {int(c) for c in args.cycles.split(",")}
    for sweep in margins["sweeps"]:
        if args.part and sweep["part"] != args.part:
            continue
        if args.parameter and sweep["parameter"] != args.parameter:
            continue
        reset_chip()
        for point in sweep["points"]:
            if "refused" in point or (cycles and point["cycles"] not in cycles):
                continue
            where = point_dir(out, sweep, point)
            if (where / "result.json").exists():
                continue
            started = time.monotonic()
            got = run_point(args, sweep, point, where)
            ok, lines = judge(sweep, got, args.repeats)
            result = {"part": sweep["part"], "parameter": sweep["parameter"],
                      "cycles": point["cycles"], "ns": point["ns"], "label": point["label"],
                      "in_spec": point["in_spec"], "repeats": args.repeats,
                      "passed": sum(ok), "ok": ok, "lines": lines, "pico": got,
                      "wire": wire(sweep, point, where / "capture.sr")}
            (where / "result.json").write_text(json.dumps(result, indent=1))
            print("%s %s %s: %d/%d pass, %s, %.0f s %s" % (
                sweep["part"], sweep["parameter"], fmt_ns(point["ns"]), sum(ok),
                args.repeats, result["wire"].get("on_wire", ""),
                time.monotonic() - started,
                "" if point["in_spec"] else "(OUT OF SPEC)"), flush=True)


def analyse(args):
    """Each run point's capture measured again and decoded by sigrok, which is too slow
    to do between points."""
    margins = json.loads(Path(args.margins).read_text())
    for sweep in margins["sweeps"]:
        if args.part and sweep["part"] != args.part:
            continue
        if args.parameter and sweep["parameter"] != args.parameter:
            continue
        for point in sweep["points"]:
            if "refused" in point:
                continue
            where = point_dir(args.out, sweep, point)
            path = where / "result.json"
            sr = where / "capture.sr"
            if not path.exists() or not sr.exists():
                continue
            if (where / "capture.decode").exists() and not args.again:
                continue
            result = json.loads(path.read_text())
            result["wire"] = wire(sweep, point, sr)
            text = decode(sweep, sr)
            (where / "capture.decode").write_text(text)
            result["sigrok"] = sigrok_says(sweep, text, result["pico"])
            path.write_text(json.dumps(result, indent=1))
            print("%s %s %s: %s %s" % (sweep["part"], sweep["parameter"],
                                       fmt_ns(point["ns"]), result["wire"],
                                       result["sigrok"]), flush=True)


def fmt_ns(ns):
    return "%.0f ns" % ns if ns < 1000 else "%g us" % round(ns / 1000, 3)


def table(args):
    """Each sweep's points as run, and its working range: the points around the library's
    timing that passed every repeat, with the first failure either side."""
    margins = json.loads(Path(args.margins).read_text())
    out = Path(args.out)
    lines = []
    for sweep in margins["sweeps"]:
        results = []
        for point in sweep["points"]:
            if "refused" in point:
                continue
            path = point_dir(out, sweep, point) / "result.json"
            if path.exists():
                result = json.loads(path.read_text())
                ok, _ = judge(sweep, result["pico"], result["repeats"])
                result["passed"] = sum(ok)
                result["label"] = point["label"]
                results.append(result)
        if not results:
            continue
        results.sort(key=lambda r: r["cycles"])
        nominal = sweep["nominal"]
        rows = [r for r in sweep["rows"] if r["parameter"] == sweep["parameter"]]
        sheet = ", ".join("%s %s" % (r["side"], fmt_ns(r["ns"])) for r in rows) or "-"
        lines.append("%s %s: sheet %s (%s); library %s; %d repeats a point" % (
            sweep["part"], sweep["parameter"], sheet,
            "; ".join(sorted({r["sheet"] for r in rows})) or "-",
            fmt_ns(nominal * 1e9 / margins["clock_hz"]), results[0]["repeats"]))
        lines.append("  observable: %s" % sweep["observable"])
        home = min(range(len(results)), key=lambda i: abs(results[i]["cycles"] - nominal))
        if results[home]["passed"] != results[home]["repeats"]:
            lines.append("  the point nearest the library's timing failed: no working range")
        else:
            lo = hi = home
            while lo > 0 and results[lo - 1]["passed"] == results[lo - 1]["repeats"]:
                lo -= 1
            while (hi < len(results) - 1
                   and results[hi + 1]["passed"] == results[hi + 1]["repeats"]):
                hi += 1
            edge = []
            for i, side in ((lo - 1, "below"), (hi + 1, "above")):
                if 0 <= i < len(results):
                    r = results[i]
                    edge.append("%s: %s failed %d of %d" % (
                        side, fmt_ns(r["ns"]), r["repeats"] - r["passed"], r["repeats"]))
                else:
                    edge.append("%s: none failed %s %s" % (
                        side, "down to" if side == "below" else "up to",
                        fmt_ns(results[0 if side == "below" else -1]["ns"])))
            lines.append("  works %s to %s; %s" % (
                fmt_ns(results[lo]["ns"]), fmt_ns(results[hi]["ns"]), "; ".join(edge)))
        refused = [p["refused"] for p in sweep["points"] if "refused" in p]
        if refused:
            lines.append("  refused by the kernel, not run: %d point%s, e.g. %s" % (
                len(refused), "" if len(refused) == 1 else "s", refused[0]))
        for r in results:
            lines.append("  %-10s %2d/%-2d %-38s %s" % (
                fmt_ns(r["ns"]), r["passed"], r["repeats"],
                r["wire"].get("on_wire", r["wire"].get("capture", "")),
                r["label"]))
        lines.append("")
    text = "\n".join(lines)
    (out / "TABLE.txt").write_text(text)
    print(text)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=["run", "analyse", "table"])
    parser.add_argument("margins")
    parser.add_argument("out")
    parser.add_argument("--part")
    parser.add_argument("--parameter")
    parser.add_argument("--repeats", type=int, default=20)
    parser.add_argument("--cycles")
    parser.add_argument("--again", action="store_true")
    args = parser.parse_args()
    args.pico = os.environ.get("PICO")
    if args.command == "run":
        if not args.pico:
            sys.exit("PICO=id:<serial of Pico A> is needed")
        run(args)
    elif args.command == "analyse":
        analyse(args)
    else:
        table(args)


if __name__ == "__main__":
    main()
