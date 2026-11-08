# SPDX-License-Identifier: Apache-2.0
# Builds one static page per protocol plus an index, from data files only: the output of
# write_corpus.exe (firmware.tsv, limits.tsv, firmware/), test/<protocol>.ml and
# demo/speed.tsv. These inputs are optional, and a page says when one is missing: clock
# windows (python/clock_cliffs.py). Board ledgers, named-refusal pictures and agent
# transcripts get a section only where there is one.
# Writes corpus.sha256 next to the pages in sha256sum's format, and --check verifies a tree
# against it. There are no timestamps, so the same inputs give the same bytes.
# Usage: python3 test/corpus.py --data DIR --out DIR [--speed TSV] [--ledger TSV]...
#            [--witnesses DIR] [--matrix FILE] [--cliffs FILE] [--refusals DIR]
#            [--transcripts DIR]
#        python3 test/corpus.py --check DIR
import argparse
import ast
import csv
import hashlib
import html
import json
import shutil
import sys
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = "corpus.sha256"
STAGES = ["spec", "file", "certificate", "bench"]
WORKFLOW = ("https://github.com/MarcosAsh/protocol-emulator/blob/main/"
            ".github/workflows/ocaml.yaml")
# the protocol page each ledger demo belongs on; demos not listed here go on the index
DEMO_PROTOCOL = {
    "swd": "swd", "neopixel": "ws2812", "eeprom": "i2c", "eeprom_stretch": "i2c",
    "ds18b20": "one_wire", "can": "can", "can_node": "can_node", "keyboard": "usb",
    "self_timing": "uart", "flash": "spi_cs", "sweep_i2c_100k": "i2c",
    "sweep_i2c_400k": "i2c", "sweep_spi_mode0": "spi_cs", "sweep_spi_mode3": "spi_cs",
}
SPEED_NOTE = ("Times are the first mark of each stage in demo/speed.tsv; a protocol "
              "nobody timed has no row.")
# specs written for the blind rehearsal of 2026-10-18, with no public datasheet behind them
REHEARSAL = ("snorble", "plinkoo", "frumbleglide")
FLEXIBILITY = "../flexibility.html"


def spec_ids(tsv):
    """The protocol ids a demo/*_specs.tsv lists, under the corpus's names. The library's swd
    entered after the seal, so the held-out SWD is swd_blind."""
    ids = [line.split("\t")[0] for line in (ROOT / tsv).read_text().splitlines()
           if line and not line.startswith("#")]
    return [{"swd": "swd_blind"}.get(i, i.replace("-", "_")) for i in ids]


ORIGIN = {
    **{n: "drawn" for n in spec_ids("demo/corpus_specs.tsv")},
    **{n: "held out" for n in spec_ids("demo/heldout_specs.tsv")},
    **{n: "invented spec" for n in REHEARSAL},
}
# said on the index and on each page of that origin
ORIGINS = {
    "drawn": "Drawn: picked from sigrok's decoders by drand round 33346612 "
    "(demo/corpus_draw_33346612.json).",
    "held out": "Held out: sealed in test/heldout.sha256 on 2026-10-02 and opened on "
    "2026-11-02 (test/heldout.txt).",
    "invented spec": "Invented spec: written for a blind rehearsal on 2026-10-18, with no "
    "public datasheet.",
}
RUNS_ON = f'The drawn and held-out runs are on <a href="{FLEXIBILITY}">Flexibility</a>.'

CSS = """
:root { --bg: #fff; --fg: #1a1a1a; --muted: #666; --code: #f4f4f4; --line: #ddd;
  --bad: #b3261e; --ok: #1b6e2d; }
@media (prefers-color-scheme: dark) {
  :root { --bg: #161616; --fg: #e8e8e8; --muted: #9a9a9a; --code: #232323;
    --line: #333; --bad: #f2837c; --ok: #7fd18f; }
}
* { box-sizing: border-box; }
body { font: 14px/1.4 system-ui, sans-serif; margin: 0 auto; padding: 16px;
  max-width: 64rem; background: var(--bg); color: var(--fg); }
a { color: inherit; }
code, pre { font: 12px/1.4 ui-monospace, monospace; background: var(--code); }
pre { padding: 8px; overflow-x: auto; max-height: 28rem; }
table { border-collapse: collapse; display: block; overflow-x: auto; }
th, td { border: 1px solid var(--line); padding: 2px 6px; text-align: left; }
.muted { color: var(--muted); }
.bad { color: var(--bad); font-weight: 600; }
.ok { color: var(--ok); }
img { max-width: 100%; background: #fff; }
"""


