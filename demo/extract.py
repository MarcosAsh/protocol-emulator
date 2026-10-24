# SPDX-License-Identifier: Apache-2.0
# The intake's double extraction: two headless agents read the spec's timing limits blind
# (each confined to its own copy of the spec, neither sees the other's) and their tables are
# compared field by field. Any disagreement stops the intake with "limit disputed, DOC p.N" and
# keeps both readings in disputed.tsv; a person who reads the page may fill its ruling column
# and settle the run with rule. Writes limits.tsv (agreed), disputed.tsv, ruled.tsv and
# agreement.txt in RUN_DIR and a row of agreement.tsv beside it. Exit 0 agreed, 3 disputed.
# Usage: python3 demo/extract.py run RUN_DIR DOC [--budget USD] [--model M] [--dry-run]
#        python3 demo/extract.py rule RUN_DIR DOC RULINGS   RULINGS: disputed.tsv, ruled
import argparse
import csv
import datetime
import hashlib
import json
import math
import os
import re
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PROMPT = os.path.join(HERE, "extract_prompt.txt")
SPEC_FILES = ["spec.txt", "spec.index", "spec.pdf"]
COLUMNS = ["symbol", "parameter", "condition", "min", "typ", "max", "unit", "page", "where"]
# what each row's comparison covers; the unit is folded into min, typ and max
FIELDS = ["min", "typ", "max", "page", "where"]
DOCUMENT_FIELDS = ["revision", "date"]
# each unit's quantity and scale to it
UNITS = {
    "s": ("s", 1), "ms": ("s", 1e-3), "us": ("s", 1e-6), "µs": ("s", 1e-6), "μs": ("s", 1e-6),
    "ns": ("s", 1e-9), "ps": ("s", 1e-12),
    "hz": ("hz", 1), "khz": ("hz", 1e3), "mhz": ("hz", 1e6), "ghz": ("hz", 1e9),
    "bit/s": ("bit/s", 1), "bps": ("bit/s", 1), "b/s": ("bit/s", 1),
    "kbit/s": ("bit/s", 1e3), "kbps": ("bit/s", 1e3), "kb/s": ("bit/s", 1e3),
    "mbit/s": ("bit/s", 1e6), "mbps": ("bit/s", 1e6),
    "baud": ("bd", 1), "bd": ("bd", 1), "kbaud": ("bd", 1e3), "kbd": ("bd", 1e3),
}
ABSENT = "(no row)"
# a ruling that a field is blank, as an empty ruling cell is no ruling
EMPTY = "(empty)"


def squash(text):
    return re.sub(r"[^0-9a-z]", "", text.lower())


def symbol_key(row):
    return squash(row["symbol"]) or squash(row["parameter"])


def condition_key(row):
    text = re.sub(r"\(?\bnotes?\s*[0-9]+(\s*(,|and)\s*[0-9]+)*\)?", "", row["condition"].lower())
    return squash(text)


def value(cell, unit, implied=""):
    """A min, typ or max as (bound, quantity, number in that quantity's base unit), or its
    squashed text when it is not a plain number. A bound its column already says (">" under
    min) is dropped."""
    text = cell.strip().replace("−", "-").replace(",", "")
    if implied and text[:1] in implied:
        text = text.lstrip(implied + "=").strip()
    if text in ("", "-", "--", "—", "–", "n/a", "na"):
        return None
    match = re.fullmatch(r"([<>≤≥]=?)?\s*([-+]?[0-9]*\.?[0-9]+)\s*([a-zA-Zµμ/]*)", text)
    if not match:
        return squash(text) + "|" + squash(unit)
    bound, number, own_unit = match.groups()
    quantity, scale = UNITS.get(re.sub(r"\s", "", own_unit or unit).lower(), (squash(unit), 1))
    return (bound or "", quantity, float(number) * scale)


def same_value(a, b):
    if isinstance(a, tuple) and isinstance(b, tuple):
        return a[:2] == b[:2] and math.isclose(a[2], b[2], rel_tol=1e-9, abs_tol=1e-18)
    return a == b


def page(cell):
    digits = re.search(r"[0-9]+", cell)
    return int(digits.group()) if digits else None


def where(cell):
    """A table or figure label, a numbered section, or the squashed text."""
    text = cell.lower()
    label = re.search(r"\b(table|figure|fig)\.?\s*([0-9]+(?:[-.][0-9]+)*)", text)
    if label:
        return ("figure" if label.group(1).startswith("fig") else "table") + " " + label.group(2)
    section = re.match(r"\s*(?:section|§)?\s*([0-9]+(?:\.[0-9]+)*)\.?(\s|$)", text)
    if section:
        return "section " + section.group(1)
    return squash(cell)


