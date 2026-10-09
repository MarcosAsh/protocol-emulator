# SPDX-License-Identifier: Apache-2.0
# Fails when README.md or docs/info.md cites a path, make target, job, commit or run that
# is not there, or quotes a number the code, the tests or the cited run disagree with.
# --teeth checks that wrong READMEs made from this one fail. --offline skips the runs.
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
WARNINGS = []

# cited for the reader to make: tt-support-tools is cloned into tt/
NOT_IN_REPO = ("tt/",)

# what a gds run hardens, as gds.yaml's paths filter has it
HARDENED = ["src", "macro", "info.yaml", "librelane_plugin_sram_pdn.py", "odb_sram_stripes.py",
            ":!*.ml", ":!*.mli", ":!**/dune"]

EXTENSIONS = "ml|mli|sv|v|sby|py|asm|hex|txt|tcl|yaml|svg|png|md|json|settings|lpf|mk"
PATH = re.compile(rf"(?<![\w./-])((?:[\w.-]+/)+[\w.-]+\.(?:{EXTENSIONS}))(?!\.?[\w/-])")
# and any backticked token with a slash, whatever its extension
BACKTICKED = re.compile(r"`(?![^`]*://)([^`\s*]*/[^`\s*]*)`")
URL = re.compile(r"https?://[^\s)]+")
FENCE = re.compile(r"^```[\w-]*\n(.*?)^```", re.M | re.S)
MAKE = re.compile(r"make -C ([\w./-]+)([^#\n]*)")
JOB = re.compile(r"`([\w-]+)` job")
# a run id is all digits and longer, a word such as "defaced" has no digit, and an all-digit
# token of 7 or 8 counts only if git knows it (check_commits)
COMMIT = re.compile(r"(?<![\w/#.-])(?=[0-9a-f]*\d)([0-9a-f]{7,8}|(?=[0-9]*[a-f])[0-9a-f]{9,12})"
                    r"(?![\w.-])")
# a run is cited by its link, or as "run N", never by a bare number such as a job id
RUN = re.compile(r"actions/runs/(\d+)|\bruns?,? \[?(\d{9,})")
# what follows "run N, ", which has to be a date in ISO form if it looks like one at all
DATED_RUN = re.compile(r"\bruns?,? \[?(\d{9,})\]?(?:\([^)]*\))?, ([^,;)]*)")
LOOKS_DATED = re.compile(r"\d|\b(?:jan|feb|mar|apr|jun|jul|aug|sep|oct|nov|dec)", re.I)


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
        # newer gh refuses logs with colour codes unless told, older gh has no such flag
        if "--allow-escape-sequences" in done.stderr and args[0] == "api":
            args = ("api", "--allow-escape-sequences", *args[1:])
            continue
        time.sleep(2 ** attempt)
    sys.exit(f"gh {' '.join(args)}: {done.stderr.strip()}")


# What the repo and CI say

class Unreadable(Exception):
    """A source no longer says what a check reads from it."""


def read(path):
    if not (ROOT / path).is_file():
        raise Unreadable(f"{path} does not exist, and a check reads it")
    return (ROOT / path).read_text()


def find(pattern, path, flags=re.M):
    m = re.search(pattern, read(path), flags)
    if not m:
        raise Unreadable(f"{path} has nothing like {pattern}, update test/check_docs.py")
    return m


def tiles():
    m = find(r'^\s*tiles:\s*"(\d+)x(\d+)"', "info.yaml")
    return f"{m[1]} x {m[2]}"


def clock_mhz():
    return int(find(r"^\s*clock_hz:\s*(\d+)", "info.yaml")[1]) // 1_000_000


def pdk():
    return find(r"pdk: ihp-(\w+)", ".github/workflows/gds.yaml")[1].upper()


def pinout():
    """How many pins info.yaml gives the host, and inputs, outputs and bidirectional IO."""
    names = re.findall(r'^\s*u(?:i|o|io)\[\d\]:\s*"([^"]*)"', read("info.yaml"), re.M)
    kinds = {"host": r"host ", "in": r"IN\d", "out": r"OUT\d", "bidirectional": r"IO\d"}
    return {k: sum(1 for n in names if re.match(p, n)) for k, p in kinds.items()}


def isa(name):
    return int(find(rf"^let {name} = (\d+)$", "src/isa.ml")[1])


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
    macros = [n for n in instances() if re.match(r"RM_IHPSG13_1P_\d+x\d+_", n)]
    if len(macros) != 1:
        raise Unreadable(f"src/protocol_emulator.v holds {len(macros)} kinds of SRAM macro, "
                         "not 1, update test/check_docs.py")
    words, bits = re.match(r"RM_IHPSG13_1P_(\d+)x(\d+)_", macros[0]).groups()
    return instances()[macros[0]], int(words), int(bits)


