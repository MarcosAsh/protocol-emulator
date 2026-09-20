# SPDX-License-Identifier: Apache-2.0
# Mutation score of the OCaml test suite against the engine: apply one textual mutation
# to src/engine.ml at a time, run the tests, count the mutants that a test kills.
# Usage: python3 test/mutate.py [--max-per-operator N] from a repository copy.
import argparse
import re
import subprocess
import sys
from pathlib import Path

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
    ("shift direction", r"~f:srl", "~f:sll"),
    ("shift direction", r"~f:sll", "~f:srl"),
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
]


def mutants(source, max_per_operator):
    for name, pattern, replacement in OPERATORS:
        matches = list(re.finditer(pattern, source))[:max_per_operator]
        for m in matches:
            line = source.count("\n", 0, m.start()) + 1
            yield (name, line, source[: m.start()] + replacement + source[m.end():])


def run_tests(cwd):
    r = subprocess.run(
        ["dune", "build", "@runtest", "--force"], cwd=cwd, capture_output=True, text=True
    )
    if r.returncode == 0:
        return "survived"
    if "Error" in r.stderr and "[%expect" not in r.stderr and "MISMATCH" not in r.stderr:
        # a mutant that does not compile is not a mutant
        return "invalid"
    return "killed"


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--max-per-operator", type=int, default=4)
    args = p.parse_args()
    path = Path("src/engine.ml")
    original = path.read_text()
    results = []
    try:
        for name, line, mutated in mutants(original, args.max_per_operator):
            path.write_text(mutated)
            verdict = run_tests(".")
            results.append((name, line, verdict))
            print(f"{verdict:9} {name} at engine.ml:{line}", flush=True)
    finally:
        path.write_text(original)
    killed = sum(1 for _, _, v in results if v == "killed")
    valid = sum(1 for _, _, v in results if v != "invalid")
    print(f"killed {killed} of {valid} valid mutants")
    for name, line, v in results:
        if v == "survived":
            print(f"survived: {name} at engine.ml:{line}")


if __name__ == "__main__":
    main()
