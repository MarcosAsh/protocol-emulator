# SPDX-License-Identifier: Apache-2.0
# Mutation score of the OCaml tests: one textual mutation at a time, in copies under
# _mutation/. A survivor not in test/mutation_allow.txt exits 1, at --report with --json.
# Usage: python3 test/mutate.py [--scope engine|wide] [--file F ...] [--operator NAME ...]
#        [--id ID ...] [--shard I/N] [--seed S] [--jobs N] [--timeout S] [--json OUT] [--list]
#        python3 test/mutate.py --report OUT ...
import argparse
import hashlib
import json
import math
import os
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from queue import Queue

ALLOW = Path(__file__).with_name("mutation_allow.txt")
# test_provenance prints the byte and name counts of the chip's verilog, which a mutant of
# the chip changes whether or not it changes behaviour, so the mutants run without it; the
# committed verilog is still copied, as test/dune depends on it
COPIED = ["src", "test", "bin", "ppx", "python", "formal/Makefile", "dune-project", ".ocamlformat",
          "demo/paths.py", "demo/outline.py", "demo/draw.py", "demo/kernel_vs_board.py",
          "pages/die/die.bin", "test/paths/cells.json", "src/protocol_emulator.v"]
SKIPPED = shutil.ignore_patterns("sim_build", "__pycache__", "*.fst", "*.vcd", "*.xml", "*.v", "*.json",
                                 "test_provenance.ml*")

# the operators of the published score; its scope keeps exactly these
HARDWARE = [
    ("increment", r"\+:\. 1\b", "+:. 2"),
    ("decrement", r"-:\. 1\b", "-:. 2"),
    ("zero test", r"==:\. 0\b", "<>:. 0"),
    ("and to or", r" &: ", " |: "),
    ("or to and", r" \|: ", " &: "),
    ("drop enable", r" ~enable:go ", " "),
    ("drop op enable", r" ~enable:op_go ", " "),
    ("unsigned compare", r" >=: ", " >: "),
    ("less than", r" <: ", " <=: "),
    ("shift left", r"~f:srl", "~f:sll"),
    ("shift right", r"~f:sll", "~f:srl"),
    ("not", r"~:\(", "("),
    ("equal", r" ==: ", " <>: "),
    ("not equal", r" <>: ", " ==: "),
    ("add to subtract", r" \+: ", " -: "),
    ("xor to or", r" \^: ", " |: "),
    ("bit zero", r"\.:\(0\)", ".:(1)"),
    ("constant one", r"\bvdd\b", "gnd"),
    ("constant zero", r"\bgnd\b", "vdd"),
    ("jump cycles", r"Isa\.jmp_cycles - 1", "Isa.jmp_cycles"),
    ("greater", r" >:\. ", " >=:. "),
    ("not equal immediate", r" <>:\. ", " ==:. "),
    ("equal immediate", r" ==:\. (\d+)", lambda m: f" ==:. {int(m.group(1)) + 1}"),
    ("swap mux2 arms", r"mux2 (\w+) (\w+) (\w+)\b", r"mux2 \1 \3 \2"),
]

MORE_HARDWARE = [
    ("drop other enable", r" ~enable:(?!go |op_go )[\w.]+", ""),
    ("subtract to add", r" -: ", " +: "),
    ("at most", r" <=: ", " <: "),
    ("unsigned greater", r" >: ", " >=: "),
    ("less than immediate", r" <:\. ", " <=:. "),
    ("at most immediate", r" <=:\. ", " <:. "),
    ("at least immediate", r" >=:\. ", " >:. "),
    ("signed less than", r" <\+ ", " <=+ "),
    ("signed at most", r" <=\+ ", " <+ "),
    ("signed greater", r" >\+ ", " >=+ "),
    ("signed at least", r" >=\+ ", " >+ "),
]

# OCaml, for the code that elaborates the circuits and the analyser; the mutants that do
# not parse (a binding's [=]) are dropped before the run
SOFTWARE = [
    ("int plus one", r" \+ 1\b", " + 2"),
    ("int minus one", r" - 1\b", " - 2"),
    ("int add to subtract", r" \+ ", " - "),
    ("int subtract to add", r" - ", " + "),
    ("int add section", r"\( \+ \)", "( - )"),
    ("bool and to or", r" && ", " || "),
    ("bool or to and", r" \|\| ", " && "),
    ("int less than", r" < ", " <= "),
    ("int at most", r" <= ", " < "),
    ("int greater", r" > ", " >= "),
    ("int at least", r" >= ", " > "),
    ("int equal", r" = ", " <> "),
    ("int not equal", r" <> ", " = "),
    ("bool not", r"\bnot ", ""),
    ("bool true", r"\btrue\b", "false"),
    ("bool false", r"\bfalse\b", "true"),
    ("max to min", r"\bInt\.max\b", "Int.min"),
    ("min to max", r"\bInt\.min\b", "Int.max"),
]
PARSED = {name for name, _, _ in SOFTWARE}