def revision(cell):
    return re.sub(r"^(revision|rev|version|ver|v)", "", squash(cell))


def same_revision(a, b):
    """Equal, or one is the other's document number with its revision letter (DS20001203W, W)."""
    short, long = sorted([revision(a), revision(b)], key=len)
    if short == long:
        return True
    return bool(short) and long.endswith(short) and long[:-len(short)][-1:].isdigit()


def date(cell):
    """A printed date as a datetime.date when it has one of the usual shapes, else squashed."""
    text = re.sub(r"\s+", " ", cell.replace(",", " ")).strip()
    for shape in ("%Y-%m-%d", "%Y/%m/%d", "%Y.%m.%d", "%d %B %Y", "%B %d %Y", "%d %b %Y",
                  "%b %d %Y", "%d-%b-%Y", "%B %Y", "%b %Y", "%m/%Y"):
        try:
            return datetime.datetime.strptime(text, shape).date()
        except ValueError:
            pass
    return squash(cell)


def same(field, a, b):
    if field in ("min", "typ", "max"):
        implied = {"min": ">≥", "max": "<≤"}.get(field, "")
        return same_value(value(a[field], a["unit"], implied), value(b[field], b["unit"], implied))
    if field == "page":
        return page(a[field]) == page(b[field])
    if field == "where":
        return where(a[field]) == where(b[field])
    if field == "revision":
        return same_revision(a[field], b[field])
    if field == "date":
        return date(a[field]) == date(b[field])
    return squash(a[field]) == squash(b[field])


def parse(text):
    """A reading's document line and rows, from the agent's text between BEGIN LIMITS and END
    LIMITS (or a whole table file)."""
    lines = text.splitlines()
    if any(line.strip() == "BEGIN LIMITS" for line in lines):
        start = next(i for i, line in enumerate(lines) if line.strip() == "BEGIN LIMITS")
        end = next((i for i in range(start, len(lines)) if lines[i].strip() == "END LIMITS"),
                   None)
        if end is None:
            raise ValueError("no END LIMITS line")
        lines = lines[start + 1:end]
    lines = [line.strip("\r") for line in lines if line.strip() and not line.startswith("```")]
    document, rows = None, []
    for line in lines:
        cells = [cell.strip() for cell in line.split("\t")]
        if cells[0] == "document":
            cells += [""] * (4 - len(cells))
            document = dict(zip(["title"] + DOCUMENT_FIELDS, cells[1:4]))
        elif cells[0] == "symbol":
            continue
        elif len(cells) >= 2:
            cells += [""] * (len(COLUMNS) - len(cells))
            rows.append(dict(zip(COLUMNS, cells[:len(COLUMNS)])))
    if document is None:
        raise ValueError("no document line")
    if not rows:
        raise ValueError("no limit rows")
    return {"document": document, "rows": rows}




def named(row):
    """Whether the symbol column holds a parameter's name, the spec printing no symbol."""
    return " " in row["symbol"].strip()


def near(a, b):
    """At most one character inserted, dropped or changed (I2C-bus against pdftotext's I C-bus)."""
    if abs(len(a) - len(b)) > 1:
        return False
    i = next((i for i, (x, y) in enumerate(zip(a, b)) if x != y), min(len(a), len(b)))
    return a[i + 1:] == b[i + 1:] or a[i + 1:] == b[i:] or a[i:] == b[i + 1:]


def pair(a_rows, b_rows):
    """Rows of the two readings matched by symbol and condition. Then, among the leftovers, the
    same symbol, page and place with a condition one character apart, the same symbol with the
    same min, typ and max (the condition worded differently), and two names with the same
    numbers, page and place (the name worded differently). Then each leftover alone."""
    def keyed(rows):
        seen, out = {}, []
        for row in rows:
            key = (symbol_key(row), condition_key(row))
            seen[key] = seen.get(key, 0) + 1
            out.append((key + (seen[key],), row))
        return out

    a_keyed, b_keyed = keyed(a_rows), keyed(b_rows)
    b_by_key = dict(b_keyed)
    pairs, a_left = [], []
    for key, row in a_keyed:
        if key in b_by_key:
            pairs.append((row, b_by_key.pop(key)))
        else:
            a_left.append(row)
    b_left = [row for key, row in b_keyed if key in b_by_key]
    twins = [
        lambda a, b: symbol_key(a) == symbol_key(b) and near(condition_key(a), condition_key(b))
        and all(same(f, a, b) for f in ("page", "where")),
        lambda a, b: symbol_key(a) == symbol_key(b)
        and all(same(f, a, b) for f in ("min", "typ", "max")),
        lambda a, b: named(a) and named(b) and all(same(f, a, b) for f in FIELDS),
    ]
    for twin in twins:
        for row in list(a_left):
            match = next((b for b in b_left if twin(row, b)), None)
            if match is not None:
                pairs.append((row, match))
                a_left.remove(row)
                b_left.remove(match)
    return pairs + [(row, None) for row in a_left] + [(None, row) for row in b_left]


