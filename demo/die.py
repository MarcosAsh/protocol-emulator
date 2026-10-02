# SPDX-License-Identifier: Apache-2.0
# Draws the hardened die with every standard cell coloured by the RTL module it came from.
# A flop's module comes from the RTL line yosys keeps for it and its output net's name.
# Gates keep neither, so each takes the module of the nearest flop or named net it drives,
# else the nearest either way. --check scores that on the RTL synthesised a module at a time.
# Usage: gh run download RUN -R MarcosAsh/protocol-emulator -n GDS_logs -D gds
#        source env.sh && uv run demo/die.py gds/runs/wokwi -o docs/die.png [--check]
#
# /// script
# dependencies = ["matplotlib"]
# ///
import argparse
import collections
import glob
import json
import os
import re
import subprocess
import tempfile

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
from matplotlib.collections import PolyCollection  # noqa: E402
from matplotlib.patches import Rectangle  # noqa: E402

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# Clock, reset and enable nets join everything; leave out nets with more pins than this.
MAX_FANOUT = 32

SURFACE = "#fcfcfb"
SILICON = "#eceae4"
MACRO = "#dcdad3"
TEXT = "#0b0b0b"
SECONDARY = "#52514e"
MUTED = "#898781"

BLOCKS = [
    ("engine 0", "#2a78d6", "fetch, decode, ALU, shifters, timers, pins"),
    ("engine 1", "#4a3aa7", "a second, identical engine"),
    ("host FIFOs", "#eda100", "rx and tx per engine, 8 x 16 bits"),
    ("host port", "#e87ba4", "SPI, registers, each engine's config"),
    ("data memory", "#008300", "ports of the shared data SRAM"),
    ("glue", "#52514e", "reset, pad sync and sharing, clock tree"),
]


def lef_cells(paths):
    """Each cell's class, size and output pins."""
    cells = {}
    for path in paths:
        cell = None
        for line in open(path):
            words = line.split()
            if line.startswith("MACRO "):
                cell = cells[words[1]] = {"class": "", "size": (0.0, 0.0), "outputs": set()}
            elif not words or cell is None:
                continue
            elif words[0] == "CLASS" and not cell["class"]:
                cell["class"] = " ".join(words[1:-1])
            elif words[0] == "SIZE":
                cell["size"] = (float(words[1]), float(words[3]))
            elif words[0] == "PIN":
                pin = words[1]
            elif words[0] == "DIRECTION" and words[1] == "OUTPUT":
                cell["outputs"].add(pin)
    return cells


def read_def(path):
    """Die box, components as name -> (cell, x, y) in um, and nets as name ->
    [(component, pin)], clock nets left out."""
    text = open(path).read()
    scale = float(re.search(r"UNITS DISTANCE MICRONS (\d+)", text).group(1))
    box = re.search(r"DIEAREA \( (\S+) (\S+) \) \( (\S+) (\S+) \)", text)
    die = [float(v) / scale for v in box.groups()]
    section = text[text.index("\nCOMPONENTS") : text.index("\nEND COMPONENTS")]
    components = {
        m.group(1): (m.group(2), int(m.group(3)) / scale, int(m.group(4)) / scale)
        for m in re.finditer(r"- (\S+) (\S+)\s.*?(?:PLACED|FIXED) \( (-?\d+) (-?\d+) \)", section)
    }
    section = text[text.index("\nNETS") : text.index("\nEND NETS")]
    nets = {}
    for statement in section.split(";\n")[1:]:
        head, _, rest = statement.strip().partition(" + ")
        if head.startswith("- ") and "USE CLOCK" not in rest.split("\n")[0]:
            name, _, pins = head[2:].partition(" ")
            nets[name.replace("\\", "")] = [
                (c, p) for c, p in re.findall(r"\( (\S+) (\S+) \)", pins) if c != "PIN"
            ]
    return die, components, nets


