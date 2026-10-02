# SPDX-License-Identifier: Apache-2.0
# Fails when README.md or docs/info.md cites a path, make target, CI job, commit or run
# that is not there, or quotes a count the code, the tests or the cited run disagree with.
# A reworded sentence a count is read from fails too, until this file learns the new one.
# Runs are looked up with gh, which --offline skips. --teeth makes wrong READMEs from the
# current one, a count, path, target, commit or run off by one each, and fails if any passes.
# Usage: python3 test/check_docs.py [--offline] [--teeth]
import argparse
import csv
import json
import re
import subprocess
import sys
import tempfile
import time
from functools import cache
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DOCS = ["README.md", "docs/info.md"]
REPO = "MarcosAsh/protocol-emulator"
ONLINE = True

# cited for the reader to make: tt-support-tools is cloned into tt/
NOT_IN_REPO = ("tt/",)

# what a gds run hardens, as gds.yaml's paths filter has it
HARDENED = ["src", "macro", "info.yaml", "librelane_plugin_sram_pdn.py", "odb_sram_stripes.py",
            ":!*.ml", ":!*.mli", ":!**/dune"]

EXTENSIONS = "ml|mli|sv|v|sby|py|asm|hex|txt|tcl|yaml|svg|png|md|json|settings|lpf|mk"
PATH = re.compile(rf"(?<![\w./-])((?:[\w.-]+/)+[\w.-]+\.(?:{EXTENSIONS}))(?!\.?[\w/-])")
DIRECTORY = re.compile(r"`((?:[\w.-]+/)+)`")
URL = re.compile(r"https?://[^\s)]+")
MAKE = re.compile(r"make -C ([\w./-]+)([^`#\n]*)")
JOB = re.compile(r"`([\w-]+)` job")
BADGE = re.compile(r"actions/workflows/([\w.-]+)/badge\.svg")
# a run id is all digits and longer, a word such as "defaced" has no digit
COMMIT = re.compile(r"(?<![\w/#.-])(?=[0-9a-f]*\d)([0-9a-f]{7,8}|(?=[0-9]*[a-f])[0-9a-f]{9,12})"
                    r"(?![\w.-])")
RUN = re.compile(r"(?<![\d.])(\d{10,12})(?![\d.])")
DATED_RUN = re.compile(r"run \[?(\d{10,12})\]?(?:\([^)]*\))?, (\d{4}-\d\d-\d\d)")


def git(*args):
    return subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True)


def gh(*args):
    """gh's output, or None when GitHub has no such thing, or no longer has it."""
    # the API drops the odd request, so try again before giving up
    for attempt in range(4):
        done = subprocess.run(["gh", *args], capture_output=True, text=True)
        if done.returncode == 0:
            return done.stdout
        if "HTTP 404" in done.stderr or "HTTP 410" in done.stderr:
            return None
        time.sleep(2 ** attempt)
    sys.exit(f"gh {' '.join(args)}: {done.stderr.strip()}")


# What the repo and CI say

def read(path):
    return (ROOT / path).read_text()


def tiles():
    m = re.search(r'^\s*tiles:\s*"(\d+)x(\d+)"', read("info.yaml"), re.M)
    return f"{m[1]} x {m[2]}"


def clock_mhz():
    return int(re.search(r"^\s*clock_hz:\s*(\d+)", read("info.yaml"), re.M)[1]) // 1_000_000


def pdk():
    return re.search(r"pdk: ihp-(\w+)", read(".github/workflows/gds.yaml"))[1].upper()


def pinout():
    """How many pins info.yaml gives the host, and inputs, outputs and bidirectional IO."""
    names = re.findall(r'^\s*u(?:i|o|io)\[\d\]:\s*"([^"]*)"', read("info.yaml"), re.M)
    kinds = {"host": r"host ", "in": r"IN\d", "out": r"OUT\d", "bidirectional": r"IO\d"}
    return {k: sum(1 for n in names if re.match(p, n)) for k, p in kinds.items()}