def restated(rows):
    """[rows] without a row that repeats an earlier one's symbol, condition and numbers (a note
    restating a table's limit)."""
    kept = []
    for row in rows:
        if not any(symbol_key(k) == symbol_key(row) and condition_key(k) == condition_key(row)
                   and all(same(f, k, row) for f in ("min", "typ", "max")) for k in kept):
            kept.append(row)
    return kept


def ruling_key(row, field):
    return (symbol_key(row), condition_key(row), field)


def rulings(path):
    """A person's rulings on disputed fields, read off the page: disputed.tsv's symbol,
    condition and field columns and a ruling column holding the value, "(empty)" for a field
    the page leaves blank, or "(no row)"."""
    with open(path, newline="") as f:
        return {ruling_key(r, r["field"]): "" if r["ruling"] == EMPTY else r["ruling"]
                for r in csv.DictReader(f, delimiter="\t") if r.get("ruling", "") != ""}


def compare(a, b, ruled=None):
    """Every compared field's agreement, the disputes with both readings, the fields settled by
    [ruled] (a person's rulings), and the agreed rows."""
    ruled = ruled or {}
    disputes, settled, agreed, compared, rows = [], [], 0, 0, []
    for field in DOCUMENT_FIELDS:
        compared += 1
        if same(field, a["document"], b["document"]):
            agreed += 1
        else:
            dispute = {"symbol": "document", "condition": "", "field": field,
                       "a": a["document"][field], "b": b["document"][field], "pages": [1]}
            ruling = ruled.get(ruling_key(dispute, field))
            if ruling is None:
                disputes.append(dispute)
            else:
                settled.append(dict(dispute, ruling=ruling))
    for row_a, row_b in pair(restated(a["rows"]), restated(b["rows"])):
        either = row_a or row_b
        pages = sorted({page(r["page"]) or 0 for r in (row_a, row_b) if r})
        row, open_fields = dict(either), []
        if row_a and row_b and condition_key(row_a) != condition_key(row_b):
            row["condition"] = row_a["condition"] + " | " + row_b["condition"]
        for field in FIELDS:
            compared += 1
            if row_a and row_b and same(field, row_a, row_b):
                agreed += 1
                continue
            # a row with no symbol is keyed by its parameter, so disputed.tsv names it so
            dispute = {"symbol": either["symbol"] or either["parameter"],
                       "condition": either["condition"],
                       "field": field, "a": row_a[field] if row_a else ABSENT,
                       "b": row_b[field] if row_b else ABSENT, "pages": pages}
            ruling = ruled.get(ruling_key(either, field))
            if ruling is None:
                open_fields.append(dispute)
            else:
                settled.append(dict(dispute, ruling=ruling))
                row[field] = ruling
        disputes += open_fields
        if not open_fields and ABSENT not in [row[f] for f in FIELDS]:
            rows.append(row)
    disputes.sort(key=lambda d: (d["pages"], d["symbol"], d["condition"],
                                 FIELDS.index(d["field"]) if d["field"] in FIELDS else -1))
    return {"disputes": disputes, "settled": settled, "agreed": agreed, "compared": compared,
            "rows": rows}


def verdict(doc, result):
    if result["disputes"]:
        pages = result["disputes"][0]["pages"]
        return "limit disputed, %s p.%s" % (doc, "/".join(str(p) for p in pages))
    ruled = ", %d fields ruled by hand" % len(result["settled"]) if result["settled"] else ""
    return "limits agreed, %d rows%s" % (len(result["rows"]), ruled)


def agreement(result):
    return "agreement %d/%d fields (%.1f%%), %d rows agreed, %d fields disputed, %d ruled" % (
        result["agreed"], result["compared"], 100.0 * result["agreed"] / result["compared"],
        len(result["rows"]), len(result["disputes"]), len(result["settled"]))


def result_text(path):
    """The agent's final message in a stream-json transcript, or the file itself."""
    text = open(path, errors="replace").read()
    last = None
    for line in text.splitlines():
        try:
            message = json.loads(line)
        except ValueError:
            continue
        if isinstance(message, dict) and message.get("type") == "result":
            last = str(message.get("result", ""))
    return text if last is None else last


def tsv(path, head, rows):
    with open(path, "w", newline="") as f:
        out = csv.writer(f, delimiter="\t", lineterminator="\n")
        out.writerow(head)
        out.writerows(rows)


