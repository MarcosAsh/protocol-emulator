# SPDX-License-Identifier: Apache-2.0
# Every UM10204 bus timing parameter of a capture's I2C, a line each: how many were
# measured, the least, how many fail, pass or sit within a sample of the limit, then each
# fail by its samples. The i2c_timing sigrok decoder makes the same checks for PulseView:
#   SIGROKDECODE_DIR=demo/decoders sigrok-cli -i CAPTURE.sr -P i2c_timing:scl=D7:sda=D6
# Usage: python3 demo/i2c_timing.py [--mode fast] [--scl D7 --sda D6] CAPTURE.sr

import argparse
import os
import re
import sys

import sigrok

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "decoders",
                                "i2c_timing"))
import timing  # noqa: E402


def levels(samples, bit):
    return samples.translate(bytes((b >> bit) & 1 for b in range(256)))


def changes(level):
    return [m.start() + 1 for m in re.finditer(b"(?=\x00\x01|\x01\x00)", level)]


def check(path, mode, scl="D7", sda="D6"):
    """The capture's sample rate, every result in the order the checker made them, and the
    SCL edges outside a transaction."""
    rate, channels, samples = sigrok.read(path)
    bit = {name: b for b, name in channels.items()}
    scl_level, sda_level = levels(samples, bit[scl]), levels(samples, bit[sda])
    checker = timing.Checker(rate, mode)
    out = []
    for at in [0] + sorted(set(changes(scl_level) + changes(sda_level))):
        out += checker.edge(at, scl_level[at], sda_level[at])
    return rate, out + checker.finish(), checker.stray


def report(rate, results, stray, mode, shown=5):
    lines = ["%s, %s, %.2f ns a sample" % (timing.SHEET, mode, 1e9 / rate)]
    if stray:
        lines.append("  SCL edges outside any START to STOP: %d" % stray)
    for parameter, kind, *_ in timing.LIMITS:
        _, value = timing.limit(parameter, mode)
        unit = "kHz" if parameter == "fSCL" else "ns"
        sign = "<=" if kind == "at_most" else ">="
        bound = "%s %s %d %s" % (parameter, sign, value, unit)
        if parameter in timing.UNMEASURED:
            lines.append("  %-20s can't tell: one logic threshold, not 0.3 and 0.7 VDD"
                         % bound)
            continue
        mine = [r for r in results if r.parameter == parameter]
        if not mine:
            lines.append("  %-20s none" % bound)
            continue
        count = {v: sum(r.verdict == v for r in mine) for v in timing.VERDICTS}
        verdict = ("FAIL" if count["fail"] else "can't tell" if count["unsure"] else "PASS")
        if parameter == "fSCL":
            least = "%.3f kHz most" % max(r.value for r in mine)
        else:
            least = "%.0f ns least" % min(r.value for r in mine)
        lines.append("  %-20s %-10s n=%-6d %-18s fail %d, pass %d, within a sample %d" % (
            bound, verdict, len(mine), least, count["fail"], count["pass"],
            count["unsure"]))
        fails = [r for r in mine if r.verdict == "fail"]
        for r in fails[:shown]:
            lines.append("    samples %d-%d (%.6f s): %s"
                         % (r.ss, r.es, r.ss / rate, r.text))
        if len(fails) > shown:
            lines.append("    and %d more" % (len(fails) - shown))
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("capture")
    parser.add_argument("--mode", default="standard", choices=timing.MODES)
    parser.add_argument("--scl", default="D7")
    parser.add_argument("--sda", default="D6")
    args = parser.parse_args()
    rate, results, stray = check(args.capture, args.mode, args.scl, args.sda)
    print(report(rate, results, stray, args.mode))
    sys.exit(1 if any(r.verdict == "fail" for r in results) else 0)


if __name__ == "__main__":
    main()