def read_tsv(path):
    with open(path, newline="") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def esc(x):
    return html.escape(str(x))


def page(title, body, up=None):
    nav = '<a href="../">protocol-emulator</a>'
    if up:
        nav += f' / <a href="{up}">all protocols</a>'
    return (f'<!doctype html>\n<html lang="en">\n<head>\n<meta charset="utf-8">\n'
            f'<meta name="viewport" content="width=device-width, initial-scale=1">\n'
            f'<meta name="color-scheme" content="light dark">\n<title>{esc(title)}</title>\n'
            f'<link rel="icon" href="data:,">\n<style>{CSS}</style>\n</head>\n<body>\n'
            f'<p>{nav}</p>\n<h1>{esc(title)}</h1>\n{body}\n</body>\n</html>\n')


def table(head, rows, cls=None):
    if not rows:
        return ""
    out = ["<table><tr>" + "".join(f"<th>{esc(h)}</th>" for h in head) + "</tr>"]
    for r in rows:
        c = f' class="{cls(r)}"' if cls and cls(r) else ""
        out.append(f"<tr{c}>" + "".join(f"<td>{x}</td>" for x in r) + "</tr>")
    out.append("</table>")
    return "\n".join(out)


def section(name, body):
    return f"<h2>{esc(name)}</h2>\n{body}\n"


def missing(what):
    return f'<p class="muted">Not available: {esc(what)}.</p>'


def took(a, b):
    """The time from a to b in minutes, or in hours or days once it runs that long."""
    if a is None or b is None:
        return "-"
    m = (b - a).total_seconds() / 60
    if m < 120:
        return "%.1f min" % m
    return "%.1f h" % (m / 60) if m < 48 * 60 else "%.1f days" % (m / 60 / 24)


def literal(path, names):
    """The list assignments named in names, read from a data module without running it."""
    found = {}
    for node in ast.parse(Path(path).read_text()).body:
        if isinstance(node, ast.Assign) and len(node.targets) == 1:
            t = node.targets[0]
            if isinstance(t, ast.Name) and t.id in names:
                found[t.id] = ast.literal_eval(node.value)
    return found


class Inputs:
    def __init__(self, a):
        data = Path(a.data)
        self.firmware = read_tsv(data / "firmware.tsv")
        self.limits = read_tsv(data / "limits.tsv")
        self.data = data
        self.speed = {}
        if a.speed and Path(a.speed).exists():
            for r in read_tsv(a.speed):
                when = datetime.fromisoformat(r["time"]).astimezone()
                s = self.speed.setdefault(r["protocol"], {})
                s.setdefault(r["stage"], (when, r["note"], r["time"]))
        self.ledgers = []
        for path in a.ledger or []:
            for r in read_tsv(path):
                # demo/bench_run.py's rows name their protocol and expect PASS
                r.setdefault("expected", "PASS")
                self.ledgers.append((Path(path), r))
        # test/board's runs; CI re-checks their witness.json (demo/witness.py)
        self.witnesses = []
        if a.witnesses and Path(a.witnesses).is_dir():
            for path in sorted(Path(a.witnesses).glob("*/witness.json")):
                self.witnesses.append((path.parent.name, json.loads(path.read_text())))
        self.matrix = (set(Path(a.matrix).read_text().split()) if a.matrix else
                       {r["firmware"] for r in self.firmware
                        if r["class"] in ("certified", "time_triggered")})
        self.cliffs = literal(a.cliffs, {"LIMITS", "WINDOWS"}) if a.cliffs else None
        self.refusals = Path(a.refusals) if a.refusals else None
        self.transcripts = Path(a.transcripts) if a.transcripts else None