def read_hierarchy(verilog, root):
    """Instance path -> module, each module's names that come from outside it (its inputs
    and plain copies of them), and the module each RTL line is in."""
    text = open(verilog).read()
    children, outside, starts = {}, {}, []
    for m in re.finditer(r"^module (\w+)(.*?)^endmodule", text, re.S | re.M):
        body = m.group(2)
        children[m.group(1)] = re.findall(r"^\s+(\w+)\s*\n\s+(\w+)\s*\n\s+\(", body, re.M)
        names = set(re.findall(r"^\s+input (?:\[\S+\] )?(\S+);", body, re.M))
        copies = re.findall(r"^\s+assign (\S+) = ([^\s\[;]+)(?:\[[\d:]+\])?;", body, re.M)
        for _ in range(3):
            names |= {a for a, b in copies if b in names}
        outside[m.group(1)] = names
        starts.append((text.count("\n", 0, m.start()) + 1, m.group(1)))

    def walk(module, path):
        yield path, module
        for child, name in children.get(module, []):
            yield from walk(child, path + "." + name)

    return dict(walk("protocol_emulator", root)), outside, starts


def flop_modules(synthesis, starts):
    """Each flop output's names -> the RTL module of the line yosys kept for the flop."""
    design = json.load(open(synthesis))["modules"]
    top = next(m for m in design.values() if m.get("attributes", {}).get("top"))
    names = bit_names(top)
    found = {}
    for cell in top["cells"].values():
        line = re.search(r"\.v:(\d+)", cell.get("attributes", {}).get("src", ""))
        if line and "Q" in cell["connections"]:
            module = [m for start, m in starts if start <= int(line.group(1))][-1]
            found.update((n, module) for n in names[cell["connections"]["Q"][0]])
    return found


def bit_names(top):
    names = collections.defaultdict(list)
    for name, net in top["netnames"].items():
        if not net.get("hide_name"):
            for i, bit in enumerate(net["bits"]):
                n = name if len(net["bits"]) == 1 else "%s[%d]" % (name, net.get("offset", 0) + i)
                names[bit].append(n)
    return names


def block_of(path, module):
    """The block of instance [path] of [module]; None for an engine outside an engine."""
    engine = re.search(r"engine_(\d+)", path or "")
    if module == "host_fifo":
        return "host FIFOs"
    if module in ("engine", "sram_macro") and engine:
        return "engine " + engine.group(1)
    if module == "engine":
        return None
    return {
        "data_memory": "data memory",
        "sram_macro": "data memory",
        "host_port": "host port",
        "host_spi": "host port",
    }.get(module, "glue")


def owner(name, by_path, rtl, outside):
    """The block of the cell driving a hierarchical net if the name tells, and a block it
    cannot be in. Without [rtl] that is the instance the name is in. With [rtl], a flop's
    module, it is the instance of that module on the name's path, else below it, else
    any. A name copied from an input is driven from outside the instance it is in."""
    parts = name.split(".")
    paths = [".".join(parts[:n]) for n in range(len(parts) - 1, 0, -1)]
    named_in = next((p for p in paths if p in by_path), None)
    if named_in is None:
        return None, None
    inside = re.sub(r"(\[\d+\])+$", "", parts[-1]) not in outside[by_path[named_in]]
    not_in = None if inside else block_of(named_in, by_path[named_in])
    if rtl is None:
        candidates = [named_in] if inside else []
    else:
        typed = [p for p in paths if by_path.get(p) == rtl and inside]
        below = [p for p, m in by_path.items() if m == rtl and p.startswith(named_in + ".")]
        every = [p for p, m in by_path.items() if m == rtl]
        candidates = typed[:1] or (inside and below) or every
    blocks = {block_of(p, by_path[p]) for p in candidates} - {not_in}
    return blocks.pop() if len(blocks) == 1 else None, not_in