def isa(name):
    return int(re.search(rf"^let {name} = (\d+)$", read("src/isa.ml"), re.M)[1])


@cache
def instances():
    """How many of each module the generated chip holds, counted down from its top."""
    children = {}
    for module in re.split(r"^module ", read("src/protocol_emulator.v"), flags=re.M)[1:]:
        # Hardcaml writes an instance as its module, its name, then its ports
        children[re.match(r"\w+", module)[0]] = re.findall(
            r"^    (\w+)\n        \w+\n        \( \.", module, re.M)

    def count(module):
        total = {module: 1}
        for child in children.get(module, []):
            for name, n in count(child).items():
                total[name] = total.get(name, 0) + n
        return total

    return count("protocol_emulator")


def sram():
    """How many SRAM macros the chip holds, and their words and bits."""
    name = next(n for n in instances() if n.startswith("RM_IHPSG13_1P_"))
    words, bits = re.search(r"_(\d+)x(\d+)_", name).groups()
    return instances()[name], int(words), int(bits)


def library_firmwares():
    """The firmwares test_certified.ml's table accepts, which dune runtest keeps current."""
    test = read("test/test_certified.ml").split(
        'let%expect_test "the firmware library and its certificates"')[1]
    rows = test.split("[%expect {|")[1].split("|}]")[0].strip().splitlines()[1:]
    return [row.split()[0] for row in rows if "refused" not in row]


def equivalent_mutants():
    lines = read("test/mutation_allow.txt").splitlines()
    return sum(1 for line in lines if line.strip() and not line.startswith("#"))


@cache
def make_targets(directory):
    """Every target a rule names in [directory]'s Makefile or a file it includes."""
    targets, files = set(), [ROOT / directory / "Makefile"]
    while files:
        for line in files.pop().read_text().replace("\\\n", " ").splitlines():
            if m := re.match(r"-?include\s+([\w./-]+)\s*$", line):
                files.append(ROOT / directory / m[1])
            elif m := re.match(r"([^\t#=:][^#=:]*?)::?(?!=)(.*)", line):
                targets.update(m[1].split())
                if m[1].strip() == ".PHONY":
                    targets.update(m[2].split())
    return targets


@cache
def workflow_jobs():
    jobs = set()
    for workflow in (ROOT / ".github/workflows").glob("*.yaml"):
        body = workflow.read_text().split("\njobs:\n", 1)[1]
        jobs.update(re.findall(r"^  ([\w-]+):", body, re.M))
    return jobs


@cache
def not_ours(commit):
    """Why HEAD does not descend from [commit], or None if it does."""
    full = git("rev-parse", "--verify", "--quiet", f"{commit}^{{commit}}").stdout.strip()
    if not full:
        return "is not a commit"
    if git("merge-base", "--is-ancestor", full, "HEAD").returncode != 0:
        return "is not an ancestor of HEAD"
    return None


@cache
def run(run_id):
    out = gh("api", f"repos/{REPO}/actions/runs/{run_id}")
    return json.loads(out) if out else None


@cache
def gds_metrics(run_id):
    """The metrics.csv row gds.yaml uploads, or None once the artifact has expired."""
    with tempfile.TemporaryDirectory() as tmp:
        done = subprocess.run(["gh", "run", "download", run_id, "-R", REPO, "-n", "metrics",
                               "-D", tmp], capture_output=True, text=True)
        if done.returncode != 0:
            return None
        with open(Path(tmp) / "metrics.csv") as f:
            return next(csv.DictReader(f))


@cache
def mutation_score(run_id):
    """(killed, valid) from the run's log, or None once the log has expired."""
    jobs = json.loads(gh("api", f"repos/{REPO}/actions/runs/{run_id}/jobs") or '{"jobs": []}')
    for job in jobs["jobs"]:
        log = gh("api", f"repos/{REPO}/actions/jobs/{job['id']}/logs") or ""
        if m := re.search(r"total: killed (\d+) of (\d+) valid mutants", log):
            return int(m[1]), int(m[2])
    return None