def protocols(inp):
    names = []
    for r in inp.firmware:
        if r["protocol"] not in names:
            names.append(r["protocol"])
    return names


def ledger_protocol(r):
    """The protocol a ledger row names, else DEMO_PROTOCOL's entry for its demo, else the
    demo's own name."""
    return r.get("protocol") or DEMO_PROTOCOL.get(r["demo"], r["demo"])


def ledger_rows(inp, name):
    """Ledger rows for protocol name."""
    return [(p, r) for p, r in inp.ledgers if ledger_protocol(r) == name]


def witness_rows(inp, name):
    """test/board's witnesses for protocol name."""
    return [(d, w) for d, w in inp.witnesses if ledger_protocol(w) == name]


def board_runs(inp, name):
    """The number of distinct bench runs for protocol name. A ledger row and the witness
    from the same run count once, matched by the run's SHA256SUMS."""
    seen = {r.get("sums_sha256") or id(r) for _, r in ledger_rows(inp, name)}
    return len(seen | {w["sums_sha256"] for _, w in witness_rows(inp, name)})


def witness_table(rows):
    body = [[esc(d), esc(w["time"]), esc(w["demo"]), esc(w["result"]), esc(w["commit"][:10]),
             # eth_rx judges frames, not timing windows
             esc("%d of %d" % (sum(t["verdict"] == "proved" for t in w["timing"]),
                               len(w["timing"])) if "timing" in w else "-"),
             esc("; ".join(w["teeth"]))] for d, w in rows]
    return table(["test/board", "time", "demo", "result", "commit", "windows proved",
                  "teeth"], body, lambda r: "bad" if r[3] != "PASS" else None)


def ledger_table(rows):
    body = [[esc(p.parent.name), esc(r["date"]), esc(r["demo"]), esc(r["result"]),
             esc(r["expected"]), esc(r["commit"][:10]), esc(r["evidence"] or "-")]
            for p, r in rows]
    return table(["ledger", "date", "demo", "result", "expected", "commit", "evidence"],
                 body, lambda r: "bad" if r[3] != r[4] else None)


def failed_ledger(r):
    return r["result"] != r["expected"]


