# SPDX-License-Identifier: Apache-2.0
# Mutation score of the OCaml tests: one textual mutation at a time, in copies under
# _mutation/. A survivor not in test/mutation_allow.txt exits 1.
# Usage: python3 test/mutate.py [--scope engine|wide] [--file F ...] [--operator NAME ...]
#        [--id ID ...] [--jobs N] [--timeout S] [--list]
import argparse
import hashlib
import os
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from queue import Queue

ALLOW = Path(__file__).with_name("mutation_allow.txt")
COPIED = ["src", "test", "bin", "ppx", "python", "formal/Makefile", "dune-project", ".ocamlformat"]
SKIPPED = shutil.ignore_patterns("sim_build", "__pycache__", "*.fst", "*.vcd", "*.xml", "*.v", "*.json")

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



def plan(scope, files):
    todo, count = [], {}
    root = Path(__file__).resolve().parent.parent
    for file in files:
        for m in mutants(scope, file, (root / file).read_text()):
            key = "\0".join([m["file"], m["operator"], m["text"]])
            count[key] = count.get(key, -1) + 1
            m["id"] = hashlib.sha256(f"{key}\0{count[key]}".encode()).hexdigest()[:8]
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


def verdict(cwd, file, jobs, timeout):
    # a mutant that does not compile, or that Hardcaml refuses to elaborate, is not a mutant
    if dune(cwd, "build", "./bin/generate.exe", jobs=jobs)[0] != 0:
        return "invalid"
    for args in ELABORATE.get(file, []):
        if dune(cwd, "exec", "--", "./bin/generate.exe", *args, jobs=jobs)[0] != 0:
            return "invalid"
    try:
        return "survived" if dune(cwd, "build", "@runtest", jobs=jobs, timeout=timeout)[0] == 0 else "killed"
    except subprocess.TimeoutExpired:
        return "timeout"


def read_allowed():
    allowed = {}
    for entry in ALLOW.read_text().splitlines():
        if entry and not entry.startswith("#"):
            file, name, text, reason = [field.strip() for field in entry.split(" ## ")]
            allowed[(file, name, text)] = reason
    return allowed


def report(results):
    # a timeout counts as killed, as the suite does not pass, and is listed apart
    allowed = read_allowed()
    valid = [r for r in results if r["result"] != "invalid"]
    files = list(dict.fromkeys(r["file"] for r in results))
    for file in files + ["total"]:
        rows = [r for r in valid if file in (r["file"], "total")]
        killed = sum(1 for r in rows if r["result"] != "survived")
        timeouts = sum(1 for r in rows if r["result"] == "timeout")
        invalid = sum(1 for r in results if file in (r["file"], "total") and r["result"] == "invalid")
        print(f"{file}: killed {killed} of {len(rows)} valid mutants"
              f" ({timeouts} timed out, {invalid} invalid)")
    unexpected = []
    for r in valid:
        if r["result"] in ("survived", "timeout"):
            reason = allowed.get((r["file"], r["operator"], r["text"]))
            if r["result"] == "survived" and reason is None:
                unexpected.append(r)
            print(f"{r['result']}: {r['operator']} at {r['file']}:{r['line']} [{r['id']}]:"
                  f" {reason or ('NOT ALLOWED' if r['result'] == 'survived' else 'counted killed')}"
                  f"\n    - {r['text']}\n    + {r['after']}")
    return 1 if unexpected else 0


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--scope", choices=SCOPES, default="engine")
    p.add_argument("--file", action="append", help="only these files of the scope")
    p.add_argument("--operator", action="append", help="only these operators")
    p.add_argument("--id", action="append", help="only these mutants, as --list names them")
    p.add_argument("--jobs", type=int, default=1)
    p.add_argument("--dune-jobs", type=int, help="dune's -j in each copy")
    p.add_argument("--timeout", type=int, help="seconds per suite; default 3x the unmutated one")
    p.add_argument("--list", action="store_true", help="print the mutants and stop")
    args = p.parse_args()
    files = args.file or SCOPES[args.scope]["files"]
    todo = plan(args.scope, files)
    todo = [m for m in todo if not args.operator or m["operator"] in args.operator]
    todo = [m for m in todo if not args.id or m["id"] in args.id]
    if args.list:
        for m in todo:
            print(f"{m['id']} {m['operator']} at {m['file']}:{m['line']}\n    - {m['text']}\n    + {m['after']}")
        for file in files:
            print(f"{file}: {sum(1 for m in todo if m['file'] == file)} mutants")
        print(f"total: {len(todo)} mutants")
        return
    root = Path(__file__).resolve().parent.parent
    work = root / "_mutation"
    copies = Queue()
    timeout = args.timeout

    def run(m):
        copy = copies.get()
        original = (copy / m["file"]).read_text()
        try:
            (copy / m["file"]).write_text(m["mutated"])
            result = verdict(copy, m["file"], args.dune_jobs, timeout)
        finally:
            (copy / m["file"]).write_text(original)
            copies.put(copy)
        print(f"{result:9} {m['operator']} at {m['file']}:{m['line']} [{m['id']}]", flush=True)
        return {k: v for k, v in m.items() if k != "mutated"} | {"result": result}

    try:
        (work / "0").mkdir(parents=True)
        for item in COPIED:
            (work / "0" / item).parent.mkdir(parents=True, exist_ok=True)
            if (root / item).is_dir():
                shutil.copytree(root / item, work / "0" / item, ignore=SKIPPED)
            else:
                shutil.copy(root / item, work / "0" / item)
        start = time.monotonic()
        code, err = dune(work / "0", "build", "@runtest", jobs=args.dune_jobs)
        if code != 0:
            sys.exit("the unmutated suite fails\n" + err[-4000:])
        timeout = timeout or 3 * round(time.monotonic() - start)
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
    sys.exit(report(results))


if __name__ == "__main__":
    main()