# What the docs say

def flat(text):
    """[text] on one line, so a sentence reads the same however it wraps."""
    return " ".join(text.split())


def units(text):
    """Paragraphs and table rows, the span a number shares with the run it came from."""
    for block in re.split(r"\n\s*\n", text):
        if block.lstrip().startswith("|"):
            yield from block.splitlines()
        else:
            yield flat(block)


def glance(text):
    """The first table in the README, as {label: the rest of its row}."""
    table = next((u for u in re.split(r"\n\s*\n", text) if u.startswith("|")), "")
    rows = [[c.strip() for c in row.strip("|").split("|")] for row in table.splitlines()[2:]]
    return {cells[0]: " | ".join(cells[1:]) for cells in rows}


def numbers(pattern, text):
    return [int(n.replace(",", "")) for n in re.findall(pattern, text)]


# The checks, each yielding what is wrong

def check_paths(doc, text):
    for path in sorted(set(PATH.findall(URL.sub(" ", text)) + DIRECTORY.findall(text))):
        if not path.startswith(NOT_IN_REPO) and not (ROOT / path).exists():
            yield f"{path} does not exist"
    for workflow in BADGE.findall(text):
        if not (ROOT / ".github/workflows" / workflow).exists():
            yield f"the badge's workflow {workflow} does not exist"


def check_make(doc, text):
    for directory, args in MAKE.findall(text):
        if not (ROOT / directory / "Makefile").exists():
            yield f"make -C {directory}: there is no {directory}/Makefile"
            continue
        for target in args.split():
            if "=" not in target and not target.startswith("-"):
                if target not in make_targets(directory):
                    yield f"make -C {directory} {target}: no such target"


def check_jobs(doc, text):
    for job in sorted(set(JOB.findall(flat(text)))):
        if job not in workflow_jobs():
            yield f"no workflow has a `{job}` job"


def check_commits(doc, text):
    if git("rev-parse", "--is-shallow-repository").stdout.strip() != "false":
        yield "a shallow clone cannot place commits, check out with fetch-depth: 0"
        return
    for commit in sorted(set(COMMIT.findall(URL.sub(" ", text)))):
        if why := not_ours(commit):
            yield f"commit {commit} {why}"


def check_runs(doc, text):
    for run_id in sorted(set(RUN.findall(text))):
        r = run(run_id)
        if r is None:
            yield f"run {run_id} does not exist in {REPO}"
        elif r["conclusion"] != "success":
            yield f"run {run_id} ({r['name']}) concluded {r['conclusion']}"
        elif why := not_ours(r["head_sha"]):
            yield f"run {run_id} ran {r['head_sha'][:7]}, which {why}"
    for run_id, date in DATED_RUN.findall(flat(text)):
        r = run(run_id)
        if r and r["created_at"][:10] != date:
            yield f"run {run_id} is dated {date} but ran on {r['created_at'][:10]}"


def check_gds(doc, text):
    """Numbers beside a gds run are that run's, and it hardened the chip as it is now."""
    for unit in units(text):
        runs = set(re.findall(r"[Gg]ds run \[?(\d{10,12})", unit))
        if len(runs) > 1:
            yield f"gds runs {', '.join(sorted(runs))} in one place, whose numbers are whose?"
        if len(runs) != 1:
            continue
        run_id = runs.pop()
        if not run(run_id):
            continue  # check_runs says so
        metrics = gds_metrics(run_id)
        if metrics is None:
            yield f"gds run {run_id} has no metrics artifact left, cite a newer gds run"
            continue
        sha = run(run_id)["head_sha"]
        if git("diff", "--quiet", sha, "HEAD", "--", *HARDENED).returncode != 0:
            yield f"gds run {run_id} hardened {sha[:7]}, and the chip has changed since"
        quoted = {
            "setup_slow_ns": re.findall(r"([+-]\d+\.\d+) ns at the slow corner", unit),
            "utilisation": [float(u) / 100 for u in re.findall(r"([\d.]+)% utilisation", unit)],
            "std_cells": numbers(r"([\d,]+) (?:standard )?cells", unit),
        }
        for key, values in quoted.items():
            for value in values:
                if abs(float(value) - float(metrics[key])) > 1e-9:
                    yield f"gds run {run_id} has {key} {metrics[key]}, the docs say {value}"