def spread(seeds, edges, allowed, barred):
    """Labels every allowed cell [edges] reach from [seeds] with the label most of its
    nearest labelled cells carry, but never one [barred] rules out for it."""
    labels = dict(seeds)
    frontier = list(seeds)
    while frontier:
        votes = collections.defaultdict(collections.Counter)
        for cell in frontier:
            for other in edges[cell]:
                if other not in labels and other in allowed and labels[cell] not in barred[other]:
                    votes[other][labels[cell]] += 1
        for cell, count in votes.items():
            labels[cell] = max(sorted(count), key=count.get)
        frontier = list(votes)
    return labels


def label(cells, nets, lib, hierarchy, from_rtl):
    """Each cell's block, and the seeds: flops, named nets' drivers and macros. [nets] is
    [(hierarchical names, [(cell, pin)])]. Gates take the block of the nearest seed they
    drive first, flops of the nearest either way."""
    by_path, outside, _ = hierarchy
    seeds = {}
    barred = collections.defaultdict(set)
    neighbours = collections.defaultdict(list)
    upstream = collections.defaultdict(list)
    for names, pins in nets:
        drivers = [c for c, p in pins if p in lib[cells[c]]["outputs"]]
        if len(pins) <= MAX_FANOUT:
            for c, _ in pins:
                neighbours[c] += [o for o, _ in pins if o != c]
                if c not in drivers:
                    upstream[c] += drivers
        known = [(n, from_rtl[n]) for n in names if n in from_rtl] or [(n, None) for n in names]
        if not known:
            continue
        name, rtl = known[0]
        block, not_in = owner(name, by_path, rtl, outside)
        for c in drivers:
            barred[c].add(not_in)
            if block and (rtl or c not in seeds):
                seeds[c] = block
    logic = {c for c, t in cells.items() if lib[t]["class"] != "BLOCK"}
    gates = {c for c in logic if "Q" not in lib[cells[c]]["outputs"]}
    for c, t in cells.items():
        if lib[t]["class"] == "BLOCK":
            seeds[c] = owner(c, by_path, None, outside)[0]
        elif c not in neighbours:
            seeds[c] = "glue"
    labels = spread(seeds, upstream, gates, barred)
    labels = spread(labels, neighbours, logic, barred)
    return {c: labels.get(c, "glue") for c in logic}, seeds


def check(verilog, lib, hierarchy, keep, liberty):
    """Synthesises the RTL a module at a time with yosys, then flattens it, so each gate's
    name gives its instance. Labels it from the names in [keep] only, and counts the gates
    that get their own block."""
    src = os.path.dirname(verilog)
    top = re.search(r"module (\w+)", open(os.path.join(src, "project.v")).read()).group(1)
    blackboxes = [
        v
        for v in glob.glob(os.path.join(src, "*.v"))
        if not v.endswith(("protocol_emulator.v", "project.v"))
    ]
    with tempfile.TemporaryDirectory() as tmp:
        out = os.path.join(tmp, "netlist.json")
        script = "".join("read_verilog -lib %s; " % v for v in blackboxes) + (
            "read_verilog %s %s; hierarchy -top %s; synth -top %s; "
            "dfflibmap -liberty %s; abc -liberty %s; opt_clean; flatten; opt_clean; "
            "write_json %s"
            % (verilog, os.path.join(src, "project.v"), top, top, liberty, liberty, out)
        )
        subprocess.run(["yosys", "-q", "-p", script], check=True, stdout=subprocess.DEVNULL)
        design = json.load(open(out))["modules"][top]
        from_rtl = flop_modules(out, hierarchy[2])
    names = bit_names(design)
    cells, pins, truth = {}, collections.defaultdict(list), {}
    for name, cell in design["cells"].items():
        if cell["type"] not in lib:
            continue
        plain = name.replace("$flatten", "").replace("\\", "")
        cells[plain] = cell["type"]
        path = re.match(r"(\w+(?:\.\w+)*)\.", plain)
        truth[plain] = block_of(path and path.group(1), hierarchy[0].get(path and path.group(1)))
        for port, bits in cell["connections"].items():
            for bit in bits:
                pins[bit].append((plain, port))
    root = next(iter(hierarchy[0]))
    nets = [
        ([n for n in names[b] if n in keep and n.startswith(root + ".")], ps)
        for b, ps in pins.items()
        if isinstance(b, int)
    ]
    labels, seeds = label(cells, nets, lib, hierarchy, from_rtl)
    gates = [c for c in labels if c not in seeds]
    return sum(1 for c in gates if labels[c] == truth[c]), len(gates)


