# SPDX-License-Identifier: Apache-2.0
# Fails when README.md or docs/info.md cites a path, make target, job, commit or run that
# is not there, or quotes a number the code, the tests or the cited run disagree with,
# naming the line, or links to a page that is gone. Board results and gds runs older than
# CI keeps are read from the releases test/evidence.sha256 pins. --teeth checks that wrong
# READMEs made from this one fail. --offline skips the runs, evidence and links.
# Usage: python3 test/check_docs.py [--offline] [--teeth] [--external-links]
import argparse
import contextlib
import csv
import io
import json
import re
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
from functools import cache
from pathlib import Path

import evidence

ROOT = Path(__file__).resolve().parent.parent
DOCS = ["README.md", "docs/info.md"]
REPO = "MarcosAsh/protocol-emulator"
ONLINE = True
EXTERNAL = False
# links checked unless --external-links asks for every host
OWN_HOSTS = ("github.com", "marcosash.github.io")
LINK_TTL = 24 * 3600  # how long a link that answered is not asked again
WORDS = dict(zip("one two three four five six seven eight nine ten".split(),
                 map(str, range(1, 11))))
WARNINGS = []
DEADLINE = "2027-01-18"  # the competition's submission date

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


@cache
def engine_scope():
    """The files of test/mutate.py's engine scope, whose score the docs quote."""
    files = find(r'"engine": \{\s*"files": \[([^]]*)\]', "test/mutate.py")[1]
    return re.findall(r'"([^"]+)"', files)


def equivalent_mutants():
    lines = read("test/mutation_allow.txt").splitlines()
    return sum(1 for line in lines if line.split(" ## ")[0] in engine_scope())


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
def green_runs(workflow):
    """The green runs of [workflow] on main that HEAD descends from, newest first."""
    out = gh("api", f"repos/{REPO}/actions/workflows/{workflow}/runs?branch=main&status=success"
                    "&per_page=100")
    return [r for r in json.loads(out or '{"workflow_runs": []}')["workflow_runs"]
            if not not_ours(r["head_sha"])]


@cache
def chip_gds_runs():
    """The green gds runs on main that hardened the chip as it is now, newest first."""
    return [str(r["id"]) for r in green_runs("gds.yaml") if same_chip(r["head_sha"])]


def current_gds_run():
    """The newest of them, or None."""
    return next(iter(chip_gds_runs()), None)


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
            return {**next(csv.DictReader(f)), "expires_at": artifacts[0]["expires_at"][:10]}, None


@cache
def gds_numbers(run_id):
    """The run's metrics row from a pinned release that keeps it, else from its artifact,
    or None and why not."""
    kept = evidence.gds_kept(run_id)
    return (kept, None) if kept else gds_metrics(run_id)


def said_gds(m):
    """A metrics row as the docs word it."""
    return (f"{int(m['std_cells']):,} standard cells, "
            f"{round(float(m['utilisation']) * 100, 6):g}% utilisation, "
            f"setup slack {float(m['setup_slow_ns']):+.3f} ns at the slow corner")


def best_gds_run():
    """The run the docs should cite: the newest green gds run of the chip as it is now that
    a pinned release keeps, else the newest, or None."""
    runs = chip_gds_runs()
    return next((r for r in runs if evidence.gds_kept(r)), next(iter(runs), None))


@cache
def fresh_gds():
    """What to cite instead: a green gds run of the chip as it is now, one a pinned release
    keeps if there is one, and its numbers."""
    best = best_gds_run()
    if best is None:
        return "no green gds run on main has hardened the chip as it is now"
    kept = evidence.gds_kept(best)
    where = f", kept in release {kept['release']}" if kept else ""
    m, _ = gds_numbers(best)
    return f"cite gds run {best}{where}" + (f": {said_gds(m)}" if m else "")