def check_mutation(doc, text):
    """A mutation score beside a mutation run is that run's."""
    for unit in units(text):
        for run_id in re.findall(r"mutation run \[?(\d{10,12})", unit):
            if not run(run_id):
                continue
            score = mutation_score(run_id)
            if score is None:
                yield f"mutation run {run_id} has no log left, cite a newer mutation run"
                continue
            for quoted in re.findall(r"(\d+) of (\d+) valid mutants", unit):
                if tuple(map(int, quoted)) != score:
                    yield (f"mutation run {run_id} killed {score[0]} of {score[1]}, "
                           f"the docs say {quoted[0]} of {quoted[1]}")


def check_counts(doc, text):
    """Counts the code and the tests hold, wherever the docs quote them."""
    text = flat(text)
    quoted = {
        "library firmwares": numbers(r"(\d+) library firmwares", text),
        "valid mutants": re.findall(r"(\d+) of (\d+) valid mutants", text),
        "equivalent mutants": numbers(r"other (\d+) are equivalent", text),
        "tiles": re.findall(r"(\d+ x \d+) tiles", text),
    }
    if doc == "README.md":
        for what, values in quoted.items():
            if not values:
                yield f"nothing quotes the {what}, if it was reworded update test/check_docs.py"
    firmwares = len(library_firmwares())
    for n in quoted["library firmwares"]:
        if n != firmwares:
            yield f"{n} library firmwares, test/test_certified.ml has {firmwares} accepted"
    for killed, valid in quoted["valid mutants"]:
        for n in quoted["equivalent mutants"]:
            if n != int(valid) - int(killed) or n != equivalent_mutants():
                yield (f"{n} equivalent mutants, but {killed} of {valid} killed leaves "
                       f"{int(valid) - int(killed)} and test/mutation_allow.txt has "
                       f"{equivalent_mutants()}")
    for n in quoted["tiles"]:
        if n != tiles():
            yield f"{n} tiles, info.yaml has {tiles()}"
    for n in numbers(r"tiles at (\d+) MHz", text):
        if n != clock_mhz():
            yield f"{n} MHz, info.yaml has {clock_mhz()}"
    for n in numbers(r"(\d+)-bit (?:clock|free-running counter)", text):
        if n != isa("timer_bits"):
            yield f"a {n}-bit clock, src/isa.ml has timer_bits = {isa('timer_bits')}"
    for n in numbers(r"(\d+)-word IHP", text):
        if n != sram()[1]:
            yield f"a {n}-word macro, the chip's are {sram()[1]} words"
    depth = int(re.search(r"^let depth = (\d+)$", read("src/host_fifo.ml"), re.M)[1])
    for n in numbers(r"(\d+)-deep fifos", text):
        if n != depth:
            yield f"{n}-deep fifos, src/host_fifo.ml has depth = {depth}"


def check_transcripts(doc, text):
    """What a transcript shows the assembler print, a test in test/assemble/ diffs
    against what it does print, after the same edit."""
    printed = {line for f in (ROOT / "test/assemble").glob("*.expected")
               for line in f.read_text().splitlines()}
    for block in re.findall(r"^```\n(.*?)^```", text, re.M | re.S):
        if "bin/generate.exe assemble" not in block:
            continue
        for line in block.splitlines():
            if m := re.match(r"\$ sed '([^']*)'", line):
                if f'"{m[1]}"' not in read("test/assemble/dune"):
                    yield f"no rule in test/assemble/dune makes the edit {m[1]}"
            elif not line.startswith("$ ") and line != "..." and line not in printed:
                yield f"no test in test/assemble/ prints {line.strip()!r}"


