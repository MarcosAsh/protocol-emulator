# SPDX-License-Identifier: Apache-2.0
# Mutation score of the OCaml tests: one textual mutation at a time, in copies under
# _mutation/. A survivor not in test/mutation_allow.txt exits 1, at --report with --json.
# --prove takes each survivor of the trusted checker to the proofs (prove() below), and
# --prove-only every mutant, without the tests.
# Usage: python3 test/mutate.py [--scope engine|wide|kernel] [--file F ...] [--operator NAME ...]
#        [--id ID ...] [--shard I/N] [--seed S] [--jobs N] [--timeout S] [--json OUT] [--list]
#        [--prove | --prove-only] [--proof-timeout S] [--proofs NAME ...]
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
# file ## operator ## line ## formula ## why it holds: the inputs where a survivor of the
# checker is compared with the original, for one that differs only outside them
ASSUME = Path(__file__).with_name("mutation_assume.txt")
# test_provenance prints the byte and name counts of the chip's verilog, which a mutant of
# the chip changes whether or not it changes behaviour, so the mutants run without it; the
# committed verilog is still copied, as test/dune depends on it
COPIED = ["src", "test", "bin", "ppx", "python", "pio", "formal/Makefile", "dune-project", ".ocamlformat",
          "demo/paths.py", "demo/outline.py", "demo/draw.py", "demo/kernel_vs_board.py",
          "demo/glitch_map.py", "demo/clock_sweep.py", "demo/corpus_draw.py",
          "demo/corpus_decoders.tsv", "demo/extract.py", "pages/die/die.bin", "test/paths/cells.json",
          "test/python/corpus_beacon_33000000.json", "src/protocol_emulator.v", "icepi/Makefile"]
# json the tests read, which SKIPPED drops from the test/ copy above
COPIED_JSON = ["test/diagrams", "test/lab"]
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
    "src/isa.ml", "src/program_config.ml",
]
# the files the chip does not instantiate, each with the generators that elaborate it alone;
# the kernel's step is in both of its circuits, its table in neither
KERNEL = [["kernel"], ["kernel-accepts"]]
APART = {
    "src/kernel.ml": KERNEL,
    "src/kernel_types.ml": KERNEL,
    "src/kernel_step.ml": KERNEL,
    "src/kernel_accepts.ml": [["kernel-accepts"]],
    "src/kernel_table.ml": [],
    "src/osr_kernel.ml": [["osr"]],
    "src/manchester_rx.ml": [
        ["manchester-rx"],
        ["manchester-rx", "-samples-per-bit", "8", "-samples-per-cycle", "2", "-gain-shift", "3"],
    ],
}
ELABORATE = {f: CHIP for f in RTL} | APART
# engine is the published score's four files, five mutants an operator each; wide is
# every file that makes RTL, the kernel and the analyser, every match
SCOPES = {
    "engine": {
        "files": ["src/engine.ml", "src/decoder.ml", "src/pins.ml", "src/host_port.ml"],
        "operators": lambda file: HARDWARE,
        "max_per_operator": 5,
    },
    "wide": {
        "files": RTL + list(APART) + ["src/analyser.ml", "src/interval.ml"],
        "operators": lambda file: (
            SOFTWARE if file in ["src/analyser.ml", "src/interval.ml"]
            else HARDWARE + MORE_HARDWARE + SOFTWARE),
        "max_per_operator": None,
    },
    "kernel": {
        "files": [
            "src/kernel.ml", "src/kernel_types.ml", "src/kernel_step.ml", "src/kernel_accepts.ml",
            "src/kernel_table.ml", "src/osr_kernel.ml"],
        "operators": lambda file: HARDWARE + MORE_HARDWARE + SOFTWARE,
        "max_per_operator": None,
    },
}