@cache
def failed_jobs(run_id, name):
    """The conclusions of [run_id]'s jobs called [name] that did not succeed."""
    jobs = json.loads(gh("api", f"repos/{REPO}/actions/runs/{run_id}/jobs?per_page=100")
                      or '{"jobs": []}')["jobs"]
    found = [j["conclusion"] for j in jobs if j["name"] == name]
    return [c for c in found if c != "success"] if found else ["missing"]


def changed_since(sha, paths):
    return git("diff", "--name-only", sha, "HEAD", "--", *paths).stdout.split()


@cache
def fresh_mutation():
    """What to cite instead: the newest green mutation run on main of the files as they
    are, and its score."""
    for r in green_runs("mutation.yaml"):
        if not changed_since(r["head_sha"], engine_scope()):
            score, _ = mutation_score(str(r["id"]))
            if score:
                return (f"cite mutation run {r['id']}, {r['created_at'][:10]}: killed "
                        f"{score[0]} of {score[1]} valid mutants")
    return ("no green mutation run on main has mutated them as they are, run mutation.yaml "
            "on main and cite that")


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


@cache
def link_status(url):
    """The status [url] answers with after redirects, or None if it does not answer. An
    answer under 400 is cached for LINK_TTL, so CI asks GitHub once a day."""
    path = evidence.CACHE / "links.json"
    try:
        seen = json.loads(path.read_text())
    except (OSError, ValueError):
        seen = {}
    if (hit := seen.get(url)) and hit["status"] < 400 and time.time() - hit["at"] < LINK_TTL:
        return hit["status"]
    for method in ["HEAD", "GET"]:
        ask = urllib.request.Request(url, method=method,
                                     headers={"User-Agent": "protocol-emulator check_docs"})
        try:
            with urllib.request.urlopen(ask, timeout=20) as answer:
                status = answer.status
        except urllib.error.HTTPError as e:
            status = e.code
        except (urllib.error.URLError, OSError):
            status = None
        if status != 405:  # HEAD not allowed
            break
    if status is not None:
        seen[url] = {"status": status, "at": time.time()}
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(seen, indent=1, sort_keys=True))
    return status


def warn(message):
    """For evidence that checks now but will not for long, or a link GitHub would not
    answer."""
    if message not in WARNINGS:
        WARNINGS.append(message)


# What the docs say

def line_of(text, needle):
    """The line [needle] starts on in [text], however the text wraps it, or None. A needle
    (unit, n) is n's first line from where the paragraph or row [unit] starts."""
    def at(needle, start=0):
        words = str(needle).split()[:12]
        m = words and re.compile(r"\s+".join(map(re.escape, words))).search(text, start)
        return m.start() if m else None
    unit, needle = needle if isinstance(needle, tuple) else (None, needle)
    found = at(needle, (unit and at(unit)) or 0)
    return None if found is None else text.count("\n", 0, found) + 1


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
            yield path, f"{path} does not exist"


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
            yield f"make -C {directory}", f"make -C {directory}: there is no {directory}/Makefile"
            continue
        for target in targets:
            if target not in make_targets(directory):
                yield f"make -C {directory}", f"make -C {directory} {target}: no such target"


def check_jobs(doc, text):
    for job in sorted(set(JOB.findall(flat(text)))):
        if job not in workflow_jobs():
            yield f"`{job}` job", f"no workflow has a `{job}` job"


def check_commits(doc, text):
    if git("rev-parse", "--is-shallow-repository").stdout.strip() != "false":
        yield "a shallow clone cannot place commits, check out with fetch-depth: 0"
        return
    for commit in sorted(set(COMMIT.findall(URL.sub(" ", text)))):
        why = not_ours(commit)
        if commit.isdigit() and why == "is not a commit":
            continue  # a number such as 16777216, unless git knows it as a commit
        if why:
            yield commit, f"commit {commit} {why}"