def check_glance(doc, text):
    """The table at the top of the README, against where each number comes from."""
    if doc != "README.md":
        return
    table, body = glance(text), flat(text)
    count, words, bits = sram()
    pins = pinout()
    listed = re.search(r"library firmwares \(([^)]*)\)", body)
    bench = re.search(r"demo_self_timing\.py` passed on (\d{4}-\d\d-\d\d)", body)
    silicon = "no silicon yet" if "Nothing has run on silicon yet" in body else "silicon"
    rows = {
        "Process": [("tiles", r"(\d+ x \d+) tiles", tiles()),
                    ("process", r"IHP (\w+)", pdk())],
        "Clock": [("clock", r"(\d+) MHz", str(clock_mhz()))],
        "Cores": [("cores", r"(\d+) cores", str(instances().get("engine"))),
                  ("SRAM macros", r"(\d+) IHP", str(count)),
                  ("SRAM shape", r"IHP (\d+ x \d+)", f"{words} x {bits}")],
        "Pins": [("host pins", r"(\d+) for the host", str(pins["host"])),
                 ("inputs", r"(\d+) in,", str(pins["in"])),
                 ("outputs", r"(\d+) out,", str(pins["out"])),
                 ("bidirectional pins", r"(\d+) bidirectional", str(pins["bidirectional"])),
                 ("wires", r"(\d+) wires", str(isa("num_wires")))],
        # check_gds holds these to the run's metrics
        "Hardened": [("gds run", r"gds run \[?(\d{10,12})", True),
                     ("cells", r"([\d,]+) standard cells", True),
                     ("utilisation", r"([\d.]+)% utilisation", True),
                     ("slack", r"([+-][\d.]+) ns at the slow corner", True)],
        "Firmware": [("library firmwares", r"(\d+) library", str(len(library_firmwares()))),
                     ("protocols", r"(\d+) protocols",
                      str(len(re.split(r",\s*", listed[1]))) if listed else "a list")],
        "Proved": [],
        "Board": [("bench date", r"(\d{4}-\d\d-\d\d)", bench[1] if bench else "a date"),
                  ("silicon", r"(no silicon yet)", silicon)],
    }
    for label in table.keys() - rows.keys():
        yield f"the table's {label} row has no check, add one to test/check_docs.py"
    for label, checks in rows.items():
        if label not in table:
            yield f"the table has no {label} row"
            continue
        for what, pattern, expected in checks:
            m = re.search(pattern, table[label])
            if not m:
                yield f"the table's {label} row does not give its {what}"
            elif expected is not True and m[1] != expected:
                yield f"the table's {label} row says {m[1]} for its {what}, not {expected}"


CHECKS = [check_paths, check_make, check_jobs, check_commits, check_counts, check_transcripts,
          check_glance]
ONLINE_CHECKS = [check_runs, check_gds, check_mutation]


def failures(docs):
    """{check: [what is wrong]} over every doc."""
    checks = CHECKS + (ONLINE_CHECKS if ONLINE else [])
    return {c.__name__: [f"{doc}: {why}" for doc, text in docs.items() for why in c(doc, text)]
            for c in checks}


def read_docs():
    return {doc: read(doc) for doc in DOCS}


def first(pattern, change):
    """The README with the first match of [pattern]'s group changed, or None."""
    def tooth(text):
        m = re.search(pattern, text)
        return m and text[:m.start(1)] + change(m[1]) + text[m.end(1):]
    return tooth


def bump(s):
    """[s] with its last digit one more, a count, date or id the docs did not mean."""
    i = max(i for i, c in enumerate(s) if c.isdigit())
    return s[:i] + str((int(s[i]) + 1) % 10) + s[i + 1:]