def protocol_page(inp, name, out):
    fw = [r for r in inp.firmware if r["protocol"] == name]
    names = sorted({r["firmware"] for r in fw})
    limits = [r for r in inp.limits if r["protocol"] == name]
    parts = []
    if name in ORIGIN:
        parts.append(f"<p>{esc(ORIGINS[ORIGIN[name]])}"
                     + (f" {RUNS_ON}" if ORIGIN[name] != "invented spec" else "") + "</p>")
    # spec source
    sheets = sorted({(r["part"], r["document"], r["page"]) for r in limits})
    parts.append(section("Spec source", table(
        ["part", "document", "page"], [[esc(x) for x in s] for s in sheets])
        if sheets else missing("no datasheet limits for this protocol")))
    # limits
    parts.append(section("Datasheet limits", table(
        ["firmware", "parameter", "limit", "bound by", "needs (cycles)", "bound (cycles)",
         "bound (ns)", "result", "margin", "sheet"],
        [[esc(r["firmware"]), esc(r["parameter"]), esc(f'{r["side"]} {r["limit_ns"]} ns'),
          esc(r["bound_by"]), esc(r["needed_cycles"]), esc(r["bound_cycles"]),
          esc(r["bound_ns"]), esc(r["result"]), esc(r["margin"]),
          esc(f'{r["document"]} {r["page"]}')] for r in limits],
        lambda r: "bad" if r[7] == "FAIL" else None)
        if limits else missing("no limits")))
    # protocol file and firmware
    src = ROOT / "test" / f"{name}.ml"
    body = (f"<details><summary>test/{esc(name)}.ml</summary><pre>"
            f"{esc(src.read_text())}</pre></details>" if src.exists()
            else missing(f"test/{name}.ml"))
    for r in fw:
        text = (inp.data / "firmware" / r["source"]).read_text()
        clock = "" if r["clock_hz"] == "-" else f', {int(r["clock_hz"]) / 1e6:g} MHz'
        body += (f"\n<details><summary>{esc(r['class'])} firmware {esc(r['firmware'])}"
                 f"{esc(clock)}</summary><pre>{esc(text)}</pre></details>")
    parts.append(section("Protocol file and firmware", body))
    # certificate
    link = f'<a href="{WORKFLOW}">ocaml.yaml</a>'
    items = []
    for n in names:
        if n in inp.matrix:
            items.append(f"<li><code>{esc(n)}</code>: proved in CI by inductive_certificate "
                         f"({esc(n)}), {link}</li>")
        else:
            items.append(f"<li><code>{esc(n)}</code>: not in CI's certificate matrix</li>")
    body = "<ul>" + "".join(items) + "</ul>"
    stamp = inp.speed.get(name, {}).get("certificate")
    if stamp:
        body += f"<p>Proof run stamped in demo/speed.tsv: {esc(stamp[2])}, {esc(stamp[1])}.</p>"
    parts.append(section("Certificate", body))
    # clock window
    if inp.cliffs is None:
        parts.append(section("Clock window", missing("python/clock_cliffs.py not given")))
    else:
        w = [x for x in inp.cliffs.get("WINDOWS", []) if x["firmware"] in names]
        parts.append(section("Clock window", table(
            ["firmware", "shipped Hz", "lowest Hz", "set by", "highest Hz", "set by"],
            [[esc(x["firmware"]), esc(x["shipped_hz"]), esc(x["lowest_hz"] or "-"),
              esc(x.get("lowest_limit") or "-"), esc(x["highest_hz"] or "-"),
              esc(x.get("highest_limit") or "-")] for x in w])
            if w else missing("no window for this protocol's firmware")))
    # speed
    s = inp.speed.get(name)
    if s:
        t = [s.get(k, (None,))[0] for k in STAGES]
        rows = [[esc(k), esc(s[k][2]), esc(s[k][1])] for k in STAGES if k in s]
        gaps = [f"spec to {k}: {took(t[0], t[STAGES.index(k)])}" for k in STAGES[1:]]
        body = table(["stage", "time", "note"], rows) + f"<p>{esc('; '.join(gaps))}</p>"
        body += f'<p class="muted">{esc(SPEED_NOTE)}</p>'
        parts.append(section("Time taken", body))
    else:
        parts.append(section("Time taken", missing("no row in demo/speed.tsv")))
    # board evidence
    seen = witness_rows(inp, name)
    if seen:
        parts.append(section("Board witnesses", witness_table(seen) + (
            "<p class=\"muted\">CI decodes each capture again and holds it to the bytes "
            "sent and the windows, each tooth refused: demo/witness.py check.</p>")))
    rows = ledger_rows(inp, name)
    if rows:
        rows.sort(key=lambda pr: (pr[1]["date"], pr[0].parent.name))
        parts.append(section("Board evidence", ledger_table(rows)
                             + "<p class=\"muted\">The latest entry is the last row.</p>"))
    # refusals
    svgs = sorted(p for p in inp.refusals.glob("*.svg")
                  if any(p.name.startswith(n + "-") for n in names)) if inp.refusals else []
    body = ""
    for p in svgs:
        dest = out / "refusals" / p.name
        dest.parent.mkdir(exist_ok=True)
        shutil.copyfile(p, dest)
        body += f'<p><img src="refusals/{esc(p.name)}" alt="{esc(p.stem)}"></p>'
    if body:
        parts.append(section("Refusals", body))
    # transcript
    found = []
    if inp.transcripts:
        found = sorted(p for p in inp.transcripts.iterdir()
                       if p.is_file() and p.name.split(".")[0] == name)
    body = ""
    for p in found:
        dest = out / "transcripts" / p.name
        dest.parent.mkdir(exist_ok=True)
        shutil.copyfile(p, dest)
        body += f'<p><a href="transcripts/{esc(p.name)}">{esc(p.name)}</a></p>'
    if body:
        parts.append(section("Agent transcript", body))
    return page(name, "\n".join(parts), up="index.html")