def library_firmwares():
    """The library firmwares the kernel accepts in test_kernel.ml, which dune runtest keeps
    current."""
    test = find(r'^let%expect_test "the kernel on the firmware library[^"]*" =(.*?)\|\}\]',
                "test/test_kernel.ml", re.M | re.S)[1]
    return re.findall(r"^\s*\((\w+) \(verdict \(Ok \(\)\)\)\)$", test, re.M)


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


def same_chip(sha):
    return git("diff", "--quiet", sha, "HEAD", "--", *HARDENED).returncode == 0


@cache
def current_gds_run():
    """The newest green gds run on main that hardened the chip as it is now, or None."""
    out = gh("api", f"repos/{REPO}/actions/workflows/gds.yaml/runs?branch=main&status=success")
    for r in json.loads(out or '{"workflow_runs": []}')["workflow_runs"]:
        if not not_ours(r["head_sha"]) and same_chip(r["head_sha"]):
            return str(r["id"])
    return None


@cache
def gds_metrics(run_id):
    """The metrics.csv row gds.yaml uploads, or None and why not."""
    out = gh("api", f"repos/{REPO}/actions/runs/{run_id}/artifacts?name=metrics")
    artifacts = json.loads(out or '{"artifacts": []}')["artifacts"]
    if not artifacts:
        return None, "has no metrics artifact"
    if artifacts[0]["expired"]:
        return None, f"has a metrics artifact that expired on {artifacts[0]['expires_at'][:10]}"
    with tempfile.TemporaryDirectory() as tmp:
        gh("run", "download", run_id, "-R", REPO, "-n", "metrics", "-D", tmp)
        if not (Path(tmp) / "metrics.csv").exists():
            return None, "has a metrics artifact gh could not download"
        with open(Path(tmp) / "metrics.csv") as f:
            return next(csv.DictReader(f)), None


@cache
def mutation_score(run_id):
    """(killed, valid) from the run's log, or None and why not."""
    url = f"repos/{REPO}/actions/runs/{run_id}/jobs?per_page=100"
    jobs = json.loads(gh("api", url) or '{"jobs": []}')["jobs"]
    # a sharded run's score is its score job's; each shard logs only its own part
    jobs = [job for job in jobs if job["name"] == "score"] or jobs
    logs = [gh("api", f"repos/{REPO}/actions/jobs/{job['id']}/logs") for job in jobs]
    if not any(logs):
        return None, "has a log that expired"
    for log in filter(None, logs):
        if m := re.search(r"total: killed (\d+) of (\d+) valid mutants", log):
            return (int(m[1]), int(m[2])), None
    return None, "has no score in its log"


def warn(message):
    """For a cited run that still checks but whose numbers can no longer be read."""
    if message not in WARNINGS:
        WARNINGS.append(message)


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
    """The first table in the README, as {label: (what it says, its source)}."""
    table = next((u for u in re.split(r"\n\s*\n", text) if u.startswith("|")), "")
    rows = [[c.strip() for c in row.strip("|").split("|")] for row in table.splitlines()[2:]]
    return {cells[0]: (cells[1], " ".join(cells[2:])) for cells in rows}


def row_numbers(text):
    """Every number in [text], sorted: 23,883 and +4.009 count, the 5 of ECP5 does not."""
    found = re.findall(r"(?<![\w.,+-])([+-]?(?:\d{1,3}(?:,\d{3})+|\d+)(?:\.\d+)?)(?!\w)", text)
    return sorted(round(float(n.replace(",", "")), 6) for n in found)


def numbers(pattern, text):
    return [int(n.replace(",", "")) for n in re.findall(pattern, text)]


# The checks, each yielding what is wrong

def check_paths(doc, text):
    for path in sorted(set(PATH.findall(URL.sub(" ", text)) + BACKTICKED.findall(text))):
        if path.startswith(NOT_IN_REPO) or git("check-ignore", "-q", path).returncode == 0:
            continue  # the reader makes it
        if not (ROOT / path).exists():
            yield f"{path} does not exist"


def make_commands(text):
    """(directory, targets) of each make -C, whole in code, and in prose only when it ends
    at punctuation or the line's end, so the words after it are not read as targets."""
    fences = FENCE.findall(text)
    rest = FENCE.sub("", text)
    for code in fences + re.findall(r"`([^`\n]+)`", rest):
        for directory, args in MAKE.findall(code):
            yield directory, [a for a in args.split() if "=" not in a and not a.startswith("-")]
    prose = re.sub(r"`[^`\n]+`", "", rest)
    word = r"[\w/-]+(?:\.[\w/-]+)*"  # a full stop after it ends the sentence
    for directory, target in re.findall(rf"make -C ({word})(?: ({word}))?(?=[.,;:)]|\s*$)",
                                        prose, re.M):
        yield directory, [target] if target else []