def check_runs(doc, text):
    for run_id in sorted({m[1] or m[2] for m in RUN.finditer(flat(text))}):
        r = run(run_id)
        if r is None:
            yield run_id, f"run {run_id} does not exist in {REPO}"
        elif r["conclusion"] != "success":
            yield run_id, f"run {run_id} ({r['name']}) concluded {r['conclusion']}"
        elif why := not_ours(r["head_sha"]):
            yield run_id, f"run {run_id} ran {r['head_sha'][:7]}, which {why}"
    for run_id, phrase in DATED_RUN.findall(flat(text)):
        r = run(run_id)
        if m := re.fullmatch(r"(\d{4}-\d\d-\d\d)\.?", phrase.strip()):
            if r and r["created_at"][:10] != m[1]:
                yield m[1], f"run {run_id} is dated {m[1]} but ran on {r['created_at'][:10]}"
        elif LOOKS_DATED.search(phrase):
            yield run_id, (f"run {run_id} has {phrase.strip()!r} beside it, write a date as "
                           "YYYY-MM-DD")


def check_gds(doc, text):
    """Numbers beside a gds run are that run's, it hardened the chip as it is now, and it is
    the newest green one on main or a release pinned in test/evidence.sha256 keeps it."""
    for unit in units(text):
        runs = set(re.findall(r"[Gg]ds run \[?(\d{10,12})", unit))
        if len(runs) > 1:
            yield ((unit, min(runs)),
                   f"gds runs {', '.join(sorted(runs))} in one place, whose numbers are whose?")
        if len(runs) != 1:
            continue
        run_id = runs.pop()
        if not run(run_id):
            continue  # check_runs says so
        sha = run(run_id)["head_sha"]
        if not same_chip(sha):
            yield (unit, run_id), (f"gds run {run_id} hardened {sha[:7]} and the chip has "
                                   f"changed since, {fresh_gds()}")
            continue
        if run_id != current_gds_run() and not evidence.gds_kept(run_id):
            yield (unit, run_id), (f"gds run {run_id} is stale, a newer green gds run on main "
                                   f"hardened this chip and no pinned release keeps it, "
                                   f"{fresh_gds()}")
        metrics, why = gds_numbers(run_id)
        if metrics is None:
            yield (unit, run_id), (f"gds run {run_id} {why}, so the numbers beside it cannot "
                                   f"be checked, {fresh_gds()}")
            continue
        if metrics.get("expires_at", DEADLINE) < DEADLINE:
            warn(f"gds run {run_id}'s metrics expire on {metrics['expires_at']}, before the "
                 f"{DEADLINE} deadline, keep them in a release pinned in test/evidence.sha256")
        if "precheck" in unit and (bad := failed_jobs(run_id, "precheck")):
            yield (unit, "precheck"), f"gds run {run_id}'s precheck job is {', '.join(bad)}"
        if unit.startswith("|"):
            continue  # check_glance holds a table row's numbers
        quoted = [("setup_slow_ns", s, float(s))
                  for s in re.findall(r"([+-]\d+\.\d+) ns at the slow corner", unit)]
        quoted += [("utilisation", s, round(float(s) / 100, 6))
                   for s in re.findall(r"([\d.]+)% utilisation", unit)]
        quoted += [("std_cells", s, int(s.replace(",", "")))
                   for s in re.findall(r"([\d,]+) (?:standard )?cells", unit)]
        for key, said, value in quoted:
            if abs(value - float(metrics[key])) > 1e-9:
                yield (unit, said), (f"gds run {run_id} has {key} {metrics[key]}, the docs say "
                                     f"{said}: {said_gds(metrics)}")


def check_mutation(doc, text):
    """A mutation score beside a mutation run is that run's, and the run mutated the files
    as they are now."""
    for unit in units(text):
        for run_id in re.findall(r"mutation run \[?(\d{10,12})", unit):
            if not run(run_id):
                continue
            sha = run(run_id)["head_sha"]
            if changed := changed_since(sha, engine_scope()):
                yield (unit, run_id), (f"mutation run {run_id} mutated {sha[:7]}, and "
                                       f"{', '.join(changed)} changed since, {fresh_mutation()}")
            score, why = mutation_score(run_id)
            if score is None:
                yield (unit, run_id), (f"mutation run {run_id} {why}, so the score beside it "
                                       f"cannot be checked, {fresh_mutation()}")
                continue
            for quoted in re.findall(r"(\d+) of (\d+) valid mutants", unit):
                if tuple(map(int, quoted)) != score:
                    yield ((unit, " of ".join(quoted)),
                           f"mutation run {run_id} killed {score[0]} of {score[1]}, the docs say "
                           f"{quoted[0]} of {quoted[1]}")