# The trusted checker: the generator of its check of a row, as Kernel.check and
# Osr_kernel.check decide it, the outputs that must match and the groups whose and
# accepts; the lines where it is software the gates leave out; and the proofs, fastest
# first, a mutant that accepts more must pass: an sby run each, or one a task of a task list
# of formal/Makefile, those of the second list, the slowest, last.
KERNEL_PROVED = {
    "check": ["check-gates"],
    "equal": ["next_pc", "target_pc"],
    "accept": ["conjunct$", "starts_open", "interval"],
    "outside": [],
    "lemma": "test_kernel.ml",
    "verilog": ["engine.v", "kernel_step.v", "kernel_accepts.v"],
    "proofs": [
        ("phase_step", ["phase_step.sby", "prove"]),
        ("phase_table", ["phase_table.sby", "prove"]),
        ("row_step", ["row_step.sby", "jmp", "wait", "in", "out", "mov", "set", "alu_x", "alu_y", "alu_p",
          "alu_t", "sys"]),
        ("phase_table_affine", ["phase_table_affine.sby", "prove"]),
        ("phase_spacing", ["phase_spacing.sby", "prove"]),
        ("pair_step", ["pair_step.sby"], "PAIR_STEP_TASKS", "PAIR_STEP_ALONE"),
    ],
}