def summary(inp, name):
    fw = [r for r in inp.firmware if r["protocol"] == name]
    lim = [r for r in inp.limits if r["protocol"] == name]
    fails = sum(r["result"] == "FAIL" for r in lim)
    cert = sum(r["class"] in ("certified", "time_triggered") for r in fw)
    s = inp.speed.get(name, {})
    t = [s.get(k, (None,))[0] for k in STAGES]
    led = ledger_rows(inp, name)
    bad = sum(failed_ledger(r) for _, r in led)
    return [f'<a href="{esc(name)}.html">{esc(name)}</a>', esc(ORIGIN.get(name, "")), len(fw),
            cert, len(lim), f'<span class="bad">{fails}</span>' if fails else "0",
            took(t[0], t[2]), took(t[0], t[3]),
            f"{board_runs(inp, name)}" + (f' ({bad} off)' if bad else ""),
            len(witness_rows(inp, name))]


def index_page(inp, names):
    rows = [summary(inp, n) for n in names]
    note = " ".join(ORIGINS.values()) + " The rest is the library. "
    body = f"<p>{esc(note)}{RUNS_ON}</p>" + table(
        ["protocol", "origin", "firmware", "certified", "limits", "limits failed",
         "spec to certificate", "spec to bench", "board runs", "witnessed in CI"], rows)
    body += f'<p class="muted">{esc(SPEED_NOTE)}</p>'
    rest = [(p, r) for p, r in inp.ledgers if ledger_protocol(r) not in names]
    if rest:
        body += section("Board runs tied to no protocol page", ledger_table(rest))
    loose = [(d, w) for d, w in inp.witnesses if ledger_protocol(w) not in names]
    # learn runs keep a different record: what was decoded, not a timed bench run
    learned = [(d, w) for d, w in loose if "result" not in w]
    loose = [(d, w) for d, w in loose if "result" in w]
    if loose:
        body += section("Board witnesses tied to no protocol page", witness_table(loose))
    if learned:
        body += section("Learn runs on the board", table(
            ["test/board", "demo", "decoded"],
            [[esc(d), esc(w["demo"]), esc("; ".join(w["expect"]))] for d, w in learned]))
    body += f'<p class="muted">Hashes of every page: <a href="{MANIFEST}">{MANIFEST}</a>.</p>'
    return page("Protocol corpus", body)


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_manifest(out):
    files = sorted(p for p in out.rglob("*") if p.is_file() and p.name != MANIFEST)
    (out / MANIFEST).write_text("".join(
        f"{sha256(p)}  {p.relative_to(out).as_posix()}\n" for p in files))


def check(out):
    bad = []
    listed = set()
    for line in (out / MANIFEST).read_text().splitlines():
        sha, path = line.split(maxsplit=1)
        listed.add(path)
        if not (out / path).is_file() or sha256(out / path) != sha:
            bad.append(path)
    for p in out.rglob("*"):
        rel = p.relative_to(out).as_posix()
        if p.is_file() and p.name != MANIFEST and rel not in listed:
            bad.append(rel + " (not in the manifest)")
    if bad:
        sys.exit("corpus does not match " + MANIFEST + ": " + ", ".join(bad))
    print(f"{len(listed)} files match {MANIFEST}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data")
    ap.add_argument("--out")
    ap.add_argument("--speed", default=str(ROOT / "demo/speed.tsv"))
    ap.add_argument("--ledger", action="append")
    ap.add_argument("--witnesses", default=str(ROOT / "test/board"),
                    help="test/board's runs, each a directory with its witness.json")
    ap.add_argument("--matrix", help="write_certificate.exe -names, else the library's "
                    "certified and time-triggered firmware")
    ap.add_argument("--cliffs")
    ap.add_argument("--refusals")
    ap.add_argument("--transcripts")
    ap.add_argument("--check")
    a = ap.parse_args()
    if a.check:
        return check(Path(a.check))
    if not a.data or not a.out:
        ap.error("--data and --out, or --check")
    out = Path(a.out)
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)
    inp = Inputs(a)
    names = protocols(inp)
    (out / "index.html").write_text(index_page(inp, names))
    for n in names:
        (out / f"{n}.html").write_text(protocol_page(inp, n, out))
    write_manifest(out)
    print(f"{len(names)} protocol pages and an index in {out}")


if __name__ == "__main__":
    main()