def check_board(doc, text):
    """A demo the docs say passed on a date passed that day in a hashed ledger a release
    pinned in test/evidence.sha256 keeps, with the edges and baud the docs give it."""
    for unit in units(text):
        for m in re.finditer(r"passed (?:the ([\w-]+) demo )?on (\d{4}-\d\d-\d\d)", unit):
            scripts = re.findall(r"`(python/\w+\.py)`", unit[:m.start()].rsplit(". ", 1)[-1])
            demo = m[1].replace("-", "_") if m[1] else scripts[-1] if scripts else None
            if demo is None:
                yield (unit, m[0]), f"{m[0]!r} names no demo or python/ script before it"
                continue
            found = evidence.passes(demo)
            entry = next((e for e in found if e.get("time", "")[:10] == m[2]), None)
            if entry is None:
                newest = found and found[0]
                fresh = (f"the newest is {newest.get('time', '?').replace('T', ' ')} in release "
                         f"{newest['release']}, {newest['path']}, bitstream sha256 "
                         f"{newest.get('bitstream_sha256', '?')[:16]}" if newest
                         else "no pinned ledger has it passing")
                yield ((unit, m[2]),
                       f"no hashed board evidence shows {demo} passing on {m[2]}, {fresh}")
                continue
            after = unit[m.end():]
            for n in numbers(r"all (\d+) edges", after):
                logged = evidence.edges(entry)
                if not logged or any(edges != n or not ok for _, edges, ok in logged):
                    said = ", ".join(f"{edges} {label}{'' if ok else ' (not all on time)'}"
                                     for label, edges, ok in logged)
                    yield ((unit, f"all {n} edges"),
                           f"{demo} on {m[2]} logged {said or 'no edges'}, the docs say all {n}")
            bauds = re.findall(r"baudrate=(\d+)", (entry["dir"] / "run.txt").read_text())
            for n in numbers(r"at (\d+) baud", after):
                if str(n) not in bauds:
                    yield ((unit, f"{n} baud"), f"{demo} on {m[2]} decoded at "
                           f"{', '.join(bauds) or 'no'} baud, the docs say {n}")


def check_links(doc, text):
    """Every link to GitHub or the Pages site answers, and a 404 or 410 fails. Runs are
    check_runs', and other hosts are asked only with --external-links."""
    for url in sorted({u.rstrip(".,;:") for u in URL.findall(text)}):
        host = urllib.parse.urlparse(url).hostname or ""
        if "/actions/runs/" in url or not (EXTERNAL or host in OWN_HOSTS):
            continue
        status = link_status(url)
        if status in (404, 410):
            yield url, f"{url} answers {status}"
        elif status is None or status >= 400:
            warn(f"{url} answered {status or 'nothing'}, so it goes unchecked")


@cache
def cocotb_seconds(run_id, module):
    """{test: real seconds} for [module]'s cocotb tests that passed in [run_id]'s logs."""
    jobs = json.loads(gh("api", f"repos/{REPO}/actions/runs/{run_id}/jobs?per_page=100")
                      or '{"jobs": []}')["jobs"]
    logs = "".join(gh("api", f"repos/{REPO}/actions/jobs/{j['id']}/logs") or "" for j in jobs)
    return {test: float(s) for test, s in re.findall(
        rf"\*\* {module}\.(\w+) +PASS +[\d.]+ +([\d.]+) ", logs)}


