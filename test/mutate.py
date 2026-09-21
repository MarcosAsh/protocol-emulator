# SPDX-License-Identifier: Apache-2.0
# Mutation score of the OCaml test suite: apply one textual mutation to a source file at
# a time, run the tests, count the mutants that a test kills.
# Usage: python3 test/mutate.py [--file src/pins.ml ...] [--operator NAME ...]
#        [--max-per-operator N] [--jobs N]
# The mutants are made in copies of the repository under _mutation/, which dune ignores,
# so the checkout itself is never touched. A mutant that survives and is not listed in
# test/mutation_allow.txt makes the exit code 1.
import argparse
import re
import shutil
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from queue import Queue

FILES = ["src/engine.ml", "src/decoder.ml", "src/pins.ml", "src/host_port.ml"]
ALLOW = Path(__file__).with_name("mutation_allow.txt")
COPIED = ["src", "test", "bin", "dune-project", ".ocamlformat"]
SKIPPED = shutil.ignore_patterns("sim_build", "__pycache__", "*.fst", "*.vcd", "*.xml", "*.v", "*.json")

OPERATORS = [
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


def mutants(file, source, max_per_operator):
    lines = source.split("\n")
    for name, pattern, replacement in OPERATORS:
        for m in list(re.finditer(pattern, source))[:max_per_operator]:
            line = source.count("\n", 0, m.start()) + 1
            new = replacement(m) if callable(replacement) else m.expand(replacement)
            mutated = source[: m.start()] + new + source[m.end():]
            yield (file, name, line, lines[line - 1].strip(), mutated)


def dune(cwd, *args):
    return subprocess.run(["dune", *args, "--root", "."], cwd=cwd, capture_output=True, text=True)


def verdict(cwd):
    # a mutant that does not compile, or that Hardcaml refuses to elaborate, is not a mutant
    if dune(cwd, "build", "./bin/generate.exe").returncode != 0:
        return "invalid"
    if dune(cwd, "exec", "./bin/generate.exe", "top").returncode != 0:
        return "invalid"
    return "survived" if dune(cwd, "build", "@runtest").returncode == 0 else "killed"


def read_allowed():
    allowed = {}
    for entry in ALLOW.read_text().splitlines():
        if entry and not entry.startswith("#"):
            file, name, text, reason = [field.strip() for field in entry.split(" ## ")]
            allowed[(file, name, text)] = reason
    return allowed


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--file", action="append", help="default: " + " ".join(FILES))
    p.add_argument("--operator", action="append", help="only these operators")
    p.add_argument("--max-per-operator", type=int, default=5)
    p.add_argument("--jobs", type=int, default=1)
    args = p.parse_args()
    files = args.file or FILES
    root = Path(__file__).resolve().parent.parent
    work = root / "_mutation"
    allowed = read_allowed()
    copies = Queue()

    def run(mutant):
        file, name, line, text, mutated = mutant
        copy = copies.get()
        try:
            original = (copy / file).read_text()
            (copy / file).write_text(mutated)
            result = verdict(copy)
            (copy / file).write_text(original)
        finally:
            copies.put(copy)
        print(f"{result:9} {name} at {file}:{line}", flush=True)
        return (file, name, line, text, result)

    try:
        (work / "0").mkdir(parents=True)
        for item in COPIED:
            if (root / item).is_dir():
                shutil.copytree(root / item, work / "0" / item, ignore=SKIPPED)
            else:
                shutil.copy(root / item, work / "0" / item)
        if dune(work / "0", "build", "@runtest").returncode != 0:
            sys.exit("the unmutated suite fails")
        for n in range(args.jobs):
            if n > 0:
                shutil.copytree(work / "0", work / str(n), symlinks=True)
            copies.put(work / str(n))
        todo = [m for f in files for m in mutants(f, (root / f).read_text(), args.max_per_operator)]
        todo = [m for m in todo if not args.operator or m[1] in args.operator]
        with ThreadPoolExecutor(args.jobs) as pool:
            results = list(pool.map(run, todo))
    finally:
        shutil.rmtree(work, ignore_errors=True)

    unexpected = []
    for file in files + ["total"]:
        rows = [r for r in results if file in (r[0], "total") and r[4] != "invalid"]
        killed = sum(1 for r in rows if r[4] == "killed")
        print(f"{file}: killed {killed} of {len(rows)} valid mutants")
    for file, name, line, text, result in results:
        if result == "survived":
            reason = allowed.get((file, name, text))
            print(f"survived: {name} at {file}:{line}: {reason or 'NOT ALLOWED'}\n    {text}")
            if reason is None:
                unexpected.append((file, line))
    sys.exit(1 if unexpected else 0)


if __name__ == "__main__":
    main()
