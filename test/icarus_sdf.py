# SPDX-License-Identifier: Apache-2.0
# Rewrites the flow's SDF, or the netlist, into what Icarus's annotator takes: the SRAM
# macros' escaped names become plain ones, each macro's per-bit IOPATHs one path per bus at
# the slowest bit's delay, and wires onto a macro's bus pins, which crash vvp, are dropped,
# as are the timing checks, which Icarus ignores and cannot parse on a bus bit.
# python3 icarus_sdf.py sdf|netlist < in > out

import re
import sys

MACRO = re.compile(r"\\?(core(?:\\?\.\w+)*\\?\.sram_macro\\?\.sram)\b ?")
TRIPLE = re.compile(r"\(([\d.]+):([\d.]+):([\d.]+)\)")


def plain(match):
    return match.group(1).replace("\\", "").replace(".", "_")


def netlist(lines):
    for line in lines:
        yield MACRO.sub(lambda m: plain(m) + " ", line) if "sram_macro" in line else line


def slowest(triples):
    return "(" + ":".join(f"{max(t[i] for t in triples):.3f}" for i in range(3)) + ")"


def sdf(lines):
    buses = {}
    depth = 0
    for line in lines:
        if depth or line.strip() == "(TIMINGCHECK":
            depth += line.count("(") - line.count(")")
            continue
        if "sram_macro" in line:
            if "INTERCONNECT" in line:
                continue
            line = MACRO.sub(plain, line)
        path = re.match(r"\s*\(IOPATH (\S+) (\w+)\[\d+\] (.*)\)$", line)
        if path:
            source, bus, delays = path.groups()
            rise, fall = [[float(x) for x in t] for t in TRIPLE.findall(delays)]
            buses.setdefault((source, bus), []).append((rise, fall))
            continue
        if buses and line.strip() == ")":
            for (source, bus), bits in buses.items():
                rise = slowest([b[0] for b in bits])
                fall = slowest([b[1] for b in bits])
                yield f"    (IOPATH {source} {bus} {rise} {fall})\n"
            buses = {}
        yield line


if __name__ == "__main__":
    sys.stdout.writelines({"sdf": sdf, "netlist": netlist}[sys.argv[1]](sys.stdin))