# the files that make the kernel's check: its software outside the gates is what only a test kills
PROVED = {
    "src/kernel.ml": KERNEL_PROVED,
    "src/kernel_types.ml": KERNEL_PROVED | {"outside": [(r"^  let of_spec", r"^end")]},
    "src/kernel_step.ml": KERNEL_PROVED,
    "src/kernel_accepts.ml": KERNEL_PROVED,
    "src/kernel_table.ml": KERNEL_PROVED | {"outside": [(r"^  let verdicts", r"^end")]},
    "src/osr_kernel.ml": {
        "check": ["check-gates", "-osr"],
        "equal": [],
        "accept": ["conjunct$", "is_full"],
        "outside": [(r"^module Program = struct", r"^end"), (r"^let check", r"^module I = struct")],
        "lemma": "test_osr_kernel.ml",
        "verilog": ["engine.v", "osr_step.v"],
        "proofs": [("data_step", ["data_step.sby", "prove"])],
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


def makefile_tasks(root, name):
    # a task list of formal/Makefile, its lines continued with a backslash
    text = (root / "formal" / "Makefile").read_text().replace("\\\n", " ")
    return re.search(rf"^{name} = (.*)$", text, re.M).group(1).split()


def proof_runs(root, spec):
    # each sby run of a checker's proofs, by name
    runs = []
    for name, args, *lists in spec["proofs"]:
        if not lists:
            runs.append((name, args))
            continue
        tasks, slow = (makefile_tasks(root, n) for n in lists)
        for task in [t for t in tasks if t not in slow] + slow:
            runs.append((f"{name}:{task}", args + [task]))
    return runs


def outside(file, line):
    # a line of the checker's software that its gates leave out
    lines = (Path(__file__).resolve().parent.parent / file).read_text().split("\n")
    for start, end in PROVED[file]["outside"]:
        first = next(i for i, text in enumerate(lines) if re.match(start, text))
        last = next(i for i, text in enumerate(lines) if i > first and re.match(end, text))
        if first < line <= last + 1:
            return True
    return False


def read_assumed():
    assumed = {}
    for entry in ASSUME.read_text().splitlines():
        if entry and not entry.startswith("#"):
            file, name, text, formula, why = [field.strip() for field in entry.split(" ## ")]
            assumed[(file, name, text)] = formula, why
    return assumed


def run_logged(command, cwd, log, timeout):
    with open(log, "w") as out:
        p = subprocess.Popen(command, cwd=cwd, stdout=out, stderr=subprocess.STDOUT, text=True,
                             start_new_session=True)
        try:
            return p.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            os.killpg(p.pid, signal.SIGKILL)
            p.wait()
            return None


def prove(cwd, m, original, prover, timeout, proof_timeout, untested, only):
    # A survivor of the checker, by its gates against the original's: EQUIVALENT if its
    # decision is the same for every input, STRICT if it accepts only what the original
    # does, so the original's theorem holds of it, either under the formula of
    # test/mutation_assume.txt if any. Else it accepts more: LAX if the SAT lemma or a
    # proof then fails on it, the trace the counterexample, SOUND if every one holds, TESTED
    # if, untested before, a test of the lemma's file fails but every proof holds. OUTSIDE:
    # software of the checker the gates leave out, which only a test can kill.
    spec = PROVED[m["file"]]
    logs = cwd / "_prove"
    logs.mkdir(exist_ok=True)
    gates = logs / "mutant.aag"
    with open(gates, "w") as out:
        code = subprocess.run(["_build/default/bin/generate.exe", *spec["check"]], cwd=cwd,
                              stdout=out, stderr=subprocess.DEVNULL, timeout=timeout).returncode
    if code != 0:
        return {"class": "invalid", "evidence": ["check-gates fails"]}
    flags = [f for name in spec["equal"] for f in ["-equal", name]]
    flags += [f for name in spec["accept"] for f in ["-accept", name]]
    against = original / Path(m["file"]).with_suffix(".aag").name
    compare = [str(prover), "-original", str(against), "-mutant", str(gates), *flags]
    decided = None
    if against.read_bytes() == gates.read_bytes():
        decided, evidence = "EQUIVALENT", ["its check's gates are the original's, to the byte"]
    else:
        p = subprocess.run(compare, capture_output=True, text=True, timeout=proof_timeout)
        evidence = p.stdout.splitlines()
        assumed = read_assumed().get((m["file"], m["operator"], m["text"]))
        if p.returncode == 3 and assumed:
            p = subprocess.run(compare + ["-assume", assumed[0]], capture_output=True, text=True,
                               timeout=proof_timeout)
            evidence += [f"assume {assumed[0]}, as {assumed[1]}"] + p.stdout.splitlines()
        # rows of another width are another interface, which only the proofs can judge
        if p.returncode not in (0, 3) and "differ" not in p.stderr:
            return {"class": "unproved", "evidence": evidence + p.stderr.splitlines()[-20:]}
        evidence += [line for line in p.stderr.splitlines() if "differ" in line]
        if p.returncode == 0:
            decided = "STRICT" if "accepts only" in evidence[-1] else "EQUIVALENT"
    if decided:
        return {"class": "OUTSIDE" if outside(m["file"], m["line"]) else decided, "evidence": evidence}
    # it accepts more: the SAT lemma, then the proofs, each until one fails. A failed base
    # case is a run the mutant lets miss: LAX. A failed induction step is only unproved.
    log = logs / "lemma.log"
    tested = False
    if run_logged(["sh", "test/only.sh", spec["lemma"]], cwd, log, proof_timeout) != 0:
        # LAX only where a QED of the lemma's became a counterexample
        lines = log.read_text().splitlines()
        lost = {m.group(1) for line in lines if (m := re.match(r'^-.*\(QED "([^"]*)"', line))}
        lax = any(re.match(rf'^\+.*\(counterexample "{re.escape(name)}"', line) for line in lines
                  for name in lost)
        verdicts = [line for line in lines if re.match(r'^[-+ ].*\((QED|counterexample) "', line)]
        if lax:
            return {"class": "LAX", "evidence": evidence + [f"{spec['lemma']} fails:"] + verdicts + lines[-40:]}
        # untested, a test of the lemma's file that fails kills it, but the proofs still run
        if not untested:
            return {"class": "TESTED", "evidence": evidence + [f"{spec['lemma']} fails:"] + lines[-40:]}
        tested = True
        evidence += [f"{spec['lemma']} fails a test, its QEDs hold:"] + verdicts + lines[-40:]
    else:
        evidence.append(f"{spec['lemma']} holds")
    formal = cwd / "formal"
    if run_logged(["make", *spec["verilog"]], formal, logs / "verilog.log", timeout) != 0:
        return {"class": "invalid", "evidence": evidence + ["the proofs' verilog fails"]}
    runs = proof_runs(cwd, spec)
    picked = [(name, args) for name, args in runs if not only or name in only or name.split(":")[0] in only]
    for name, args in picked:
        code = run_logged(["sby", "-f", *args], formal, logs / f"{name}.log", proof_timeout)
        if code is None:
            return {"class": "unproved", "evidence": evidence + [f"{name} timed out"]}
        if code != 0:
            lines = (logs / f"{name}.log").read_text().splitlines()
            # the failed assertion and the counterexample's constants: the program, the rows
            failed = [line for line in lines if re.search(r"Assert failed|anyconst|summary", line)]
            lax = any("FAIL for basecase" in line or "returned FAIL" in line and "induction" not in line
                      for line in lines)
            return {"class": "LAX" if lax else "unproved", "evidence": evidence + [f"{name} fails:"] + failed[-60:]}
        evidence.append(f"{name} holds")
    skipped = [name for name, args in runs if (name, args) not in picked]
    if skipped:
        evidence.append(f"not run: {' '.join(skipped)}")
    return {"class": "TESTED" if tested else "unproved" if skipped else "SOUND", "evidence": evidence}


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


# a survivor's class from prove(): explained by a proof, or killed by one
PROVED_SAFE = ("EQUIVALENT", "STRICT", "SOUND")


def report(results, planned):
    # a timeout counts as killed, as the suite does not pass, and is listed apart; so does a
    # survivor a proof kills. An allowed mutant's timeout is no kill: an equivalent one runs
    # as the original does, until the timeout stops it.
    allowed = read_allowed()
    valid = [r for r in results if r["result"] != "invalid" and r.get("class") != "invalid"]
    order = SCOPES["wide"]["files"]
    files = sorted({r["file"] for r in results}, key=lambda f: (order.index(f) if f in order else len(order), f))

    def survives(r):
        timed_out_allowed = r["result"] == "timeout" and (r["file"], r["operator"], r["text"]) in allowed
        return (r["result"] in ("survived", "untested") or timed_out_allowed) and r.get(
            "class") not in ("LAX", "TESTED")

    print(f"ran {len(results)} of {planned} planned mutants")
    for file in files + ["total"]:
        rows = [r for r in valid if file in (r["file"], "total")]
        killed = sum(1 for r in rows if not survives(r))
        timeouts = sum(1 for r in rows if r["result"] == "timeout")
        invalid = sum(1 for r in results if file in (r["file"], "total") and r not in valid)
        print(f"{file}: killed {killed} of {len(rows)} valid mutants"
              f" ({timeouts} timed out, {invalid} invalid)")
    parts = [("all", [False, True])]
    if any(r["held_out"] for r in results):
        parts += [("in-sample", [False]), ("held-out", [True])]
    for label, held_out in parts:
        rows = [r for r in valid if r["held_out"] in held_out]
        killed = sum(1 for r in rows if not survives(r))
        print(f"{label}: killed {killed} of {len(rows)}, {wilson(killed, len(rows))} (Wilson 95%)")
    classed = [r for r in valid if "class" in r]
    if classed:
        counts = {}
        for r in classed:
            counts[r["class"]] = counts.get(r["class"], 0) + 1
        print("proved: " + ", ".join(f"{n} {c}" for c, n in sorted(counts.items())))
    unexpected = []
    for r in sorted(valid, key=lambda r: (r["held_out"], files.index(r["file"]), r["line"])):
        if r["result"] in ("survived", "untested", "timeout"):
            reason = allowed.get((r["file"], r["operator"], r["text"]))
            if "class" in r:
                reason = r["class"] + (f" ({reason})" if reason and r["class"] not in PROVED_SAFE else "")
            elif r["result"] == "timeout" and not reason:
                reason = "counted killed"
            if survives(r) and r.get("class") not in PROVED_SAFE and not allowed.get(
                    (r["file"], r["operator"], r["text"])):
                unexpected.append(r)
            tag = " held out" if r["held_out"] else ""
            print(f"{r['result']}: {r['operator']} at {r['file']}:{r['line']} [{r['id']}{tag}]:"
                  f" {reason or 'NOT ALLOWED'}\n    - {r['text']}\n    + {r['after']}")
            for line in r.get("evidence", []):
                print(f"    | {line if len(line) < 400 else line[:400] + ' ...'}")
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
    p.add_argument("--prove", action="store_true", help="take each survivor of the checker to the proofs")
    p.add_argument("--prove-only", action="store_true", help="take every mutant of the checker, untested")
    p.add_argument("--proof-timeout", type=int, default=4 * 3600, help="seconds per proof")
    p.add_argument("--proofs", nargs="+", help="only these of PROVED's sby proofs, by name")
    args = p.parse_args()
    proving = args.prove or args.prove_only
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
        proved = {}
        try:
            (copy / m["file"]).write_text(m["mutated"])
            if args.prove_only:
                built = dune(copy, "build", "./bin/generate.exe", jobs=args.dune_jobs, timeout=timeout)[0]
                result, by = ("untested" if built == 0 else "invalid"), []
            else:
                result, by = verdict(copy, m["file"], args.dune_jobs, timeout)
            if proving and m["file"] in PROVED and result in ("survived", "untested"):
                proved = prove(copy, m, work / "original", work / "prove_mutant.exe", timeout,
                               args.proof_timeout, args.prove_only, args.proofs)
        finally:
            (copy / m["file"]).write_text(original)
            copies.put(copy)
        row = {k: v for k, v in m.items() if k != "mutated"}
        row |= {"result": result, "by": by, "seconds": round(time.monotonic() - start)} | proved
        with lock:
            print(f"{result:9} {proved.get('class', ''):10} {m['operator']} at {m['file']}:{m['line']}"
                  f" [{m['id']}]", flush=True)
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
        for item in COPIED_JSON:
            shutil.copytree(root / item, work / "0" / item, dirs_exist_ok=True)
        if proving:
            # the proofs' files, and the original's check and the prover, made once
            tracked = subprocess.run(["git", "ls-files", "formal"], cwd=root, capture_output=True,
                                     text=True, check=True).stdout.split()
            for item in tracked:
                (work / "0" / item).parent.mkdir(parents=True, exist_ok=True)
                shutil.copy(root / item, work / "0" / item)
            command = ["build", "./bin/generate.exe", "./test/mutant/prove_mutant.exe"]
            if dune(work / "0", *command, jobs=args.dune_jobs)[0] != 0:
                sys.exit("the unmutated copy fails to build the prover")
            shutil.copy(work / "0/_build/default/test/mutant/prove_mutant.exe", work)
            (work / "original").mkdir()
            for file, spec in PROVED.items():
                gates = work / "original" / Path(file).with_suffix(".aag").name
                with open(gates, "w") as aag:
                    subprocess.run(["_build/default/bin/generate.exe", *spec["check"]], cwd=work / "0",
                                   stdout=aag, check=True)
                # teeth: the original equals itself, and with its first output's and gate
                # flipped it neither equals the original nor accepts only what it does
                flipped = gates.with_suffix(".flipped")
                with open(flipped, "w") as aag:
                    subprocess.run(["awk", "-f", "formal/kernel_equiv/flip.awk", str(gates)], cwd=root,
                                   stdout=aag, check=True)
                flags = [f for name in spec["equal"] for f in ["-equal", name]]
                flags += [f for name in spec["accept"] for f in ["-accept", name]]
                for mutant, code in [(gates, 0), (flipped, 3)]:
                    p = subprocess.run([str(work / "prove_mutant.exe"), "-original", str(gates), "-mutant",
                                        str(mutant), *flags], capture_output=True, text=True)
                    if p.returncode != code:
                        sys.exit(f"the prover on {mutant.name} exits {p.returncode}\n{p.stdout}{p.stderr}")
        # a copy that cannot build or elaborate the design would count every mutant invalid
        elaborate = sorted({tuple(a) for m in todo for a in ELABORATE.get(m["file"], [])})
        commands = [["exec", "--", "./bin/generate.exe", *a] for a in elaborate]
        for command in [["build", "./bin/generate.exe"]] + commands:
            if dune(work / "0", *command, jobs=args.dune_jobs)[0] != 0:
                sys.exit(f"the unmutated copy fails dune {' '.join(command)}")
        start = time.monotonic()
        if args.prove_only:
            timeout = timeout or 1800
        else:
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
