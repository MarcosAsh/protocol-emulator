# SPDX-License-Identifier: Apache-2.0
# Data for pages/die: every cell and wire of a hardened run, and which nets switch on each
# cycle of its netlist sending "Jane St!" (demo/live_die_stimulus.py). Fails unless the
# netlist's pins equal the RTL's on every cycle. Cells are coloured as demo/die.py does.
# Usage: source env.sh && make -C pages/die, or demo/live_die.py GDS -o pages/die/die.bin
import argparse
import glob
import gzip
import json
import os
import re
import struct
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
sys.path[:0] = [HERE, os.path.join(REPO, "python")]
import die  # noqa: E402
import live_die_stimulus  # noqa: E402

# Coordinates are kept in steps of 20 nm, which puts a 6 x 4 tile die in 16 bits.
STEP = 20
SRAM = "SRAM macros"
LAYERS = ["Metal1", "Metal2", "Metal3", "Metal4", "Metal5", "TopMetal1", "TopMetal2"]
REGISTERS = {0: "control", 1: "status", 7: "tx", 9: "program address", 10: "program"}


def read_routes(path):
    """Each net's use, pins and routed segments [(layer, x1, y1, x2, y2)], and each pin's
    place, in DEF units. Vias and patches are left out."""
    text = open(path).read()
    section = text[text.index("\nNETS") : text.index("\nEND NETS")]
    nets = {}
    for statement in section.split(";\n")[1:]:
        statement = statement.strip()
        if not statement.startswith("- "):
            continue
        head, _, rest = statement.partition(" + ")
        name, _, pins = head[2:].partition(" ")
        use = re.search(r"\+ USE (\w+)", statement)
        segments = []
        for piece in re.split(r"\b(?:ROUTED|NEW|FIXED|COVER)\b", rest)[1:]:
            layer, _, route = piece.strip().partition(" ")
            points, x, y = [], None, None
            for px, py in re.findall(
                r"\( (\S+) (\S+)(?: \S+)? \)", re.sub(r"RECT \([^)]*\)", "", route)
            ):
                x = x if px == "*" else int(px)
                y = y if py == "*" else int(py)
                points.append((x, y))
            if layer in LAYERS:
                segments += [(LAYERS.index(layer), *a, *b) for a, b in zip(points, points[1:])]
        nets[name.replace("\\", "")] = {
            "use": use.group(1) if use else "SIGNAL",
            "pins": re.findall(r"\( (\S+) (\S+) \)", pins),
            "segments": segments,
        }
    section = text[text.index("\nPINS") : text.index("\nEND PINS")]
    places = re.finditer(
        r"- (\S+) \+ NET \S+ \+ DIRECTION \w+ \+ USE SIGNAL.*?PLACED \( (\d+) (\d+) \)",
        section,
        re.S,
    )
    return nets, {m.group(1): (int(m.group(2)), int(m.group(3))) for m in places}


def simulate(build, sources, defines, program, dump):
    """Runs the stimulus and returns what it wrote: the pins at each falling edge."""
    from cocotb_tools.runner import get_runner

    runner = get_runner("icarus")
    runner.build(
        sources=sources + [os.path.join(HERE, "live_die_tb.v")],
        hdl_toplevel="live_die_tb",
        defines=defines,
        build_dir=build,
        timescale=("1ns", "1ps"),
        always=True,
    )
    pins = os.path.join(build, "pins.json")
    os.environ["LIVE_DIE_PROGRAM"] = program
    os.environ["LIVE_DIE_PINS"] = pins
    # waves only switches icarus from -none to -fst, and the testbench picks what to dump
    runner.test(
        hdl_toplevel="live_die_tb",
        test_module="live_die_stimulus",
        build_dir=build,
        test_dir=build,
        waves=dump is not None,
        plusargs=["+dump=" + dump] if dump else [],
    )
    return json.load(open(pins))