# what each file is mutated with and the Verilog a mutant must still elaborate to
CHIP = [["top"], ["top", "-sram", "-engines", "2"]]
RTL = [
    "src/engine.ml", "src/decoder.ml", "src/pins.ml", "src/deadline.ml", "src/crc.ml",
    "src/host_port.ml", "src/host_spi.ml", "src/host_fifo.ml", "src/data_memory.ml",
    "src/program_memory.ml", "src/sram_macro.ml", "src/engines.ml", "src/top.ml",
]
ELABORATE = {f: CHIP for f in RTL} | {"src/kernel.ml": [["kernel"], ["kernel-accepts"]]}
# engine is the published score's four files, five mutants an operator each; wide is
# every file that makes RTL, the kernel and the analyser, every match
SCOPES = {
    "engine": {
        "files": ["src/engine.ml", "src/decoder.ml", "src/pins.ml", "src/host_port.ml"],
        "operators": lambda file: HARDWARE,
        "max_per_operator": 5,
    },
    "wide": {
        "files": RTL + ["src/kernel.ml", "src/analyser.ml", "src/interval.ml"],
        "operators": lambda file: (
            SOFTWARE if file in ["src/analyser.ml", "src/interval.ml"]
            else HARDWARE + MORE_HARDWARE + SOFTWARE),
        "max_per_operator": None,
    },
}


QUOTED = re.compile(r"\{([a-z_]*)\|")
CHAR = re.compile(r"'(\\.|[^\\'])'")


def mask(source):
    # comments and string literals as spaces, so no operator matches inside them
    out = list(source)
    i, depth, n = 0, 0, len(source)

    def blank(a, b):
        for k in range(a, b):
            if out[k] != "\n":
                out[k] = " "

    def string_end(i):
        i += 1
        while source[i] != '"':
            i += 2 if source[i] == "\\" else 1
        return i + 1

    start = 0
    while i < n:
        if source.startswith("(*", i):
            if depth == 0:
                start = i
            depth += 1
            i += 2
        elif depth and source.startswith("*)", i):
            depth -= 1
            i += 2
            if depth == 0:
                blank(start, i)
        elif source[i] == '"':
            end = string_end(i)
            if depth == 0:
                blank(i, end)
            i = end
        elif m := QUOTED.match(source, i):
            end = source.index("|" + m.group(1) + "}", m.end()) + len(m.group(0))
            if depth == 0:
                blank(i, end)
            i = end
        elif m := CHAR.match(source, i):
            i = m.end()
        else:
            i += 1
    return "".join(out)


def parses(source):
    with tempfile.TemporaryDirectory() as d:
        (Path(d) / "m.ml").write_text(source)
        return subprocess.run(["ocamlc", "-stop-after", "parsing", "-c", "m.ml"], cwd=d,
                              capture_output=True).returncode == 0


def mutants(scope, file, source):
    masked = mask(source)
    lines = source.split("\n")
    cap = SCOPES[scope]["max_per_operator"]
    seen = set()
    for name, pattern, replacement in SCOPES[scope]["operators"](file):
        found = [m for m in re.finditer(pattern, masked) if masked[m.start():m.end()] == source[m.start():m.end()]]
        for m in found[:cap]:
            new = replacement(m) if callable(replacement) else m.expand(replacement)
            mutated = source[: m.start()] + new + source[m.end():]
            if mutated in seen or (name in PARSED and not parses(mutated)):
                continue
            seen.add(mutated)
            line = source.count("\n", 0, m.start()) + 1
            after = mutated.split("\n")[line - 1]
            yield {"file": file, "operator": name, "line": line, "text": lines[line - 1].strip(),
                   "after": after.strip(), "mutated": mutated}


def plan(scope, files, seed, held_out):
    # a mutant's id and whether it is held out follow from its line, not where it is
    todo, count = [], {}
    root = Path(__file__).resolve().parent.parent
    for file in files:
        for m in mutants(scope, file, (root / file).read_text()):
            key = "\0".join([m["file"], m["operator"], m["text"]])
            count[key] = count.get(key, -1) + 1
            m["id"] = hashlib.sha256(f"{key}\0{count[key]}".encode()).hexdigest()[:8]
            pick = hashlib.sha256(f"{seed}\0{m['id']}".encode()).hexdigest()
            m["held_out"] = seed is not None and int(pick, 16) % 100 < held_out
            todo.append(m)
    return todo