def check_demo_time(doc, text):
    """How long the docs say a cocotb module takes, against its last three green test runs
    on main, give or take a third."""
    for module, said in re.findall(r"COCOTB_TEST_MODULES=(\w+)`[^.]*? in about (\d+) minutes",
                                   flat(text)):
        runs = [str(r["id"]) for r in green_runs("test.yaml")][:3]
        took = [sum(cocotb_seconds(r, module).values()) for r in runs]
        took = [s for s in took if s]
        if not took:
            yield module, f"no green test run on main logs {module}'s tests passing"
            continue
        minutes = sum(took) / len(took) / 60
        if abs(minutes - int(said)) > max(1, int(said) / 3):
            yield (f"in about {said} minutes",
                   f"{module} took {minutes:.0f} minutes in test runs {', '.join(runs)} "
                   f"({', '.join(f'{s / 60:.1f}' for s in took)}), the docs say about {said}")


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
            yield (f"{n} library firmwares",
                   f"{n} library firmwares, the kernel accepts {firmwares} in test/test_kernel.ml")
    for killed, valid in quoted["valid mutants"]:
        for n in quoted["equivalent mutants"]:
            if n != int(valid) - int(killed) or n != equivalent_mutants():
                yield (f"other {n} are",
                       f"{n} equivalent mutants, but {killed} of {valid} killed leaves "
                       f"{int(valid) - int(killed)} and test/mutation_allow.txt has "
                       f"{equivalent_mutants()}")
    for n in quoted["tiles"]:
        if n != tiles():
            yield f"{n} tiles", f"{n} tiles, info.yaml has {tiles()}"
    for n in numbers(r"tiles at (\d+) MHz", text):
        if n != clock_mhz():
            yield f"tiles at {n} MHz", f"{n} MHz, info.yaml has {clock_mhz()}"
    for n in numbers(r"(\d+)-bit (?:clock|free-running counter)", text):
        if n != isa("timer_bits"):
            yield f"{n}-bit", f"a {n}-bit clock, src/isa.ml has timer_bits = {isa('timer_bits')}"
    for n in numbers(r"(\d+)-word IHP", text):
        if n != sram()[1]:
            yield f"{n}-word IHP", f"a {n}-word macro, the chip's are {sram()[1]} words"
    depth = int(find(r"^let depth = (\d+)$", "src/host_fifo.ml")[1])
    for n in numbers(r"(\d+)-deep fifos", text):
        if n != depth:
            yield f"{n}-deep fifos", f"{n}-deep fifos, src/host_fifo.ml has depth = {depth}"
    for baud, mhz, period in re.findall(r"at (\d+) baud from the (\d+) MHz clock\. The host "
                                        r"sends the bit period, (\d+) cycles", text):
        if int(period) != round(int(mhz) * 1e6 / int(baud)):
            yield (f"{period} cycles", f"{period} cycles a bit, {mhz} MHz over {baud} baud is "
                   f"{round(int(mhz) * 1e6 / int(baud))}")
    for whole, num, den, baud, mhz in re.findall(r"(\d+) (\d+)/(\d+) for (\d+) baud at (\d+) MHz",
                                                 text):
        if abs(int(whole) + int(num) / int(den) - int(mhz) * 1e6 / int(baud)) > 1e-9:
            yield (f"{whole} {num}/{den}", f"{whole} {num}/{den} cycles a bit, {mhz} MHz over "
                   f"{baud} baud is {int(mhz) * 1e6 / int(baud):g}")
    transmitters = len(find(r"^DATA = (.*)$", "formal/Makefile")[1].split())
    for word in re.findall(r"all but (\w+) transmitters", text):
        if WORDS.get(word, word) != str(transmitters):
            yield (f"all but {word}", f"all but {word} transmitters, formal/Makefile's DATA "
                   f"proves the host's words on {transmitters}")
    for path, date in re.findall(r"`([\w./-]+)`[^.`]*? committed on (\d{4}-\d\d-\d\d)", text):
        added = git("log", "--diff-filter=A", "--format=%ad", "--date=short", "--", path)
        first = (added.stdout.split() or ["never"])[-1]
        if first != date:
            yield date, f"{path} committed on {date}, git first has it on {first}"


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
                    yield m[1], f"no rule in test/assemble/dune makes the edit {m[1]}"
            elif not line.startswith("$ ") and line != "..." and line not in printed:
                yield line, f"no test in test/assemble/ prints {line.strip()!r}"


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
        metrics = gds_numbers(run_id[1])[0] if ONLINE and run(run_id[1]) else None
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
        "Board": None,  # check_board holds it to the hashed ledger
    }
    for label in table.keys() - expected.keys():
        yield f"| {label} |", f"the table's {label} row has no check, add one to test/check_docs.py"
    for label, numbers in expected.items():
        if label not in table:
            yield f"the table has no {label} row"
        elif numbers is not None:
            said, sources = row_numbers(table[label][0]), row_numbers(" ".join(map(str, numbers)))
            if said != sources:
                said, sources = (", ".join(f"{n:g}" for n in ns) for ns in (said, sources))
                yield (f"| {label} |", f"the table's {label} row gives {said or 'no number'}, "
                       f"its sources {sources}")
    if "Process" in table and pdk() not in table["Process"][0].upper():
        yield "| Process |", (f"the table's Process row does not name {pdk()}, which gds.yaml "
                              "hardens on")