def vcd_cycles(path):
    """Yields, for each clock cycle, the bit names whose value at its end differs from
    the end of the cycle before, and a function giving a bit's value then. A cycle
    starts at a rising edge of clk. Values start unknown."""
    vcd = subprocess.Popen(["fst2vcd", path], stdout=subprocess.PIPE, text=True)
    lines = iter(vcd.stdout)
    codes, where = {}, {}
    for line in lines:
        words = line.split()
        if words[:1] == ["$var"]:
            width, code, name = int(words[2]), words[3], words[4].lstrip("\\")
            bits = (
                [name] if width == 1 else ["%s[%d]" % (name, width - 1 - i) for i in range(width)]
            )
            codes.setdefault(code, [width, []])[1].append(bits)
            where.update((b, (code, i)) for i, b in enumerate(bits))
        elif words[:1] == ["$enddefinitions"]:
            break
    clock = where["clk"][0]
    values, start, block, rise, started = {}, {}, [], False, False

    def apply():
        for code, value in block:
            width = codes[code][0]
            start.setdefault(code, values.get(code, "x" * width))
            values[code] = value.rjust(width, "0" if value[0] == "1" else value[0])
        block.clear()

    def close():
        changed = set()
        for code, old in start.items():
            if values[code] != old:
                for bits in codes[code][1]:
                    changed.update(b for b, n, o in zip(bits, values[code], old) if n != o)
        start.clear()
        return changed

    def bit(name):
        code, i = where[name]
        return values.get(code, "x" * codes[code][0])[i]

    for line in lines:
        if line[0] == "#":
            if rise and started:
                yield close(), bit
            started |= rise
            apply()
            rise = False
        elif line[0] in "01xz":
            code = line[1:].strip()
            block.append((code, line[0]))
            rise |= code == clock and line[0] == "1"
        elif line[0] == "b":
            value, code = line[1:].split()
            block.append((code, value))
    apply()
    yield close(), bit
    vcd.wait()


def number(bits):
    """The unsigned value of bits MSB first, or None if any is unknown."""
    return int(bits, 2) if set(bits) <= {"0", "1"} else None


def instructions(asm):
    """The program's lines, one a word: labels and comments dropped."""
    lines = []
    for line in open(asm):
        line = re.sub(r"^\w+:", "", line.split(";")[0]).strip()
        if line:
            lines.append(re.sub(r"\s+", " ", line))
    return lines


def spi_frames(levels):
    """[first cycle, last cycle, what] for each host frame, from (sck, mosi, cs_n)."""
    frames, frame = [], None
    for cycle, (sck, mosi, cs_n) in enumerate(levels):
        if not cs_n and frame is None:
            frame, bits = [cycle, cycle, []], []
        if frame is None:
            continue
        if sck and not levels[cycle - 1][0]:
            bits.append(mosi)
        frame[1] = cycle
        if cs_n:
            data = [int("".join(map(str, bits[i : i + 8])), 2) for i in range(0, len(bits) - 7, 8)]
            reg = data[0] & 0x7F
            words = ["%04x" % ((a << 8) | b) for a, b in zip(data[1::2], data[2::2])]
            name = REGISTERS.get(reg) or "config %d" % (reg - 16)
            if data[0] & 0x80:
                frame[2] = " ".join(["write", name] + words)
            else:
                frame[2] = "read %s" % name
            frames.append(frame)
            frame = None
    return frames


def pin_labels(info):
    """Each top-level port bit's name in info.yaml's pinout, like uo_out[1] OUT0."""
    labels = {}
    for kind, n, label in re.findall(r'^\s+(ui|uo|uio)\[(\d)\]: "(.*)"', open(info).read(), re.M):
        for port in {"ui": ["ui_in"], "uo": ["uo_out"], "uio": ["uio_in", "uio_out", "uio_oe"]}[
            kind
        ]:
            labels["%s[%s]" % (port, n)] = label
    return labels