# Wrong READMEs, made from what it says now: (what is wrong, how, needs gh)
TEETH = [
    ("a path", first(PATH, lambda p: re.sub(r"\.(\w+)$", r"x.\1", p)), False),
    ("a directory", first(DIRECTORY, lambda d: d[:-1] + "x/"), False),
    ("a make target", first(r"make -C \S+ ([a-z]\w*)(?![\w=])", lambda t: t + "x"), False),
    ("a job", first(JOB, lambda j: j + "x"), False),
    ("a commit", first(r"\b(?=\w*[a-f])(?=\w*\d)([0-9a-f]{7})\b", bump), False),
    ("the firmware count", first(r"(\d+) library firmwares", bump), False),
    ("the protocols", first(r"(\d+) protocols", bump), False),
    ("the mutation score", first(r"(\d+) of \d+ valid mutants", bump), False),
    ("the equivalent mutants", first(r"other (\d+) are equivalent", bump), False),
    ("the tiles", first(r"(\d+ x \d+) tiles", bump), False),
    ("the clock", first(r"\| (\d+) MHz", bump), False),
    ("the cores", first(r"(\d+) cores", bump), False),
    ("the SRAM macros", first(r"(\d+) IHP", bump), False),
    ("the inputs", first(r"(\d+) in,", bump), False),
    ("the wires", first(r"(\d+) wires", bump), False),
    ("the bench date", first(r"demo on (\d{4}-\d\d-\d\d)", bump), False),
    ("a missing row", first(r"(\| Clock \|[^\n]*\n)", lambda _: ""), False),
    ("a transcript", first(r"worst slack (\d+)", bump), False),
    ("a transcript's edit", first(r"\$ sed '([^']*)'", bump), False),
    ("the slack", first(r"([+-][\d.]+) ns at the slow corner", bump), True),
    ("the utilisation", first(r"([\d.]+)% utilisation", bump), True),
    ("the cells", first(r"([\d,]+) standard cells", bump), True),
    ("a run id", first(r"run \[?(\d{10,12})", bump), True),
    ("a run date", first(r"run \d{10,12}, (\d{4}-\d\d-\d\d)", bump), True),
    # the run the die picture is from, which hardened older Verilog
    ("an old gds run", first(r"[Gg]ds run (\d{10,12})", lambda _: "36615334436"), True),
]


def teeth():
    docs = read_docs()
    if any(failures(docs).values()):
        sys.exit("the docs fail as they are, so the teeth would prove nothing")
    missed = []
    for what, tooth, online in TEETH:
        if online and not ONLINE:
            print(f"skip {what} (offline)")
            continue
        wrong = tooth(docs["README.md"])
        if not wrong:
            sys.exit(f"the tooth for {what} finds nothing to change in the README")
        caught = [name for name, found in failures({**docs, "README.md": wrong}).items() if found]
        line = next(b for a, b in zip(docs["README.md"].splitlines(), wrong.splitlines()) if a != b)
        print(f"{'ok  ' if caught else 'FAIL'} {what}, caught by {', '.join(caught) or 'nothing'}")
        print(f"     {line.strip()[:88]}")
        if not caught:
            missed.append(what)
    if missed:
        sys.exit(f"{len(missed)} wrong READMEs passed: {', '.join(missed)}")


def main():
    global ONLINE
    p = argparse.ArgumentParser()
    p.add_argument("--offline", action="store_true", help="skip what needs gh")
    p.add_argument("--teeth", action="store_true", help="check that wrong READMEs fail")
    args = p.parse_args()
    ONLINE = not args.offline
    if not ONLINE:
        print("skip run ids, gds metrics and mutation scores (offline)")
    if args.teeth:
        return teeth()
    failed = failures(read_docs())
    for name, found in failed.items():
        print(f"{'FAIL' if found else 'ok  '} {name}")
        for why in found:
            print(f"     {why}")
    if any(failed.values()):
        sys.exit(f"{sum(map(len, failed.values()))} things in the docs disagree with the repo")


if __name__ == "__main__":
    main()
