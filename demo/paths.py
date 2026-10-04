# SPDX-License-Identifier: Apache-2.0
# The worst setup paths of a gds run's slow corner, with slack, each start, end and the
# cells between named by the src line demo/die.py's sources gives them.
# Usage: source env.sh && demo/paths.py GDS --provenance JSON [-n 10]
#        demo/paths.py --report max.rpt --cells cells.json, as test/paths does
import argparse
import glob
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
CORNER = "nom_slow_1p08V_125C"
# what the flow adds after synthesis, buffers and hold fixes, which no RTL made
ADDED = re.compile(r"(?:fanout|hold|rebuffer|split|wire|max_cap|max_length|input|output)\d+$")


def read_paths(text):
    """[(slack, startpoint, endpoint, cells from the startpoint on, the path's text)] of an
    OpenSTA report_checks, in its order."""
    paths = []
    for block in re.split(r"\n(?=Startpoint: )", text)[1:]:
        start = re.match(r"Startpoint: (\S+)", block).group(1)
        end = re.search(r"^Endpoint: (\S+)", block, re.M).group(1)
        slack = float(re.search(r"(-?[\d.]+)\s+slack \((?:MET|VIOLATED)\)", block).group(1))
        cells = []
        for cell in re.findall(r"[v^] (\S+)/\S+ \(", block[: block.index("data arrival time")]):
            if cell not in cells[-1:]:
                cells.append(cell)
        # a path from an input pin starts at no cell
        first = cells.index(start) if start in cells else 0
        paths.append((slack, start, end, cells[first:], block))
    return paths


def describe(paths, lines):
    """Each path as two lines: its rank, slack, start and end, then the src lines of the
    cells between, a run of cells from one line counted once. [lines] maps a cell to its
    line and whether its own name gave it."""

    def line(cell):
        source, own = lines.get(cell, (None, False))
        return ("" if own else "~") + source if source else "?"

    def point(cell):
        engine = re.search(r"engine_(\d+)\.sram_macro", cell)
        if cell.endswith(".sram"):
            name = "program SRAM, engine %s" % engine.group(1) if engine else "data SRAM"
        else:
            name = cell
        return "%s %s" % (name, line(cell))

    out = []
    for rank, slack, start, end, cells in paths:
        runs = []
        for cell in cells[1:-1]:
            if not ADDED.match(cell):
                if runs and runs[-1][0] == line(cell):
                    runs[-1][1] += 1
                else:
                    runs.append([line(cell), 1])
        added = sum(1 for c in cells[1:-1] if ADDED.match(c))
        out.append("%2d  %6.3f ns  %s  ->  %s" % (rank, slack, point(start), point(end)))
        out.append(
            "    "
            + ", ".join(s if n == 1 else "%s x%d" % (s, n) for s, n in runs)
            + ("  (+%d buffers)" % added if added else "")
        )
    return out


def run_lines(gds, provenance):
    """Each cell of a gds run's die -> its src line and whether its own name gave it."""
    sys.path[:0] = [HERE]
    import die

    run = os.path.join(gds, "runs", "wokwi")
    src = os.path.join(gds, "src")
    pdk = os.path.join(os.environ.get("PDK_ROOT", ""), os.environ.get("PDK", "ihp-sg13cmos5l"))
    lib = die.lef_cells(
        glob.glob(os.path.join(pdk, "libs.ref", "*_stdcell", "lef", "*_stdcell.lef"))
        + glob.glob(os.path.join(REPO, "macro", "*", "*.lef"))
    )
    _, components, nets = die.read_def(glob.glob(os.path.join(run, "final", "def", "*.def"))[0])
    verilog = os.path.join(src, "protocol_emulator.v")
    root = re.search(
        r"protocol_emulator\s+(\w+)\s*\(", open(os.path.join(src, "project.v")).read()
    ).group(1)
    kept = {
        c: t
        for c, (t, _, _) in components.items()
        if lib[t]["class"] in ("BLOCK", "CORE", "CORE TIEHIGH", "CORE TIELOW", "CORE ANTENNACELL")
    }
    synthesis = glob.glob(os.path.join(run, "*-yosys-synthesis", "*.nl.v.json"))[0]
    registers = die.registers(verilog)
    commit = json.load(open(os.path.join(run, "final", "commit_id.json")))["commit"]
    found, own = die.sources(
        kept,
        [([n] if n.startswith(root + ".") else [], pins) for n, pins in nets.items()],
        lib,
        die.read_hierarchy(verilog, root),
        {n: registers[line] for n, line in die.flop_lines(synthesis).items() if line in registers},
        die.read_provenance(provenance, commit),
        die.from_instances(verilog),
    )
    return {c: (s, c in own) for c, s in found.items()}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("gds", nargs="?", help="a gds run's GDS_logs artifact")
    parser.add_argument("--provenance", help="generate.exe provenance's JSON for the run's RTL")
    parser.add_argument("--report", help="a max.rpt, default the run's slow corner's")
    parser.add_argument("--cells", help="each cell's line as JSON, in place of the run's")
    parser.add_argument("-n", type=int, default=10, help="how many of the worst, default 10")
    parser.add_argument("--ranks", help="which of the worst, as 1,6, in place of -n")
    parser.add_argument("--fixture", help="also write the paths shown and their cells' lines")
    args = parser.parse_args()
    if not (args.cells or args.gds and args.provenance):
        parser.error("give GDS and --provenance, or --cells")
    report = args.report or glob.glob(
        os.path.join(args.gds, "runs", "wokwi", "*-openroad-stapostpnr", CORNER, "max.rpt")
    )[0]
    text = open(report).read()
    paths = read_paths(text)
    ranks = [int(r) for r in args.ranks.split(",")] if args.ranks else range(1, args.n + 1)
    shown = [(r, *paths[r - 1][:4]) for r in ranks if r <= len(paths)]
    lines = (
        {c: tuple(v) for c, v in json.load(open(args.cells)).items()}
        if args.cells
        else run_lines(args.gds, args.provenance)
    )
    corner = re.search(r"=+ (\S+) Corner", text)
    print(
        "%s, %d of %d setup paths by slack. ~ marks a line that is only the nearest named"
        " cell's." % (corner.group(1) if corner else report, len(shown), len(paths))
    )
    print("\n".join(describe(shown, lines)))
    if args.fixture:
        os.makedirs(args.fixture, exist_ok=True)
        with open(os.path.join(args.fixture, "max.rpt"), "w") as f:
            f.write(text[: text.index("\nStartpoint: ") + 1])
            f.write("\n".join(paths[r - 1][4].rstrip("\n") for r, *_ in shown) + "\n")
        on = sorted({c for *_, cells in shown for c in cells})
        with open(os.path.join(args.fixture, "cells.json"), "w") as f:
            json.dump({c: lines[c] for c in on if c in lines}, f, indent=0, sort_keys=True)
            f.write("\n")


if __name__ == "__main__":
    main()