def dune(cwd, command, *args, jobs=None, timeout=None):
    flags = ["-j", str(jobs)] if jobs else []
    p = subprocess.Popen(["dune", command, "--root", ".", *flags, *args], cwd=cwd, text=True,
                         stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, start_new_session=True)
    try:
        _, err = p.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        os.killpg(p.pid, signal.SIGKILL)
        p.communicate()
        raise
    return p.returncode, err


# dune names the file of each test that fails; CI forces colour, so codes are stripped first
FAILED = re.compile(r'^File "([^"]+)", line', re.M)
COLOUR = re.compile(r"\x1b\[[0-9;]*m")


def verdict(cwd, file, jobs, timeout):
    # a mutant that does not compile, or that Hardcaml refuses to elaborate, is not a mutant;
    # one whose generator loops would hang the tests too. A kill comes with the files of the
    # tests that failed.
    try:
        if dune(cwd, "build", "./bin/generate.exe", jobs=jobs, timeout=timeout)[0] != 0:
            return "invalid", []
        for args in ELABORATE.get(file, []):
            if dune(cwd, "exec", "--", "./bin/generate.exe", *args, jobs=jobs, timeout=timeout)[0] != 0:
                return "invalid", []
        code, err = dune(cwd, "build", "@runtest", jobs=jobs, timeout=timeout)
        if code == 0:
            return "survived", []
        return "killed", sorted(set(FAILED.findall(COLOUR.sub("", err))))
    except subprocess.TimeoutExpired:
        return "timeout", []


def read_allowed():
    allowed = {}
    for entry in ALLOW.read_text().splitlines():
        if entry and not entry.startswith("#"):
            file, name, text, reason = [field.strip() for field in entry.split(" ## ")]
            allowed[(file, name, text)] = reason
    return allowed


def wilson(k, n, z=1.96):
    if n == 0:
        return "no mutants"
    p = k / n
    centre = (p + z * z / (2 * n)) / (1 + z * z / n)
    half = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / (1 + z * z / n)
    return f"{100 * p:.2f}% [{100 * max(0, centre - half):.2f}, {100 * min(1, centre + half):.2f}]"