CHECKS = [check_paths, check_make, check_jobs, check_commits, check_counts, check_transcripts,
          check_glance]
ONLINE_CHECKS = [check_runs, check_gds, check_mutation, check_board, check_links,
                 check_demo_time]


def failures(docs):
    """{check: [what is wrong]} over every doc."""
    def wrong(check, doc, text):
        def say(why):
            needle, why = why if isinstance(why, tuple) else (None, why)
            n = needle is not None and line_of(text, needle)
            return f"{doc}:{n}: {why}" if n else f"{doc}: {why}"
        try:
            return [say(why) for why in check(doc, text)]
        except (Unreadable, evidence.Unverifiable) as e:
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
# the metrics of the cited gds run, which expire), and the doc if not the README
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
    ("a stale gds run", lambda text: every(text, r"[Gg]ds run \[?(\d{10,12})",
                                            lambda _: stale_gds_run()),
     "an older gds run of this chip"),
    # green, but it mutated an engine.ml that has changed since
    ("an old mutation run", lambda text: every(text, r"mutation run \[?(\d{10,12})",
                                                lambda _: "36642527804"), "gh"),
    ("a board date", first(r"passed (?:the [\w-]+ demo )?on (\d{4}-\d\d-\d\d)", bump), "gh"),
    ("the board edges", first(r"all (\d+) edges", bump), "gh"),
    ("the board baud", first(r"at (\d+) baud", bump), "gh"),
    ("a dead link", first(r"\]\(https://github\.com/[^)]*/issues/(\d+)\)", lambda n: n + "0000"),
     "gh"),
    ("a dead pages link", first(r"\]\((https://marcosash\.github\.io/[^)]*\w)/?\)",
                                lambda u: u + "x"), "gh"),
    ("the demo time", first(r"in about (\d+) minutes", lambda n: str(int(n) * 3 + 3)), "gh"),
    ("the transmitters", first(r"all but (\w+) transmitters",
                               lambda w: "seven" if w == "six" else "six"), None),
    ("a commit date", first(r"committed on (\d{4}-\d\d-\d\d)", bump), None),
    ("a bit period", first(r"the bit period,\s+(\d+) cycles", bump), None, "docs/info.md"),
    ("a fractional bit period", first(r"(\d+) \d+/\d+ for \d+ baud", bump), None, "docs/info.md"),
]


def every(text, pattern, change):
    """[text] with the token [pattern]'s first match groups changed everywhere it is."""
    m = re.search(pattern, text)
    return m and change(m[1]) and re.sub(rf"\b{m[1]}\b", change(m[1]), text)