def write(run_dir, result, line):
    tsv(os.path.join(run_dir, "limits.tsv"), COLUMNS,
        [[row[c] for c in COLUMNS] for row in result["rows"]])
    head = ["symbol", "condition", "field", "reading a", "reading b", "page"]
    tsv(os.path.join(run_dir, "disputed.tsv"), head + ["ruling"],
        [[d["symbol"], d["condition"], d["field"], d["a"], d["b"],
          "/".join(str(p) for p in d["pages"]), ""] for d in result["disputes"]])
    tsv(os.path.join(run_dir, "ruled.tsv"), head + ["ruling"],
        [[d["symbol"], d["condition"], d["field"], d["a"], d["b"],
          "/".join(str(p) for p in d["pages"]), d["ruling"]] for d in result["settled"]])
    with open(os.path.join(run_dir, "agreement.txt"), "w") as f:
        f.write(line + "\n" + agreement(result) + "\n")


def ledger(path, doc, spec, result, line):
    new = not os.path.exists(path)
    digest = hashlib.sha256(open(spec, "rb").read()).hexdigest() if os.path.exists(spec) else ""
    with open(path, "a", newline="") as f:
        out = csv.writer(f, delimiter="\t", lineterminator="\n")
        if new:
            out.writerow(["time", "doc", "spec sha256", "agreed", "compared", "ruled", "verdict"])
        out.writerow([datetime.datetime.now().astimezone().isoformat(timespec="seconds"), doc,
                      digest, result["agreed"], result["compared"], len(result["settled"]),
                      line])


def reader(run_dir, name, budget, model):
    """One blind reader: its own directory holding a copy of the spec, and the claude command
    whose file tools reach only there."""
    own = os.path.join(run_dir, "read-" + name)
    os.makedirs(own, exist_ok=True)
    for f in SPEC_FILES:
        if os.path.exists(os.path.join(run_dir, f)):
            shutil.copy(os.path.join(run_dir, f), own)
    command = ["claude", "-p", "--restricted", "--tools", "Read", "--strict-mcp-config",
               "--no-session-persistence", "--output-format", "stream-json", "--verbose",
               "--max-budget-usd", str(budget)]
    if model:
        command += ["--model", model]
    return own, command


def settle(run_dir, doc, rulings_path=None):
    """Compares the two readings in [run_dir], with a person's rulings if given, and records
    the outcome there and in agreement.tsv beside it."""
    readings = []
    for name in "ab":
        transcript = os.path.join(run_dir, "read-" + name, "transcript.jsonl")
        try:
            readings.append(parse(result_text(transcript)))
        except (OSError, ValueError) as e:
            print("failed: reader %s gave no table (%s), see %s" % (name, e, transcript))
            return 1
    result = compare(*readings, ruled=rulings(rulings_path) if rulings_path else None)
    line = verdict(doc, result)
    write(run_dir, result, line)
    ledger(os.path.join(os.path.dirname(os.path.abspath(run_dir)), "agreement.tsv"), doc,
           os.path.join(run_dir, "spec.txt"), result, line)
    print(line)
    print(agreement(result))
    for d in result["disputes"]:
        print("  p.%s %s [%s] %s: a %r, b %r" % ("/".join(str(p) for p in d["pages"]),
                                                 d["symbol"], d["condition"], d["field"], d["a"],
                                                 d["b"]))
    return 3 if result["disputes"] else 0


def run(run_dir, doc, budget, models, dry_run, timeout):
    readers = [reader(run_dir, name, budget, model) for name, model in zip("ab", models)]
    if dry_run:
        for own, command in readers:
            print("would run in %s: %s < %s > transcript.jsonl" % (own, " ".join(command), PROMPT))
        return 0
    running = [subprocess.Popen(command, cwd=own, stdin=open(PROMPT),
                                stdout=open(os.path.join(own, "transcript.jsonl"), "w"),
                                stderr=open(os.path.join(own, "claude.err"), "w"))
               for own, command in readers]
    for process in running:
        try:
            process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            process.kill()
    return settle(run_dir, doc)


def main():
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    p = sub.add_parser("run")
    p.add_argument("run_dir")
    p.add_argument("doc")
    p.add_argument("--budget", type=float, default=5)
    p.add_argument("--model", action="append", default=[],
                   help="reader a's model, then b's; one is both, none is claude's default")
    p.add_argument("--timeout", type=float, default=3600)
    p.add_argument("--dry-run", action="store_true")
    p = sub.add_parser("rule")
    p.add_argument("run_dir")
    p.add_argument("doc")
    p.add_argument("rulings")
    args = parser.parse_args()
    if args.command == "rule":
        sys.exit(settle(args.run_dir, args.doc, args.rulings))
    models = (args.model * 2)[:2] if args.model else [None, None]
    sys.exit(run(args.run_dir, args.doc, args.budget, models, args.dry_run, args.timeout))


if __name__ == "__main__":
    main()