def draw(die, components, lib, labels, notes, output):
    polys = collections.defaultdict(list)
    count = collections.Counter()
    area = collections.Counter()
    macros = []
    for c, (cell, x, y) in components.items():
        w, h = lib[cell]["size"]
        if lib[cell]["class"] == "BLOCK":
            macros.append((c, x, y, w, h))
        elif c in labels:
            polys[labels[c]].append([(x, y), (x + w, y), (x + w, y + h), (x, y + h)])
            count[labels[c]] += 1
            area[labels[c]] += w * h
    count["SRAM macros"] = len(macros)
    area["SRAM macros"] = sum(w * h for _, _, _, w, h in macros)
    total = sum(area.values())

    x0, y0, x1, y1 = die
    width, margin = 8.5, 0.3
    die_height = (width - 2 * margin) * (y1 - y0) / (x1 - x0)
    legend = margin + die_height + 0.6
    height = legend + 4 * 0.48 + 0.2 * len(notes) + 0.2
    fig = plt.figure(figsize=(width, height), dpi=1600 / width)
    fig.patch.set_facecolor(SURFACE)

    def at(x, y):
        return x / width, 1 - y / height

    ax = fig.add_axes(
        [*at(margin, margin + die_height), 1 - 2 * margin / width, die_height / height]
    )
    ax.set_xlim(x0, x1)
    ax.set_ylim(y0, y1)
    ax.axis("off")
    ax.add_patch(Rectangle((x0, y0), x1 - x0, y1 - y0, facecolor=SILICON, edgecolor="none"))
    for name, colour, _ in BLOCKS:
        ax.add_collection(PolyCollection(polys[name], facecolors=colour, linewidths=0))
    for c, x, y, w, h in macros:
        engine = re.search(r"engine_(\d+)", c)
        ax.add_patch(Rectangle((x, y), w, h, facecolor=MACRO, edgecolor=SECONDARY, linewidth=1))
        ax.text(
            x + w / 2,
            y + h / 2,
            "program SRAM\nengine %s" % engine.group(1) if engine else "data SRAM",
            ha="center",
            va="center",
            color=TEXT,
            fontsize=11,
            linespacing=1.5,
        )

    rows = BLOCKS + [("SRAM macros", MACRO, "two program, one data, 512 x 16 each")]
    for n, (name, colour, detail) in enumerate(rows):
        x, y = margin + 4.1 * (n // 4), legend + 0.48 * (n % 4)
        if n % 4 == 0:
            fig.text(*at(x + 2.95, y - 0.3), "cells", color=MUTED, fontsize=9, ha="right")
            fig.text(*at(x + 3.75, y - 0.3), "area", color=MUTED, fontsize=9, ha="right")
        fig.patches.append(
            Rectangle(
                at(x, y + 0.03),
                0.15 / width,
                0.15 / height,
                facecolor=colour,
                transform=fig.transFigure,
                edgecolor=SECONDARY if colour == MACRO else "none",
            )
        )
        fig.text(*at(x + 0.26, y), name, color=TEXT, fontsize=11)
        fig.text(*at(x + 0.26, y + 0.2), detail, color=SECONDARY, fontsize=9)
        fig.text(
            *at(x + 2.95, y), "{:,}".format(count[name]), color=TEXT, fontsize=10.5, ha="right"
        )
        fig.text(
            *at(x + 3.75, y),
            "%.1f%%" % (100 * area[name] / total),
            color=TEXT,
            fontsize=10.5,
            ha="right",
        )
    for n, note in enumerate(notes):
        fig.text(*at(margin, legend + 4 * 0.48 + 0.2 * n), note, color=MUTED, fontsize=8.5)
    fig.savefig(output, facecolor=SURFACE)
    return count, area, total


def stamp(run, die):
    path = os.path.join(run, "final", "commit_id.json")
    size = "die %.0f x %.0f um" % (die[2] - die[0], die[3] - die[1])
    if not os.path.exists(path):
        return "Local run, %s." % size
    info = json.load(open(path))
    run_id = info["workflow_url"].rstrip("/").split("/")[-1]
    return "Gds run %s, commit %s, %s." % (run_id, info["commit"][:7], size)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("run", help="LibreLane run directory, like runs/wokwi")
    parser.add_argument("--verilog", help="the RTL it hardened, default RUN/../../src")
    parser.add_argument("-o", "--output", required=True, help=".png or .svg")
    parser.add_argument("--check", action="store_true", help="score the gates, needs yosys")
    args = parser.parse_args()
    verilog = args.verilog or os.path.join(args.run, "..", "..", "src", "protocol_emulator.v")
    pdk = os.path.join(os.environ.get("PDK_ROOT", ""), os.environ.get("PDK", "ihp-sg13cmos5l"))
    lefs = glob.glob(os.path.join(pdk, "libs.ref", "*_stdcell", "lef", "*_stdcell.lef"))
    if not lefs:
        parser.error("no standard cell LEF under PDK_ROOT: source env.sh")
    lib = lef_cells(lefs + glob.glob(os.path.join(REPO, "macro", "*", "*.lef")))
    die, components, nets = read_def(glob.glob(os.path.join(args.run, "final", "def", "*.def"))[0])
    project = open(os.path.join(os.path.dirname(verilog), "project.v")).read()
    root = re.search(r"protocol_emulator\s+(\w+)\s*\(", project).group(1)
    hierarchy = read_hierarchy(verilog, root)
    synthesis = glob.glob(os.path.join(args.run, "*-yosys-synthesis", "*.nl.v.json"))[0]
    from_rtl = flop_modules(synthesis, hierarchy[2])
    cells = {
        c: t
        for c, (t, _, _) in components.items()
        if lib[t]["class"] in ("BLOCK", "CORE", "CORE TIEHIGH", "CORE TIELOW", "CORE ANTENNACELL")
    }
    named = [([n] if n.startswith(root + ".") else [], pins) for n, pins in nets.items()]
    labels, seeds = label(cells, named, lib, hierarchy, from_rtl)
    flops = [c for c in labels if "Q" in lib[cells[c]]["outputs"]]
    notes = [
        stamp(args.run, die) + " Area is of placed cells and macros, fill left out.",
        "Flops by RTL line and net name, %s of %s. Gates by the nearest flop they feed."
        % ("{:,}".format(sum(1 for c in flops if c in seeds)), "{:,}".format(len(flops))),
    ]
    if args.check:
        liberty = glob.glob(
            os.path.join(pdk, "libs.ref", "*_stdcell", "lib", "*_typ_1p20V_25C.lib")
        )
        right, gates = check(verilog, lib, hierarchy, set(nets), liberty[0])
        notes.append(
            "On the RTL synthesised a module at a time, %.1f%% of gates get their own"
            " module that way (demo/die.py --check)." % (100 * right / gates)
        )
    count, area, total = draw(die, components, lib, labels, notes, args.output)
    for name, _, _ in BLOCKS + [("SRAM macros", None, None)]:
        print("%-12s %6d %5.1f%%" % (name, count[name], 100 * area[name] / total))
    print("\n".join(notes))


if __name__ == "__main__":
    main()
