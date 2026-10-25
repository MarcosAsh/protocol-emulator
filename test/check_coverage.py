# SPDX-License-Identifier: Apache-2.0
# Checks Hardcaml's cyclesim coverage of src/ against test/coverage_triage.txt: every point
# the tests leave open must be triaged there, and every triaged point must still be open.
# Usage: python3 test/check_coverage.py test/coverage_triage.txt REPORT... [--holes]
#   a REPORT is a coverage.txt the test runner writes with HARDCAML_CYCLESIM_COVERAGE_VERBOSE=1,
#   or a directory of them (test/coverage.sh); all are merged as one
#
# Hardcaml merges only circuits that are structurally equal, so the engine inside every
# test bench counts apart. Here a point is a src/ signal: its module and local name, or,
# unnamed, the src/ frames of the stack that made it. Copies of a point in one circuit
# (loop iterations, a second engine) are covered only when all of them are; a point is
# closed when some circuit covered every copy. Signal waivers are already out of the
# report. Line numbers are only for reading: a point is told by the text of its lines.
import argparse
import collections
import hashlib
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# instance names in the hierarchy, and the module each is an instance of
INSTANCES = {
    "data_memory": "data_memory",
    "edge_stamps": "edge_stamps",
    "engine": "engine",
    "engines": "engines",
    "frame_rx": "frame_rx",
    "host_fifo": "host_fifo",
    "host_port": "host_port",
    "host_spi": "host_spi",
    "kernel_accepts": "kernel",
    "kernel_step": "kernel",
    "load_checker": "load_checker",
    "manchester_rx": "manchester_rx",
    "osr_step": "osr_kernel",
    "program_memory": "program_memory",
    "rx": "host_fifo",
    "solo": "solo",
    "sram_macro": "sram_macro",
    "top": "top",
    "tx": "host_fifo",
    "usb_frame_rx": "usb_frame_rx",
    "usb_rx": "usb_rx",
}

# the files of a module split in parts
PARTS = {"kernel_types": "kernel", "kernel_step": "kernel", "kernel_accepts": "kernel", "kernel_table": "kernel"}

# [@@deriving hardcaml] code sits at the record's field lines and its frame loses the
# caller: the engine's config registers are only ever made by the host port
DERIVED_OWNER = {"Protocol_emulator__Engine.Config": "host_port"}

FRAME = re.compile(r"^(\S+)\$(\S+):(\d+):(\d+)$")
KINDS = ["Mux", "Cases", "Reg", "Always state"]
SELF_LOOP = re.compile(r"!! unexpectedly saw: (\S+) -> \1")


def instance_module(segment):
    if re.fullmatch(r"engine_\d+", segment):
        return "engine"
    return INSTANCES.get(segment)


def split_name(name):
    """[top$engines$engine_1$x_next] is the engine's [x_next]."""
    segments = name.split("$")
    i = 0
    while i < len(segments) and instance_module(segments[i]) is None:
        i += 1
    module = None
    while i < len(segments) - 1 and instance_module(segments[i]) is not None:
        module = instance_module(segments[i])
        i += 1
    return module, "$".join(segments[i:])


_lines = {}


def source_line(file, line):
    if file not in _lines:
        path = ROOT / file
        _lines[file] = path.read_text().splitlines() if path.exists() else []
    lines = _lines[file]
    return " ".join(lines[line - 1].split()) if 0 < line <= len(lines) else "?"


def from_stack(frames):
    """The module and the src/ frames, innermost first, up to the module's hierarchy."""
    ours, module, derived = [], None, None
    for frame in frames:
        m = FRAME.match(frame)
        if not m:
            continue
        defname, file, line, col = m.group(1), m.group(2), int(m.group(3)), m.group(4)
        if defname.startswith("Hardcaml__Hierarchy"):
            break
        if not defname.startswith("Protocol_emulator__"):
            continue
        ours.append((file, line, col))
        owner = next((v for k, v in DERIVED_OWNER.items() if defname.startswith(k + ".")), None)
        if owner:
            derived = owner
        else:
            module = PARTS.get(Path(file).stem, Path(file).stem)
    module = module or derived
    if not ours or module is None:
        return None, None, None
    anchor = " < ".join(f"{f}:{c}:{source_line(f, l)}" for f, l, c in ours)
    where = " < ".join(f"{f}:{l}" for f, l, _ in ours)
    return module, anchor, where