def stale_gds_run():
    """A green gds run on main of this chip that is neither the newest nor kept, or None."""
    return next((r for r in chip_gds_runs()
                 if r != current_gds_run() and not evidence.gds_kept(r)), None)


def clear_caches():
    for f in [evidence.asset, evidence.unpacked, evidence.ledger, evidence.gds_kept,
              gds_numbers, fresh_gds, fresh_mutation]:
        f.cache_clear()


def tampered_pin(docs):
    """What fails with the board evidence pinned to another asset's hash."""
    real = evidence.pins
    pinned = real()
    board = next(k for k in pinned if k[1].startswith("board-evidence-"))
    other = next(sha for k, sha in pinned.items() if k != board)
    evidence.pins = lambda: {**pinned, board: other}
    clear_caches()
    try:
        return [name for name, found in failures(docs).items() if found]
    finally:
        evidence.pins = real
        clear_caches()


def generated_table(docs):
    """What fails with the README's table as test/results.py --readme-table writes it."""
    import results

    readme = docs["README.md"]
    table = next(u for u in re.split(r"\n\s*\n", readme) if u.startswith("|"))
    with contextlib.redirect_stderr(io.StringIO()):  # what it changed, which is nothing here
        fresh = results.readme_table(readme)
    return {name: found for name, found in
            failures({**docs, "README.md": readme.replace(table, fresh)}).items() if found}


def teeth():
    docs = read_docs()
    if any(failures(docs).values()):
        sys.exit("the docs fail as they are, so the teeth would prove nothing")
    cited = re.search(r"[Gg]ds run \[?(\d{10,12})", docs["README.md"])
    has = {None: True, "gh": ONLINE,
           "metrics": ONLINE and cited is not None and gds_numbers(cited[1])[0] is not None,
           "an older gds run of this chip": ONLINE and stale_gds_run() is not None}
    missed = []
    for what, tooth, needs, *doc in TEETH:
        doc = doc[0] if doc else "README.md"
        if not has[needs]:
            print(f"skip {what}, which needs {needs}")
            continue
        wrong = tooth(docs[doc])
        if not wrong or wrong == docs[doc]:
            sys.exit(f"the tooth for {what} finds nothing to change in {doc}")
        caught = [name for name, found in failures({**docs, doc: wrong}).items() if found]
        line = next(b for a, b in zip(docs[doc].splitlines(), wrong.splitlines()) if a != b)
        print(f"{'ok  ' if caught else 'FAIL'} {what}, caught by {', '.join(caught) or 'nothing'}")
        print(f"     {line.strip()[:88]}")
        if not caught:
            missed.append(what)
    if ONLINE:
        caught = tampered_pin(docs)
        print(f"{'ok  ' if caught else 'FAIL'} a tampered evidence pin, caught by "
              f"{', '.join(caught) or 'nothing'}")
        if not caught:
            missed.append("a tampered evidence pin")
        # not a tooth: the table the generator writes has to pass
        wrong = generated_table(docs)
        print(f"{'FAIL' if wrong else 'ok  '} test/results.py --readme-table writes a table "
              "that passes")
        for why in (w for found in wrong.values() for w in found):
            print(f"     {why}")
        if wrong:
            sys.exit("the table test/results.py --readme-table writes fails the checks")
    if missed:
        sys.exit(f"{len(missed)} wrong READMEs passed: {', '.join(missed)}")


def main():
    global ONLINE, EXTERNAL
    p = argparse.ArgumentParser()
    p.add_argument("--offline", action="store_true", help="skip what needs gh or the network")
    p.add_argument("--teeth", action="store_true", help="check that wrong READMEs fail")
    p.add_argument("--external-links", action="store_true",
                   help="ask every link's host, not just GitHub's")
    args = p.parse_args()
    ONLINE, EXTERNAL = not args.offline, args.external_links
    if not ONLINE:
        print("skip run ids, gds metrics, mutation scores, board evidence and links (offline)")
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