def report(results, planned):
    # a timeout counts as killed, as the suite does not pass, and is listed apart
    allowed = read_allowed()
    valid = [r for r in results if r["result"] != "invalid"]
    order = SCOPES["wide"]["files"]
    files = sorted({r["file"] for r in results}, key=lambda f: (order.index(f) if f in order else len(order), f))
    print(f"ran {len(results)} of {planned} planned mutants")
    for file in files + ["total"]:
        rows = [r for r in valid if file in (r["file"], "total")]
        killed = sum(1 for r in rows if r["result"] != "survived")
        timeouts = sum(1 for r in rows if r["result"] == "timeout")
        invalid = sum(1 for r in results if file in (r["file"], "total") and r["result"] == "invalid")
        print(f"{file}: killed {killed} of {len(rows)} valid mutants"
              f" ({timeouts} timed out, {invalid} invalid)")
    parts = [("all", [False, True])]
    if any(r["held_out"] for r in results):
        parts += [("in-sample", [False]), ("held-out", [True])]
    for label, held_out in parts:
        rows = [r for r in valid if r["held_out"] in held_out]
        killed = sum(1 for r in rows if r["result"] != "survived")
        print(f"{label}: killed {killed} of {len(rows)}, {wilson(killed, len(rows))} (Wilson 95%)")
    unexpected = []
    for r in sorted(valid, key=lambda r: (r["held_out"], files.index(r["file"]), r["line"])):
        if r["result"] in ("survived", "timeout"):
            reason = allowed.get((r["file"], r["operator"], r["text"]))
            if r["result"] == "survived" and reason is None:
                unexpected.append(r)
            tag = " held out" if r["held_out"] else ""
            print(f"{r['result']}: {r['operator']} at {r['file']}:{r['line']} [{r['id']}{tag}]:"
                  f" {reason or ('NOT ALLOWED' if r['result'] == 'survived' else 'counted killed')}"
                  f"\n    - {r['text']}\n    + {r['after']}")
    return 1 if unexpected or len(results) < planned else 0


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--scope", choices=SCOPES, default="engine")
    p.add_argument("--file", action="append", help="only these files of the scope")
    p.add_argument("--operator", action="append", help="only these operators")
    p.add_argument("--id", action="extend", nargs="+", help="only these mutants, as --list names them")
    p.add_argument("--shard", default="0/1", help="I/N: every Nth mutant from the Ith")
    p.add_argument("--seed", type=int, help="holds out a sample, scored apart")
    p.add_argument("--held-out", type=int, default=20, help="percent held out")
    p.add_argument("--jobs", type=int, default=1)
    p.add_argument("--dune-jobs", type=int, help="dune's -j in each copy")
    p.add_argument("--timeout", type=int, help="seconds per suite; default 3x the unmutated one per job")
    p.add_argument("--json", help="append each result to this file, a line each, for --report")
    p.add_argument("--list", action="store_true", help="print the mutants and stop")
    p.add_argument("--report", nargs="+", help="score the --json files of every shard")
    args = p.parse_args()
    if args.report:
        lines = [json.loads(line) for f in args.report for line in Path(f).read_text().splitlines()]
        heads = [line for line in lines if "planned" in line]
        seen = {h["shard"] for h in heads}
        wanted = {f"{i}/{n}" for n in {int(s.split("/")[1]) for s in seen} for i in range(n)}
        if not heads or seen != wanted:
            print(f"no results from shards {' '.join(sorted(wanted - seen)) or 'at all'}")
        code = report([line for line in lines if "result" in line], sum(h["planned"] for h in heads))
        sys.exit(code or (0 if heads and seen == wanted else 1))
    files = args.file or SCOPES[args.scope]["files"]
    shard, shards = map(int, args.shard.split("/"))
    todo = plan(args.scope, files, args.seed, args.held_out)
    todo = [m for m in todo if not args.operator or m["operator"] in args.operator]
    todo = [m for m in todo if not args.id or m["id"] in args.id]
    # a mistyped id would leave a run of nothing, which passes
    if missing := set(args.id or []) - {m["id"] for m in todo}:
        sys.exit(f"no mutant {' '.join(sorted(missing))} in this scope")
    todo = todo[shard::shards]
    if args.list:
        for m in todo:
            tag = " held out" if m["held_out"] else ""
            print(f"{m['id']}{tag} {m['operator']} at {m['file']}:{m['line']}\n    - {m['text']}\n    + {m['after']}")
        for file in files:
            print(f"{file}: {sum(1 for m in todo if m['file'] == file)} mutants")
        print(f"total: {len(todo)} mutants, {sum(1 for m in todo if m['held_out'])} held out")
        return
    root = Path(__file__).resolve().parent.parent
    work = root / "_mutation"
    out = Path(args.json).open("a") if args.json else None
    lock = threading.Lock()
    copies = Queue()
    timeout = args.timeout

    def run(m):
        copy = copies.get()
        start = time.monotonic()
        original = (copy / m["file"]).read_text()
        try:
            (copy / m["file"]).write_text(m["mutated"])
            result, by = verdict(copy, m["file"], args.dune_jobs, timeout)
        finally:
            (copy / m["file"]).write_text(original)
            copies.put(copy)
        row = {k: v for k, v in m.items() if k != "mutated"}
        row |= {"result": result, "by": by, "seconds": round(time.monotonic() - start)}
        with lock:
            print(f"{result:9} {m['operator']} at {m['file']}:{m['line']} [{m['id']}]", flush=True)
            if out:
                out.write(json.dumps(row) + "\n")
                out.flush()
        return row

    try:
        # results land as they come, so a shard cut short still reports what it ran
        if out:
            out.write(json.dumps({"scope": args.scope, "shard": args.shard, "seed": args.seed,
                                  "planned": len(todo)}) + "\n")
            out.flush()
        (work / "0").mkdir(parents=True)
        for item in COPIED:
            (work / "0" / item).parent.mkdir(parents=True, exist_ok=True)
            if (root / item).is_dir():
                shutil.copytree(root / item, work / "0" / item, ignore=SKIPPED)
            else:
                shutil.copy(root / item, work / "0" / item)
        # a copy that cannot build or elaborate the design would count every mutant invalid
        elaborate = sorted({tuple(a) for m in todo for a in ELABORATE.get(m["file"], [])})
        commands = [["exec", "--", "./bin/generate.exe", *a] for a in elaborate]
        for command in [["build", "./bin/generate.exe"]] + commands:
            if dune(work / "0", *command, jobs=args.dune_jobs)[0] != 0:
                sys.exit(f"the unmutated copy fails dune {' '.join(command)}")
        start = time.monotonic()
        code, err = dune(work / "0", "build", "@runtest", jobs=args.dune_jobs)
        if code != 0:
            sys.exit("the unmutated suite fails\n" + err[-4000:])
        # suites run side by side share the cores
        timeout = timeout or 3 * args.jobs * round(time.monotonic() - start)
        print(f"the unmutated suite passes in {round(time.monotonic() - start)} s;"
              f" {len(todo)} mutants, {timeout} s each at most", flush=True)
        for n in range(args.jobs):
            if n > 0:
                shutil.copytree(work / "0", work / str(n), symlinks=True)
            copies.put(work / str(n))
        with ThreadPoolExecutor(args.jobs) as pool:
            results = list(pool.map(run, todo))
    finally:
        shutil.rmtree(work, ignore_errors=True)
    code = report(results, len(todo))
    # a shard's survivors are judged at --report, beside every other shard's
    sys.exit(0 if args.json else code)


if __name__ == "__main__":
    main()