def varints(numbers):
    out = bytearray()
    for n in numbers:
        while n >= 0x80:
            out.append((n & 0x7F) | 0x80)
            n >>= 7
        out.append(n)
    return out


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("gds", help="a gds run's GDS_logs artifact, holding runs/ and src/")
    parser.add_argument("-o", "--output", required=True, help="the page's data, gzipped")
    parser.add_argument("--build", help="where the simulations run, default a temporary dir")
    args = parser.parse_args()
    run = os.path.join(args.gds, "runs", "wokwi")
    src = os.path.join(args.gds, "src")
    pdk = os.path.join(os.environ.get("PDK_ROOT", ""), os.environ.get("PDK", "ihp-sg13cmos5l"))
    stdcell = os.path.join(pdk, "libs.ref", "sg13cmos5l_stdcell")
    if not os.path.isdir(stdcell):
        parser.error("no standard cells under PDK_ROOT: source env.sh")
    models = [
        os.path.join(REPO, "test", "models", m)
        for m in ("RM_IHPSG13_1P_core_behavioral_bm_bist.v", "RM_IHPSG13_1P_512x16_c2_bm_bist.v")
    ]
    program = os.path.join(REPO, "test", "uart_tx.hex")
    build = os.path.abspath(args.build or tempfile.mkdtemp(prefix="live_die"))

    # the RTL the run hardened, then its netlist, on the same stimulus
    rtl = simulate(
        os.path.join(build, "rtl"),
        [os.path.join(src, "project.v"), os.path.join(src, "protocol_emulator.v")] + models,
        {"FUNCTIONAL": 1},
        program,
        None,
    )
    dump = os.path.join(build, "gl", "nets.fst")
    gates = simulate(
        os.path.join(build, "gl"),
        [os.path.join(stdcell, "verilog", v) for v in ("sg13cmos5l_udp.v", "sg13cmos5l_stdcell.v")]
        + models
        + glob.glob(os.path.join(run, "final", "nl", "*.nl.v")),
        {"GL_TEST": 1, "FUNCTIONAL": 1, "SIM": 1},
        program,
        dump,
    )
    if rtl != gates:
        differ = [n for n, (a, b) in enumerate(zip(rtl["pins"], gates["pins"])) if a != b]
        sys.exit(
            "the netlist's pins leave the RTL's at cycle %s" % (differ or [len(rtl["pins"])])[0]
        )
    out0 = [int(uo[-2] == "1") for uo, _, _ in gates["pins"]]
    uart = live_die_stimulus.frames(out0)
    if bytes(b for _, _, b in uart) != live_die_stimulus.MESSAGE or gates["status"]:
        sys.exit("sent %r, status %04x" % (uart, gates["status"]))

    lib = die.lef_cells(
        glob.glob(os.path.join(stdcell, "lef", "*_stdcell.lef"))
        + glob.glob(os.path.join(REPO, "macro", "*", "*.lef"))
    )
    def_path = glob.glob(os.path.join(run, "final", "def", "*.def"))[0]
    box, components, die_nets = die.read_def(def_path)
    routes, places = read_routes(def_path)
    project = open(os.path.join(src, "project.v")).read()
    root = re.search(r"protocol_emulator\s+(\w+)\s*\(", project).group(1)
    hierarchy = die.read_hierarchy(os.path.join(src, "protocol_emulator.v"), root)
    synthesis = glob.glob(os.path.join(run, "*-yosys-synthesis", "*.nl.v.json"))[0]
    kept = {
        c: t
        for c, (t, _, _) in components.items()
        if lib[t]["class"] in ("BLOCK", "CORE", "CORE TIEHIGH", "CORE TIELOW", "CORE ANTENNACELL")
    }
    named = [([n] if n.startswith(root + ".") else [], pins) for n, pins in die_nets.items()]
    labels, _ = die.label(kept, named, lib, hierarchy, die.flop_modules(synthesis, hierarchy[2]))

    # cells by block, then row, so a cycle's toggles sit close together
    blocks = [name for name, _, _ in die.BLOCKS] + [SRAM]
    macros = sorted(c for c, t in kept.items() if lib[t]["class"] == "BLOCK")
    order = sorted(
        (c for c in kept if c in labels),
        key=lambda c: (blocks.index(labels[c]), components[c][2], components[c][1]),
    )
    order += macros
    index = {c: n for n, c in enumerate(order)}
    masters = sorted({kept[c] for c in order})

    # the nets a kept cell or a pin drives, clocks aside, as they change at both edges and
    # so never between two rising ones
    nets = []
    for name, net in routes.items():
        if net["use"] != "SIGNAL":
            continue
        drivers = [index[c] for c, p in net["pins"] if c in index and p in lib[kept[c]]["outputs"]]
        if drivers or any(c == "PIN" for c, _ in net["pins"]):
            nets.append((drivers[0] if drivers else 0xFFFF, name, net["segments"]))
    nets.sort()
    net_index = {name: n for n, (_, name, _) in enumerate(nets)}

    pc = ["%s.top.engines.engine_0.pc[%d]" % (root, i) for i in range(8, -1, -1)]
    levels, signals, toggles = [], [], []
    for changed, bit in vcd_cycles(dump):
        toggles.append(sorted(net_index[n] for n in changed if n in net_index))
        levels.append(tuple(int(bit("ui_in[%d]" % i) == "1") for i in range(3)))
        signals.append((number("".join(map(bit, pc))), number(bit("uo_out[1]"))))
    if [s[1] for s in signals] != [number(uo[-2]) for uo, _, _ in gates["pins"]]:
        sys.exit("the dump's cycles are not the stimulus's")

    def at(v):
        return round(v * 1000 - box[0] * 1000) // STEP

    geometry = bytearray()
    for c in order:
        t, x, y = components[c]
        w, h = lib[t]["size"]
        geometry += struct.pack(
            "<4H", at(x), at(y), round(w * 1000) // STEP, round(h * 1000) // STEP
        )
    cells = bytes(blocks.index(labels.get(c, SRAM)) for c in order)
    cells += struct.pack("<%dH" % len(order), *(masters.index(kept[c]) for c in order))
    drivers = varints(b - a for a, b in zip([0] + [d for d, _, _ in nets], [d for d, _, _ in nets]))
    counts = varints(len(s) for _, _, s in nets)
    # each segment as its layer, its first end from the last segment's and its second
    # from its first, signed numbers zigzagged
    wires = bytearray()
    for _, _, segments in nets:
        x, y = 0, 0
        for layer, *ends in segments:
            x1, y1, x2, y2 = (at(v / 1000) for v in ends)
            wires += varints(
                [layer] + [(d << 1) ^ (d >> 31) for d in (x1 - x, y1 - y, x2 - x1, y2 - y1)]
            )
            x, y = x1, y1
    flips = bytearray()
    for t in toggles:
        flips += varints([len(t)]) + varints(b - a - 1 for a, b in zip([-1] + t, t))

    sections = [geometry, cells, drivers, counts, wires, flips]
    pin_names = pin_labels(os.path.join(REPO, "info.yaml"))
    header = {
        "run": json.load(open(os.path.join(run, "final", "commit_id.json"))),
        "die": [at(box[2]), at(box[3])],
        "step_nm": STEP,
        "blocks": [[name, colour] for name, colour, _ in die.BLOCKS] + [[SRAM, "#9a978f"]],
        "layers": LAYERS,
        "masters": [m.removeprefix("sg13cmos5l_") for m in masters],
        "cells": len(order),
        "macros": [[index[c], c.removeprefix(root + ".")] for c in macros],
        "nets": len(nets),
        "names": {
            n: name.removeprefix(root + ".")
            for n, (_, name, _) in enumerate(nets)
            if name.startswith(root + ".") or name in places
        },
        "pins": [
            [name, pin_names.get(name, name), at(x / 1000), at(y / 1000), net_index.get(name, -1)]
            for name, (x, y) in sorted(places.items())
        ],
        "cycles": len(toggles),
        "pc": [s[0] for s in signals],
        "out0": [s[1] for s in signals],
        "program": instructions(os.path.join(REPO, "test", "uart_tx.asm")),
        "spi": spi_frames(levels),
        "uart": uart,
        "bit": live_die_stimulus.BIT,
        "sections": [len(s) for s in sections],
    }
    head = json.dumps(header, separators=(",", ":")).encode()
    blob = b"DIE1" + struct.pack("<I", len(head)) + head
    blob += b"\0" * (-len(blob) % 4) + b"".join(sections)
    with open(args.output, "wb") as f:
        f.write(gzip.compress(blob, compresslevel=9, mtime=0))
    print(
        "%d cycles, %d cells, %d nets, %d wire segments, %d toggles; %d KB, %d KB gzipped"
        % (
            len(toggles),
            len(order),
            len(nets),
            sum(len(s) for _, _, s in nets),
            sum(map(len, toggles)),
            len(blob) >> 10,
            os.path.getsize(args.output) >> 10,
        )
    )


if __name__ == "__main__":
    main()
