# SPDX-License-Identifier: Apache-2.0
# Evidence that outlives CI's 90 days: release assets pinned by test/evidence.sha256, the
# board ledgers inside them and the gds runs they keep. Each asset is downloaded once into
# the cache and checked against its pin every time it is read. Needs gh.
# EVIDENCE_CACHE moves the cache from ~/.cache/protocol-emulator.
import csv
import hashlib
import io
import json
import os
import re
import subprocess
import tarfile
from functools import cache
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PINS = ROOT / "test/evidence.sha256"
CACHE = Path(os.environ.get("EVIDENCE_CACHE", Path.home() / ".cache/protocol-emulator"))
REPO = "MarcosAsh/protocol-emulator"


class Unverifiable(Exception):
    """Evidence that is not pinned, cannot be fetched, or does not match its pin."""


@cache
def pins():
    """{(release tag, asset name): sha256}, as test/evidence.sha256 has them."""
    found = {}
    for line in PINS.read_text().splitlines():
        if line.strip() and not line.startswith("#"):
            sha, path = line.split(maxsplit=1)
            tag, name = path.lstrip("*").split("/", 1)
            found[tag, name] = sha
    return found


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


def release_url(tag):
    return f"https://github.com/{REPO}/releases/tag/{tag}"


@cache
def asset(tag, name):
    """The pinned asset on disk, downloaded once and checked against its pin."""
    want = pins().get((tag, name))
    if want is None:
        raise Unverifiable(f"{tag}/{name} is not pinned in test/evidence.sha256")
    path = CACHE / "evidence" / want / name
    if not path.exists():
        path.parent.mkdir(parents=True, exist_ok=True)
        done = subprocess.run(["gh", "release", "download", tag, "-R", REPO, "-p", name,
                               "-D", str(path.parent), "--clobber"],
                              capture_output=True, text=True)
        if done.returncode != 0:
            raise Unverifiable(f"release {tag} gives no {name}: {done.stderr.strip()}")
    if sha256(path) != want:
        path.unlink()
        raise Unverifiable(f"{tag}/{name} does not match its sha256 in test/evidence.sha256")
    return path


@cache
def unpacked(tag, name):
    """The pinned tarball unpacked, every file its own SHA256SUMS lists checked once."""
    tarball = asset(tag, name)
    out = CACHE / "unpacked" / pins()[tag, name]
    if not (out / ".checked").exists():
        out.mkdir(parents=True, exist_ok=True)
        with tarfile.open(tarball) as t:
            t.extractall(out, filter="data")
        for sums in out.rglob("SHA256SUMS"):
            for line in sums.read_text().splitlines():
                sha, path = line.split(maxsplit=1)
                if sha256(sums.parent / path.lstrip("*")) != sha:
                    raise Unverifiable(f"{tag}/{name}: {path} does not match "
                                       f"{sums.relative_to(out)}")
        (out / ".checked").touch()
    return out


@cache
def ledger():
    """Each demo run the pinned board evidence holds: its ledger.txt fields, the python/
    scripts run.txt shows it running, where it is, and the release that keeps it."""
    entries = []
    for tag, name in sorted(pins()):
        if not name.startswith("board-evidence-"):
            continue
        root = unpacked(tag, name)
        for f in sorted(root.rglob("ledger.txt")):
            entry = dict(re.findall(r"^(\w+): (.*)$", f.read_text(), re.M))
            run = f.parent / "run.txt"
            entry["scripts"] = re.findall(r" run (python/\w+\.py)",
                                          run.read_text() if run.exists() else "")
            entry.update(dir=f.parent, release=tag, path=str(f.parent.relative_to(root)))
            entries.append(entry)
    return entries


def passes(demo):
    """The ledger's passes of [demo], a name such as self_timing or a script such as
    python/demo_self_timing.py, newest first."""
    found = [e for e in ledger() if e.get("result") == "PASS"
             and (e.get("demo") == demo or demo in e["scripts"])]
    return sorted(found, key=lambda e: e.get("time", ""), reverse=True)


def edges(entry):
    """[(label, edges, all on time)] from a timing demo's log, one per capture: the edges
    of each measured row, and whether every row says ok."""
    log = entry["dir"] / f"{entry['demo']}.log"
    if not log.exists():
        return []
    found = []
    for label, body in re.findall(r"^(\w+), \d+ SPI frames:\n(.*?)(?=^\w+, \d+ SPI|\Z)",
                                  log.read_text(), re.M | re.S):
        # a byte's predicted row, then its measured row
        lines = body.splitlines()
        rows = [lines[i + 1] for i, r in enumerate(lines[:-1]) if re.match(r"'.' 0x\w\w ", r)]
        on_time = bool(rows) and all(r.rstrip().endswith(" ok") for r in rows)
        found.append((label, sum(len(re.findall(r"\b\d+\b", r)) for r in rows), on_time))
    return found


@cache
def gds_kept(run_id):
    """The metrics.csv row of a gds run a pinned release keeps, with that release, or
    None when no pinned asset is named for the run."""
    for tag, name in sorted(pins()):
        if not re.fullmatch(rf"gds-[\w.-]*-run{run_id}\.tar\.gz", name):
            continue
        with tarfile.open(asset(tag, name)) as t:
            members = {Path(m.name).relative_to(Path(m.name).parts[0]).as_posix(): m
                       for m in t.getmembers() if m.isfile()}
            for wanted in ["metrics.csv", "submission/commit_id.json"]:
                if wanted not in members:
                    raise Unverifiable(f"{tag}/{name} has no {wanted}")
            row = next(csv.DictReader(io.TextIOWrapper(t.extractfile(members["metrics.csv"]))))
            commit = json.load(t.extractfile(members["submission/commit_id.json"]))
        if not commit.get("workflow_url", "").endswith(f"/runs/{run_id}"):
            raise Unverifiable(f"{tag}/{name} was made by {commit.get('workflow_url')}, "
                               f"not run {run_id}")
        return {**row, "release": tag, "commit_full": commit["commit"]}
    return None