def items(data, field):
    return " ".join(data.get(field, [])).split()


def cases(data, field):
    """A switch's cases, states sharing a branch, printed (A | B), as one."""
    return re.findall(r"\([^)]*\)|\S+", " ".join(data.get(field, [])))


def parse_point(kind, lines):
    waived = False
    names, frames, data, current, unexpected = None, [], collections.defaultdict(list), None, []
    i = 0
    while i < len(lines):
        raw = lines[i]
        line = raw.strip()
        if line.startswith("names:"):
            names = line[len("names:") :].strip() or lines[i + 1].strip()
        elif line == "call_stack:":
            i += 1
            while i < len(lines) and lines[i].startswith(" " * 8):
                frames.append(lines[i].strip())
                i += 1
            continue
        elif line.startswith("!!"):
            unexpected.append(" ".join([line] + [l.strip() for l in lines[i + 1 : i + 3] if l.startswith(" " * 8)]))
            current = None
        elif raw.startswith(" " * 4) and not raw.startswith(" " * 8) and ":" in line:
            current, _, value = line.partition(":")
            if value.strip():
                data[current].append(value.strip())
        elif raw.startswith(" " * 8) and current:
            data[current].append(line)
        i += 1
    # a state register's random power-up value is no state, so its switch takes the
    # default, until the clear. Hardcaml skips the first sample's 0 -> 0, as it assumes
    # a zero start; a random start S gives S -> S there instead
    if any("driving (state variable)" in line for line in lines):
        unexpected = [u for u in unexpected if u != "!! unexpectedly saw: default"]
    if kind == "Always state":
        unexpected = [u for u in unexpected if not SELF_LOOP.fullmatch(u)]
    if names:
        module, local = split_name(names)
        anchor, where = local, local
    else:
        module, anchor, where = from_stack(frames)
    if module is None:
        return None
    # the size is in the point: a parameter that changes it makes another point
    if kind == "Mux":
        never = {"=" + v for v in items(data, "never saw")}
        width = str(len(items(data, "saw selector values of")) + len(never))
    elif kind == "Cases":
        never = {"=" + v for v in cases(data, "never matched")}
        width = str(len(cases(data, "selector matched cases")) + len(never))
    elif kind == "Reg":
        width = data["width"][0]
        never = {"on" + b for b in items(data, "bits never toggled ON")}
        never |= {"off" + b for b in items(data, "bits never toggled OFF")}
        listed = len(never) + len(items(data, "bits toggled ON")) + len(items(data, "bits toggled OFF"))
        waived = listed < 2 * int(width)
    else:
        never = set(data.get("never saw", []))
        width = ""
    point = hashlib.sha1(f"{module}|{kind}|{width}|{anchor}".encode()).hexdigest()[:8]
    return point, (module, kind, width, where), never, unexpected, waived


def parse(path):
    circuits = Path(path).read_text().split("====== Circuit coverage for ")[1:]
    head = re.compile(r"\n(?=(?:%s) with id: )" % "|".join(KINDS))
    for circuit in circuits:
        points = []
        for block in head.split(circuit):
            m = re.match(r"(%s) with id: \d+\n" % "|".join(KINDS), block)
            if m:
                parsed = parse_point(m.group(1), block.split("\n")[1:])
                if parsed:
                    points.append(parsed)
        yield points