def check_make(doc, text):
    for directory, targets in make_commands(text):
        if not (ROOT / directory / "Makefile").exists():
            yield f"make -C {directory}: there is no {directory}/Makefile"
            continue
        for target in targets:
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
        why = not_ours(commit)
        if commit.isdigit() and why == "is not a commit":
            continue  # a number such as 16777216, unless git knows it as a commit
        if why:
            yield f"commit {commit} {why}"


def check_runs(doc, text):
    for run_id in sorted({m[1] or m[2] for m in RUN.finditer(flat(text))}):
        r = run(run_id)
        if r is None:
            yield f"run {run_id} does not exist in {REPO}"
        elif r["conclusion"] != "success":
            yield f"run {run_id} ({r['name']}) concluded {r['conclusion']}"
        elif why := not_ours(r["head_sha"]):
            yield f"run {run_id} ran {r['head_sha'][:7]}, which {why}"
    for run_id, phrase in DATED_RUN.findall(flat(text)):
        r = run(run_id)
        if m := re.fullmatch(r"(\d{4}-\d\d-\d\d)\.?", phrase.strip()):
            if r and r["created_at"][:10] != m[1]:
                yield f"run {run_id} is dated {m[1]} but ran on {r['created_at'][:10]}"
        elif LOOKS_DATED.search(phrase):
            yield f"run {run_id} has {phrase.strip()!r} beside it, write a date as YYYY-MM-DD"


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
        newer = current_gds_run()
        cite = f"cite gds run {newer}" if newer else "no green gds run on main has hardened it"
        sha = run(run_id)["head_sha"]
        if not same_chip(sha):
            yield f"gds run {run_id} hardened {sha[:7]} and the chip has changed since, {cite}"
        metrics, why = gds_metrics(run_id)
        if metrics is None and "expired" in why:
            warn(f"gds run {run_id} {why}, so the numbers beside it go unchecked, "
                 f"{cite if newer != run_id else 'run gds again and cite that'}")
        elif metrics is None:
            yield f"gds run {run_id} {why}"
        if metrics is None or unit.startswith("|"):
            continue  # check_glance holds a table row's numbers
        quoted = {
            "setup_slow_ns": re.findall(r"([+-]\d+\.\d+) ns at the slow corner", unit),
            "utilisation": [round(float(u) / 100, 6)
                            for u in re.findall(r"([\d.]+)% utilisation", unit)],
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
            score, why = mutation_score(run_id)
            if score is None and "expired" in why:
                warn(f"mutation run {run_id} {why}, so the score beside it goes unchecked, "
                     "cite a newer mutation run")
            elif score is None:
                yield f"mutation run {run_id} {why}"
            if score is None:
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
            yield f"{n} library firmwares, the kernel accepts {firmwares} in test/test_kernel.ml"
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
    depth = int(find(r"^let depth = (\d+)$", "src/host_fifo.ml")[1])
    for n in numbers(r"(\d+)-deep fifos", text):
        if n != depth:
            yield f"{n}-deep fifos, src/host_fifo.ml has depth = {depth}"


def check_transcripts(doc, text):
    """What a transcript shows the assembler print, a test in test/assemble/ diffs
    against what it does print, after the same edit."""
    printed = {line for f in (ROOT / "test/assemble").glob("*.expected")
               for line in f.read_text().splitlines()}
    for block in FENCE.findall(text):
        if "bin/generate.exe assemble" not in block:
            continue
        for line in block.splitlines():
            if m := re.match(r"\$ sed '([^']*)'", line):
                if f'"{m[1]}"' not in read("test/assemble/dune"):
                    yield f"no rule in test/assemble/dune makes the edit {m[1]}"
            elif not line.startswith("$ ") and line != "..." and line not in printed:
                yield f"no test in test/assemble/ prints {line.strip()!r}"


def check_glance(doc, text):
    """The table at the top of the README: each row's numbers, in any order and wording,
    are exactly the ones its sources give."""
    if doc != "README.md":
        return
    table = glance(text)
    count, words, bits = sram()
    pins = pinout()
    hardened = None  # unchecked offline, or once the run's metrics expire
    if run_id := re.search(r"gds run \[?(\d{10,12})", table.get("Hardened", ("", ""))[1]):
        metrics = gds_metrics(run_id[1])[0] if ONLINE and run(run_id[1]) else None
        if metrics:
            hardened = [metrics["std_cells"], float(metrics["utilisation"]) * 100,
                        metrics["setup_slow_ns"]]
    elif "Hardened" in table:
        yield "the table's Hardened row cites no gds run"
    expected = {
        "Process": [tiles()],
        "Clock": [clock_mhz()],
        "Cores": [instances().get("engine"), count, words, bits],
        "Pins": [pins["host"], pins["in"], pins["out"], pins["bidirectional"], isa("num_wires")],
        "Hardened": hardened,
        "Firmware": [len(library_firmwares())],
        "Proved": [],
        "Board": None,  # the bench, which no file in the repo records
    }
    for label in table.keys() - expected.keys():
        yield f"the table's {label} row has no check, add one to test/check_docs.py"
    for label, numbers in expected.items():
        if label not in table:
            yield f"the table has no {label} row"
        elif numbers is not None:
            said, sources = row_numbers(table[label][0]), row_numbers(" ".join(map(str, numbers)))
            if said != sources:
                said, sources = (", ".join(f"{n:g}" for n in ns) for ns in (said, sources))
                yield f"the table's {label} row gives {said or 'no number'}, its sources {sources}"
    if "Process" in table and pdk() not in table["Process"][0].upper():
        yield f"the table's Process row does not name {pdk()}, which gds.yaml hardens on"


CHECKS = [check_paths, check_make, check_jobs, check_commits, check_counts, check_transcripts,
          check_glance]
ONLINE_CHECKS = [check_runs, check_gds, check_mutation]


def failures(docs):
    """{check: [what is wrong]} over every doc."""
    def wrong(check, doc, text):
        try:
            return [f"{doc}: {why}" for why in check(doc, text)]
        except Unreadable as e:
            return [f"{doc}: {e}"]

    checks = CHECKS + (ONLINE_CHECKS if ONLINE else [])
    return {c.__name__: [w for doc, text in docs.items() for w in wrong(c, doc, text)]
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


# Wrong READMEs, made from what it says now: (what is wrong, how, what it needs: gh, or
# the metrics of the cited gds run, which expire)
TEETH = [
    ("a path", first(PATH, lambda p: re.sub(r"\.(\w+)$", r"x.\1", p)), None),
    ("a directory", first(r"`((?:[\w.-]+/)+)`", lambda d: d[:-1] + "x/"), None),
    ("a make target", first(r"make -C \S+ ([a-z]\w*)(?![\w=])", lambda t: t + "x"), None),
    ("a job", first(JOB, lambda j: j + "x"), None),
    ("a commit", first(r"\b(?=\w*[a-f])(?=\w*\d)([0-9a-f]{7})\b", bump), None),
    ("the firmware count", first(r"(\d+) library firmwares", bump), None),
    ("the mutation score", first(r"(\d+) of \d+ valid mutants", bump), None),
    ("the equivalent mutants", first(r"other (\d+) are equivalent", bump), None),
    ("the tiles", first(r"(\d+ x \d+) tiles", bump), None),
    ("the clock", first(r"\| (\d+) MHz", bump), None),
    ("the cores", first(r"(\d+) cores", bump), None),
    ("the SRAM macros", first(r"(\d+) IHP", bump), None),
    ("the inputs", first(r"(\d+) in,", bump), None),
    ("the wires", first(r"(\d+) wires", bump), None),
    ("a missing row", first(r"(\| Clock \|[^\n]*\n)", lambda _: ""), None),
    ("a transcript", first(r"worst slack (\d+)", bump), None),
    ("a transcript's edit", first(r"\$ sed '([^']*)'", bump), None),
    ("the slack", first(r"([+-][\d.]+) ns at the slow corner", bump), "metrics"),
    ("the utilisation", first(r"([\d.]+)% utilisation", bump), "metrics"),
    ("the cells", first(r"([\d,]+) standard cells", bump), "metrics"),
    ("a run id", first(r"run \[?(\d{10,12})", bump), "gh"),
    ("a run date", first(r"run \d{10,12}, (\d{4}-\d\d-\d\d)", bump), "gh"),
    ("a run date in words", first(r"run \d{10,12}, (\d{4}-\d\d-\d\d)", lambda _: "29 Sep"), "gh"),
    # the run the die picture is from, which hardened older Verilog
    ("an old gds run", first(r"[Gg]ds run (\d{10,12})", lambda _: "36615334436"), "gh"),
]


def teeth():
    docs = read_docs()
    if any(failures(docs).values()):
        sys.exit("the docs fail as they are, so the teeth would prove nothing")
    cited = re.search(r"[Gg]ds run \[?(\d{10,12})", docs["README.md"])
    has = {None: True, "gh": ONLINE,
           "metrics": ONLINE and cited is not None and gds_metrics(cited[1])[0] is not None}
    missed = []
    for what, tooth, needs in TEETH:
        if not has[needs]:
            print(f"skip {what}, which needs {needs}")
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
    for message in WARNINGS:
        print(f"::warning::{message}")
    if any(failed.values()):
        sys.exit(f"{sum(map(len, failed.values()))} things in the docs disagree with the repo")


if __name__ == "__main__":
    main()