def read_triage(path):
    """[point [k/n] class reason], or [module name max class reason] for a module whose open
    points are only counted."""
    points, modules = {}, {}
    for n, line in enumerate(Path(path).read_text().splitlines(), 1):
        line = line.split("#", 1)[0].strip()
        if not line:
            continue
        words = line.split()
        if words[0] == "module":
            modules[words[1]] = int(words[2])
            continue
        share = None
        m = re.fullmatch(r"(\d+)/(\d+)", words[1])
        if m:
            share = int(m.group(1)) / int(m.group(2))
            words.pop(1)
        if words[1] not in ("constant", "unreachable", "open"):
            sys.exit(f"{path}:{n}: the class is constant, unreachable or open, not {words[1]}")
        points[words[0]] = (words[1], share)
    return points, modules


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("triage")
    parser.add_argument("coverage", nargs="+")
    parser.add_argument("--holes", action="store_true", help="list every open point")
    args = parser.parse_args()

    where, never_merged, best, unexpected = {}, {}, collections.defaultdict(float), []
    waived = set()
    reports = [
        report
        for path in map(Path, args.coverage)
        for report in (sorted(path.glob("*.txt")) if path.is_dir() else [path])
    ]
    for points in (p for report in reports for p in parse(report)):
        copies = collections.defaultdict(list)
        for point, info, never, unexp, has_waiver in points:
            where[point] = info
            copies[point].append(never)
            if has_waiver:
                waived.add(point)
            # nor is a transition from it one of the design's
            unexpected += [(point, u) for u in unexp if "!unknown_state" not in u]
        for point, nevers in copies.items():
            union = set().union(*nevers)
            never_merged[point] = union if point not in never_merged else never_merged[point] & union
            best[point] = max(best[point], sum(1 for n in nevers if not n) / len(nevers))

    triage, floors = read_triage(args.triage)
    failures = []
    rows = collections.defaultdict(collections.Counter)
    for point, (module, kind, width, _) in where.items():
        rows[module]["points"] += 1
        status = triage.get(point)
        if not never_merged[point]:
            rows[module]["waived" if point in waived else "hit"] += 1
            if status:
                failures.append(f"{point} is closed now: take it out of {args.triage}")
        elif status:
            rows[module][status[0]] += 1
            if status[1] is not None and best[point] + 1e-9 < status[1]:
                failures.append(f"{point} covered {best[point]:.2f} of its copies, not {status[1]:.2f}")
        else:
            rows[module]["open"] += 1
            if module not in floors:
                failures.append(f"{point} is open and not in {args.triage}")
    for module, most in floors.items():
        if rows[module]["open"] > most:
            failures.append(f"{module} has {rows[module]['open']} open points, more than {most}")
        elif rows[module]["open"] < most:
            failures.append(f"{module} has {rows[module]['open']} open points: lower {most} to that")
    for point in triage:
        if point not in where:
            failures.append(f"{point} in {args.triage} is no longer a point")
    for point, u in unexpected:
        failures.append(f"{point} saw what a waiver says it cannot: {u}")

    columns = ["points", "hit", "waived", "constant", "unreachable", "open"]
    print(f"{'module':16}" + "".join(f"{c:>12}" for c in columns))
    total = collections.Counter()
    for module in sorted(rows):
        total.update(rows[module])
        print(f"{module:16}" + "".join(f"{rows[module][c]:>12}" for c in columns))
    print(f"{'all':16}" + "".join(f"{total[c]:>12}" for c in columns))

    if args.holes:
        print()
        for point in sorted(where, key=lambda p: where[p]):
            if never_merged[point]:
                module, kind, width, place = where[point]
                status, share = triage.get(point, ("open", None))
                copies = f" ({best[point]:.2f} of its copies)" if share is not None else ""
                print(f"{point} {status:11} {module} {kind}/{width} {place}: never "
                      f"{' '.join(sorted(never_merged[point]))}{copies}")
    for failure in failures:
        print("FAIL", failure, file=sys.stderr)
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
