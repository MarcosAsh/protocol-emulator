# SPDX-License-Identifier: Apache-2.0
# Writes a results table from GitHub Actions: each claim, the job that checks it, its last
# green run on main, the weakened copies that had to fail and did, and how long it took.
# Reads the job logs, so it can only report what CI printed. Needs gh, logged in.
# Usage: python3 test/results.py [--repo OWNER/NAME] [--runs N] [--html PAGE] > RESULTS.md
import argparse
import html
import json
import re
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from functools import cache
from pathlib import Path

REPO = None
RUNS = 30

STAMP = re.compile(r"^\ufeff?(\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d)\.\d+Z (.*)$")
SBY_LINE = re.compile(r"^SBY +[\d:]+ \[([A-Za-z0-9_]+)\] (.*)$")
SBY_DONE = re.compile(r"^DONE \((\w+), rc=(\d+)\)")
ABC_GREP = re.compile(r"^grep 'Status = ([01]) ' (\w+)/")
ABC_STATUS = re.compile(r"^Status = ([01]) ")
WITNESS = re.compile(r"^(\w+): (\w+) (verified|fails)$")
SYNC_RUN = re.compile(r"^cd sync_\w+ && if \[ -z '(.*?)' \]")
COCOTB = re.compile(r"\*\* TESTS=(\d+) PASS=(\d+) FAIL=(\d+)")
DECODE = re.compile(r"^(PASS|XFAIL|TOOTH|FAIL|MISSED) \w+: ")


def gh(*args):
    # the API drops the odd request under parallel load, so try again before giving up
    for attempt in range(4):
        done = subprocess.run(["gh", *args], capture_output=True, text=True)
        if done.returncode == 0:
            return done.stdout
        time.sleep(2 ** attempt)
    sys.exit(f"gh {' '.join(args)}: {done.stderr.strip()}")


def when(stamp):
    return datetime.fromisoformat(stamp.replace("Z", "+00:00"))


@cache
def runs(workflow):
    """The newest completed runs of [workflow] on main, newest first."""
    out = gh("run", "list", "-R", REPO, "--workflow", workflow, "--branch", "main",
             "--status", "completed", "--limit", str(RUNS),
             "--json", "databaseId,conclusion,createdAt,headSha,url")
    return json.loads(out)


@cache
def jobs(run_id):
    out = gh("api", f"repos/{REPO}/actions/runs/{run_id}/jobs?per_page=100", "--paginate",
             "--jq", ".jobs[]")
    return [json.loads(line) for line in out.splitlines() if line]


@cache
def raw_flags():
    # newer gh refuses a response with escape codes, as colored logs have, without this
    return [f for f in ["--allow-escape-sequences"] if f in gh("api", "--help")]


@cache
def log(job_id):
    """(time, text) for each line of the job's log."""
    lines = []
    for raw in gh("api", *raw_flags(), f"repos/{REPO}/actions/jobs/{job_id}/logs").splitlines():
        m = STAMP.match(raw)
        if m:
            lines.append((datetime.fromisoformat(m[1] + "+00:00"), m[2]))
    return lines


def step_lines(job, step):
    if step is None:
        return log(job["id"])
    s = next(s for s in job["steps"] if s["name"] == step)
    start, end = when(s["started_at"]), when(s["completed_at"])
    return [(t, text) for t, text in log(job["id"]) if start <= t.replace(microsecond=0) <= end]


def seconds(job, step=None):
    if step is None:
        return (when(job["completed_at"]) - when(job["started_at"])).total_seconds()
    s = next(s for s in job["steps"] if s["name"] == step)
    return (when(s["completed_at"]) - when(s["started_at"])).total_seconds()


def span(intervals):
    """Wall time covered by the intervals, which may overlap."""
    total, reach = 0.0, None
    for start, end in sorted(intervals):
        if reach is None or start > reach:
            total += (end - start).total_seconds()
            reach = end
        elif end > reach:
            total += (end - reach).total_seconds()
            reach = end
    return total


class Result:
    def __init__(self, passes=0, teeth=0, wrong=0, time=None, note="", teeth_note=""):
        self.passes, self.teeth, self.wrong, self.time, self.note = passes, teeth, wrong, time, note
        self.teeth_note = teeth_note

    def __add__(self, other):
        time = None if self.time is None or other.time is None else self.time + other.time
        note = "; ".join(n for n in [self.note, other.note] if n)
        teeth_note = "; ".join(n for n in [self.teeth_note, other.teeth_note] if n)
        return Result(self.passes + other.passes, self.teeth + other.teeth,
                      self.wrong + other.wrong, time, note, teeth_note)


def sby(*prefixes):
    """SymbiYosys tasks by name: a pass is a proof or cover, a FAIL or UNKNOWN with rc 0 is a
    tooth its .sby expects to fail, anything else is wrong."""
    def read(lines):
        first, done = {}, {}
        for t, text in lines:
            m = SBY_LINE.match(text)
            if not m or not m[1].startswith(prefixes):
                continue
            first.setdefault(m[1], t)
            d = SBY_DONE.match(m[2])
            if d:
                done[m[1]] = (t, d[1], d[2])
        r = Result(time=span((first[task], t) for task, (t, _, _) in done.items()))
        for _, status, rc in done.values():
            if status == "PASS" and rc == "0":
                r.passes += 1
            elif status in ("FAIL", "UNKNOWN") and rc == "0":
                r.teeth += 1
            else:
                r.wrong += 1
        return r
    return read


def abc(*prefixes, controls=()):
    """ABC's dprove through the Makefile's greps: a directory with any 'Status = 0' is a
    mutant refuted, one with only 'Status = 1' a proof, unless [controls] names it; the grep
    must print that status."""
    def read(lines):
        status, touched = {}, []
        for i, (t, text) in enumerate(lines):
            if re.match(r"^(rm -rf|grep 'Status) .*\b(" + "|".join(prefixes) + ")", text):
                touched.append(t)
            m = ABC_GREP.match(text)
            if not m or not m[2].startswith(prefixes):
                continue
            printed = i + 1 < len(lines) and ABC_STATUS.match(lines[i + 1][1])
            ok = printed and printed[1] == m[1]
            status.setdefault(m[2], []).append(m[1] if ok else "wrong")
        r = Result(time=span([(min(touched), max(touched))]) if touched else None)
        for name, seen in status.items():
            if "wrong" in seen:
                r.wrong += 1
            elif name in controls:
                continue
            elif "0" in seen:
                r.teeth += 1
            else:
                r.passes += 1
        return r
    return read


def sync(lines):
    """formal/sync/check.tcl runs through the Makefile, which echoes each one's FAILS:
    empty is the check, a name is a mutant that must fail there."""
    r, touched = Result(), []
    for i, (t, text) in enumerate(lines):
        m = SYNC_RUN.match(text)
        if m:
            touched += [t, lines[min(i + 1, len(lines) - 1)][0]]
            if m[1]:
                r.teeth += 1
            else:
                r.passes += 1
    r.time = span([(min(touched), max(touched))]) if touched else None
    return r


def witness(lines):
    """Certifaiger checks cake_lpr verified, and weakened models whose witness it rejected."""
    r = Result()
    for _, text in lines:
        m = WITNESS.match(text)
        if m and m[3] == "verified":
            r.passes += 1
        elif m:
            r.teeth += 1
    return r


def cocotb(lines):
    r = Result()
    for _, text in lines:
        m = COCOTB.search(text)
        if m:
            r.passes += int(m[2])
            r.wrong += int(m[3])
    return r


def decoded(lines):
    """demo/decode.py's verdicts: a refused tooth counts as teeth, a fail or miss wrong."""
    r = Result()
    for _, text in lines:
        m = DECODE.match(text)
        if m and m[1] in ("PASS", "XFAIL"):
            r.passes += 1
        elif m and m[1] == "TOOTH":
            r.teeth += 1
        elif m:
            r.wrong += 1
    return r


def matching(pattern, fmt):
    """A note from the last line matching [pattern], formatted with its groups."""
    def read(lines):
        found = [re.search(pattern, text) for _, text in lines]
        found = [m for m in found if m]
        return Result(note=fmt.format(*found[-1].groups()) if found else "")
    return read


def both(*readers):
    def read(lines):
        results = [f(lines) for f in readers]
        r = results[0]
        for other in results[1:]:
            r = r + other
            r.time = results[0].time
        return r
    return read


def green(lines):
    return Result()


def mutation(lines):
    killed = [re.search(r"total: killed (\d+) of (\d+) valid mutants", t) for _, t in lines]
    killed = [m for m in killed if m]
    refused = sum(1 for _, t in lines if re.match(r"survived: .*: NOT ALLOWED$", t))
    if not killed:
        return Result()
    k, n = int(killed[-1][1]), int(killed[-1][2])
    return Result(wrong=refused,
                  teeth_note=f"{k} of {n} mutants killed; of the {n - k} survivors "
                  f"{n - k - refused} allowed with a reason, {refused} not")


def split(lines):
    counts = dict(re.findall(r"\(\(verdict (\w+)\) \(count (\d+)\)\)", "\n".join(t for _, t in lines)))
    return Result(note=", ".join(f"{v} {c}" for v, c in counts.items()))


# Each claim's status word once a green run on main logs its check, and the last until then.
STATUSES = {
    "proved for all time": "a proof over every state, input or program it names, with no "
    "bound on time: induction, PDR, or an UNSAT checked by cake_lpr",
    "proved to depth N": "a bounded proof: every run of N steps from the clear, nothing "
    "past it",
    "checked": "a structural check of every cell of a netlist, or Tiny Tapeout's precheck",
    "tested": "many runs, mutants or variants, not all of them",
    "simulated": "cocotb tests and recorded pin traces on a design in simulation",
    "not verified": "no green run on main shows the check, or its log shows no pass",
}


FORMAL = Path(__file__).resolve().parent.parent / "formal"


def depth(sby_file, task):
    """The status of a bounded proof, at the depth formal/[sby_file] gives [task]."""
    found = re.search(rf"^{task}: depth (\d+)$", (FORMAL / sby_file).read_text(), re.M)
    return f"proved to depth {found[1]}"


def status_word(status):
    return "proved to depth N" if status.startswith("proved to depth") else status


class Claim:
    def __init__(self, text, workflow, job, target, read, step=None, teeth_note="",
                 status="proved for all time"):
        self.text, self.workflow, self.job, self.target = text, workflow, job, target
        self.read, self.step, self.teeth_note, self.status = read, step, teeth_note, status

    def jobs_of(self, run):
        found = [j for j in jobs(run["databaseId"]) if self.job(j["name"])]
        if self.step:
            found = [j for j in found if any(s["name"] == self.step for s in j["steps"])]
        return found

    def ok(self, found):
        if not found:
            return False
        if self.step:
            return all(s["conclusion"] == "success"
                       for j in found for s in j["steps"] if s["name"] == self.step)
        return all(j["conclusion"] == "success" for j in found)

    def evaluate(self):
        """The last run on main where every matching job (or step) is green, or failing
        that the last run that has the job at all."""
        latest = None
        for run in runs(self.workflow):
            found = self.jobs_of(run)
            if found and latest is None:
                latest = (run, found)
            if self.ok(found):
                return run, found, True
        return (*latest, False) if latest else (None, [], False)


def exactly(name):
    return lambda job: job == name


def matrix(name, keep=lambda value: True):
    pattern = re.compile(rf"^{re.escape(name)} \((.*)\)$")
    return lambda job: bool(pattern.match(job)) and keep(pattern.match(job)[1])


def plain_certificate(value):
    return value != "stamped" and not value.startswith("data_")


TESTED = "the mutation row"

CLAIMS = [
    ("The theorem", [
        Claim("For any program, and any table of intervals the kernel accepts, the core never "
              "misses a deadline: step lemma and kernel check in one run",
              "ocaml", exactly("phase_table"), "phase_table_proof", sby("phase_table_")),
        Claim("The same for rows that also bound the phase less a multiple of the loop "
              "counter, with the kernel's check of one step proved per opcode",
              "ocaml", exactly("phase_table_affine"), "phase_table_affine_proof",
              sby("row_step_", "phase_table_affine_")),
        Claim("For any program, the core moves between entries as the kernel's step says, "
              "and a deadline wait entered in time never faults (k-induction on the RTL). "
              "A timer that stops at its top instead of wrapping has to fail it",
              "ocaml", lambda job: job in ("test", "saturating"), "phase_step saturating_proof",
              sby("phase_step_"), step="Prove"),
        Claim("For any program and any table of intervals the kernel accepts with a spacing, "
              "each counted edge of a watched pair is spaced", "ocaml", matrix("phase_spacing"),
              "phase_spacing_part", sby("pair_step_", "phase_spacing_")),
        Claim("An accepted table is closed under the kernel's step, over every instruction "
              "word and row; every UNSAT is cadical's, checked by cake_lpr",
              "ocaml", exactly("test"), "dune build @runtest", green, step="Run tests",
              teeth_note="expect tests: a proof with one line corrupted is refused"),
        Claim("The kernel's Verilog, which the RTL proofs read, equals the gates its SAT "
              "proofs build", "ocaml", exactly("test"), "kernel_equiv",
              abc("kernel_equiv_"), step="Prove"),
        Claim("The k-inductions of phase_step, edge_step and self_check_clean each have a "
              "Certifaiger witness, every check of it an UNSAT that cake_lpr verifies",
              "ocaml", matrix("witness"), "witness_proof", witness),
        Claim("Across one-field variants of the library, no firmware the kernel accepts "
              "misses a deadline in a run", "reject split", exactly("split"), "split.exe",
              split, status="tested"),
    ]),
    ("Lemmas on the RTL", [
        Claim("The pins change only the cycle after an entry that writes them",
              "ocaml", exactly("test"), "edge_step", sby("edge_step_"), step="Prove"),
        Claim("A pin wait releases, and a jump on the pin goes, by the sample of its own cycle",
              "ocaml", exactly("test"), "event_step", sby("event_step_"), step="Prove"),
        Claim("A pin outside an engine's footprint keeps 0 from the clear",
              "ocaml", exactly("test"), "frame_step", sby("frame_step_"), step="Prove"),
        Claim("Two engines with disjoint footprints drive and read their pads as they would "
              "alone", "ocaml", exactly("test"), "chip_frame", sby("chip_frame_"), step="Prove"),
        Claim("What out, mov, in, push and pull write is the ISA's function of the shift "
              "registers", "ocaml", exactly("test"), "value_step", sby("value_step_"),
              step="Prove"),
        Claim("Each out sends the bits of the last pulled word that the osr count names",
              "ocaml", exactly("test"), "data_step", sby("data_step_"), step="Prove"),
        Claim("Issue timing depends on nothing but the delay field",
              "ocaml", exactly("test"), "issue_timing", sby("issue_timing_"), step="Prove"),
        Claim("When and how the host talks reaches the pins only through the program's own "
              "fifo waits and tests, or a fault", "ocaml", exactly("test"),
              "host_timing late_host", sby("host_timing_", "late_host_"), step="Prove"),
        Claim("The fifos keep their order", "ocaml", exactly("test"), "fifo_order",
              sby("fifo_order_"), step="Prove"),
    ]),
    ("Per-firmware proofs", [
        Claim("Each library firmware's certificate holds for all time, by induction, under "
              "the assumptions test/test_certified.ml lists",
              "ocaml", matrix("inductive_certificate", plain_certificate), "inductive_proof",
              sby("certificate_")),
        Claim("For the five transmitters that pull by hand, the pins show the right bit of "
              "the right host word", "ocaml",
              matrix("inductive_certificate", lambda v: v.startswith("data_")), "data_proof",
              sby("certificate_data_")),
        Claim("Each uart_tx_stamped frame carries the low 16 bits of the cycle its start bit "
              "showed on the pin",
              "ocaml", matrix("inductive_certificate", lambda v: v == "stamped"),
              "stamped_proof", sby("certificate_stamped_")),
        Claim("uart_tx on engine 0 to uart_rx on engine 1 over an on-chip wire, 10 cycles a "
              "bit: engine 1 pushes the low byte of each word engine 0 pulled, once a frame",
              "ocaml", exactly("link"), "link_proof", sby("link_")),
        Claim("hardcaml_hobby_boards' Uart.Tx, compiled to firmware, drives the core's pin as "
              "the circuit drives its line, 4 cycles later, at 4 clocks a bit, for bytes at "
              "least 4 cycles after ready", "ocaml", exactly("test"), "fsm_miter_proof",
              sby("fsm_miter_"), step="Prove"),
        Claim("Self_check.checker, for one set of edges on pin 0, rows at 0, on one engine "
              "with a private data memory, its program and rows as ROMs and the host idle: no "
              "irq, no halt and none of its own deadlines missed until the line leaves its "
              "rows", "ocaml", exactly("self_check"), "self_check_clean_proof",
              sby("self_check_clean_"), step="Prove"),
        Claim("Self_check.checker's irq only after a break and by the contract's deadline, "
              "for 116 cycles from the clear, which reach the first frame's deadline only if "
              "the first fall comes by about cycle 22", "ocaml", exactly("self_check"),
              "self_check_proof",
              sby(*(f"self_check_{t}" for t in ["bmc", "cover", "stamp", "least", "silent",
                                                "slow"])),
              step="Prove", status=depth("self_check.sby", "bmc")),
    ]),
    ("From RTL to silicon", [
        Claim("The flop program memory equals IHP's model of the 512x16 SRAM, step for step "
              "from any contents", "ocaml", exactly("test"), "sram_equiv",
              abc("sram_equiv_", controls=["sram_equiv_zero"]), step="Prove"),
        Claim("Power-up is deterministic: two copies of the chip from any two states of their "
              "flops and fifos, with the same words in their SRAMs, reset at the first edge "
              "and given the same pins, drive the same pins", "ocaml", exactly("test"),
              "powerup", sby("powerup_"), step="Prove"),
        Claim("The hardened netlist equals the RTL for all time from all flops 0",
              "gds", exactly("netlist_equiv"),
              "netlist_equiv netlist_equiv_teeth",
              both(abc("netlist_equiv_"),
                   matching(r"netlist: (\d+) logic cells", "{} logic cells compared")),
              step="Prove the netlist equal to the RTL, and fail on six mutants"),
        Claim("One clock, and every other pin read by one two-flop synchroniser, on the RTL",
              "ocaml", exactly("test"), "sync_rtl sync_rtl_teeth", sync, step="Prove",
              status="checked"),
        Claim("The same on the hardened netlist", "gds", exactly("netlist_equiv"),
              "sync_gate sync_gate_teeth", sync,
              step="Check one clock and a two-flop synchroniser on every pin, and fail on "
              "five mutants", status="checked"),
        Claim("The hardened design passes Tiny Tapeout's precheck", "gds",
              exactly("precheck"), "tt-gds-action/precheck", green,
              teeth_note="none, a check", status="checked"),
    ]),
    ("Tests", [
        Claim("The cocotb tests and recorded pin traces pass on the RTL", "test",
              exactly("test"), "make -C test; make replay", cocotb, teeth_note=TESTED,
              status="simulated"),
        Claim("The same on the hardened gate-level netlist", "gds", exactly("gl_test"),
              "tt-gds-action/gl_test; make replay GATES=yes", cocotb, teeth_note=TESTED,
              status="simulated"),
        Claim("The same on the iCE40 kit's netlist", "ocaml", exactly("fpga"),
              "make FPGA=yes; make replay FPGA=yes",
              both(cocotb, matching(r"ICESTORM_LC: *(\d+)/ *(\d+)", "{} of {} LCs"),
                   matching(r"Max frequency for clock [^:]*: ([\d.]+) MHz", "{} MHz routed")),
              step="Build for the FPGA kit and simulate the netlist", teeth_note=TESTED,
              status="simulated"),
        Claim("The same on the Icepi Zero's ECP5 netlist, timing met at 48 MHz", "ocaml",
              exactly("fpga"), "make -C icepi; make ICEPI=yes",
              both(cocotb, matching(r"Max frequency for clock [^:]*: ([\d.]+) MHz",
                                    "{} MHz routed")),
              step="Build for the Icepi Zero and simulate the netlist", teeth_note=TESTED,
              status="simulated"),
        Claim("sigrok's decoders read the gate-level netlist's outputs as they read the RTL's",
              "gds", exactly("gl_test"), "demo/decode.py on the gate level's traces",
              both(decoded, matching(r"^sigrok on the gate-level netlist: (\d+) of (\d+) ",
                                     "{} of {} protocols")),
              step="Decode the gate level's traces with sigrok", status="simulated"),
        Claim("Every textual mutant of the engine, decoder, pins and host port is killed by "
              "the tests, or allowed with a reason", "mutation", exactly("mutate"),
              "test/mutate.py", mutation, status="tested"),
    ]),
]

METRICS = re.compile(r"^commit,date,(.*)$")


def minutes(s):
    if s is None:
        return ""
    s = int(round(s))
    return f"{s // 60} min {s % 60:02d} s" if s >= 60 else f"{s} s"


def run_cell(run, good):
    if run is None:
        return "no run on main"
    date = run["createdAt"][:10]
    mark = "" if good else " **(not green)**"
    return f"[{run['databaseId']}]({run['url']}) {date} `{run['headSha'][:7]}`{mark}"


class Row:
    """What CI shows for one claim; [missing] when its green run logged no pass."""
    def __init__(self, claim, run=None, good=False, where="", passes=0, wrong=0, note="",
                 teeth="", time=None, missing=False):
        self.claim, self.run, self.good, self.where = claim, run, good, where
        self.passes, self.wrong, self.note = passes, wrong, note
        self.teeth, self.time, self.missing = teeth, time, missing

    def evidence(self, passed=""):
        """The passes, the failures and the note; [passed] follows the count of passes."""
        counts = [f"{self.passes}{passed}"] if self.passes else []
        counts += [f"{self.wrong} failed"] if self.wrong else []
        return "; ".join(t for t in [", ".join(counts), self.note] if t)

    @property
    def status(self):
        shown = self.run and self.good and not self.wrong and not self.missing
        return self.claim.status if shown else "not verified"


def row(claim):
    run, found, good = claim.evaluate()
    if run is None:
        return Row(claim)
    result = Result(time=0.0)
    for job in found:
        r = claim.read(step_lines(job, claim.step))
        if r.time is None:
            r.time = seconds(job, claim.step)
        result = result + r
    job_names = sorted({j["name"].split(" (")[0] for j in found})
    where = f"{claim.workflow} / {', '.join(job_names)}"
    if claim.step:
        where += f" / {claim.step}"
    if len(found) > 1:
        where += f" ({len(found)} jobs)"
    # a green job may never have run the check, as before the check was added, so the log
    # has to show a pass, or for mutation and split their tally
    if claim.read is green:
        missing = False
    elif claim.read in (mutation, split):
        missing = not (result.note or result.teeth_note)
    else:
        missing = not result.passes
    if missing:
        result.time = None
    if result.teeth:
        teeth = f"{result.teeth}, all failed as expected"
    else:
        teeth = result.teeth_note or claim.teeth_note or "none in the log"
    return Row(claim, run, good, where, result.passes, result.wrong, result.note, teeth,
               result.time, missing)


def markdown_row(r):
    claim = r.claim
    if r.run is None:
        return f"| {claim.text} | `{claim.target}` ({claim.workflow}) | no run on main | | | |"
    passes = r.evidence() or ("**none in the log**" if r.missing else "")
    return (f"| {claim.text} | `{claim.target}`<br>{r.where} | {run_cell(r.run, r.good)} "
            f"| {passes} | {r.teeth} | {minutes(r.time)} |")


PAGE_STYLE = """
  :root { --bg: #fff; --fg: #1a1a1a; --muted: #666; --code: #f4f4f4; --line: #ddd;
    --ok: #1a7f37; --bad: #c62828; }
  @media (prefers-color-scheme: dark) {
    :root:not([data-theme="light"]) { --bg: #161616; --fg: #e8e8e8; --muted: #9a9a9a;
      --code: #232323; --line: #333; --ok: #57c27a; --bad: #ef6a6a; }
  }
  :root[data-theme="dark"] { --bg: #161616; --fg: #e8e8e8; --muted: #9a9a9a;
    --code: #232323; --line: #333; --ok: #57c27a; --bad: #ef6a6a; }
  body { font: 14px/1.4 system-ui, sans-serif; margin: 0 auto; padding: 16px;
    max-width: 76rem; background: var(--bg); color: var(--fg); }
  a { color: inherit; }
  code { font: 12px/1.4 ui-monospace, monospace; background: var(--code); padding: 0 3px;
    overflow-wrap: anywhere; }
  table { border-collapse: collapse; width: 100%; }
  th, td { text-align: left; vertical-align: top; padding: 6px 8px;
    border-bottom: 1px solid var(--line); }
  thead th { font-weight: 600; white-space: nowrap; }
  tr.section th { padding-top: 20px; font-size: 1.05rem; }
  .status { font-weight: 600; }
  .status, .nowrap { white-space: nowrap; }
  .proved { color: var(--ok); }
  .unverified, .bad { color: var(--bad); }
  .muted, dd { color: var(--muted); }
  dl { display: grid; grid-template-columns: max-content 1fr; gap: 2px 16px; }
  dd { margin: 0; }
  /* narrow: each row a card, the roles in the markup keep it a table to a screen reader */
  @media (max-width: 720px) {
    table, tbody, tr, th, td { display: block; }
    thead { position: absolute; width: 1px; height: 1px; overflow: hidden;
      clip-path: inset(50%); }
    tr { border-bottom: 1px solid var(--line); padding: 8px 0; }
    th, td { border: 0; padding: 2px 0; }
    td[data-label]::before { content: attr(data-label) ": "; color: var(--muted); }
    dl { grid-template-columns: 1fr; }
    dd { margin-bottom: 6px; }
  }
"""


def html_row(r):
    e = html.escape
    claim = r.claim
    kind = {"proved for all time": "proved", "not verified": "unverified"}.get(r.status, "")
    passes = r.evidence(" passed") or ("none in the log" if r.missing else "")
    passes = f'<br><span class="muted">{e(passes)}</span>' if passes else ""
    status = f'<span class="status {kind}">{e(r.status)}</span>{passes}'
    if r.run is None:
        where, run, date = e(claim.workflow), "no run on main", ""
    else:
        sha = r.run["headSha"]
        where, date = e(r.where), r.run["createdAt"][:10]
        run = (f'<a href="{e(r.run["url"])}">{r.run["databaseId"]}</a> at <a href='
               f'"https://github.com/{e(REPO)}/commit/{sha}"><code>{sha[:7]}</code></a>')
        if not r.good:
            run += ' <span class="bad">(not green)</span>'
    nowrap = ' class="nowrap"'
    cells = [("Status", "", status), ("CI job", "", f"<code>{e(claim.target)}</code><br>{where}"),
             ("Last green run", "", run), ("Date", nowrap, date), ("Teeth", "", e(r.teeth)),
             ("Job time", nowrap, minutes(r.time))]
    return (f'<tr role="row"><th scope="row" role="rowheader">{e(claim.text)}</th>'
            + "".join(f'<td role="cell" data-label="{label}"{style}>{text}</td>'
                      for label, style, text in cells)
            + "</tr>")


def html_page(rows, now):
    """The claims as one table, for GitHub Pages."""
    e = html.escape
    counts = {}
    for r in rows.values():
        counts[r.status] = counts.get(r.status, 0) + 1
    tally = ", ".join(f"{n} {status}" for word in STATUSES for status, n in counts.items()
                      if status_word(status) == word)
    legend = "\n".join(f"<dt>{e(s)}</dt><dd>{e(m)}</dd>" for s, m in STATUSES.items())
    body = []
    for title, section in CLAIMS:
        body.append('<tbody role="rowgroup"><tr role="row" class="section">'
                    f'<th colspan="7" scope="rowgroup" role="rowheader">{e(title)}</th></tr>')
        body += [html_row(rows[id(claim)]) for claim in section]
        body.append("</tbody>")
    body = "\n".join(body)
    heads = ["Claim", "Status", "CI job", "Last green run", "Date", "Teeth", "Job time"]
    heads = "".join(f'<th scope="col" role="columnheader">{h}</th>' for h in heads)
    return f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="color-scheme" content="light dark">
<title>Protocol Emulator Results</title>
<style>{PAGE_STYLE}</style>
</head>
<body>
<h1>Results</h1>
<p class="muted">The claims CI checks, the job that checks each, and its last run on main where
every job behind it was green. Written by <code>test/results.py</code> at {e(now)} from the
job logs, so it shows only what CI printed. Teeth are weakened copies and mutants that have
to fail. Job time adds up jobs that ran in parallel. The assumptions and the tools trusted
are under
<a href="https://github.com/{e(REPO)}#what-is-not-proved">What is not proved</a> in the
README. Bench measurements are not in CI and not here.
<a href="https://github.com/{e(REPO)}">Repository</a>, <a href="../playground/">playground</a>.</p>
<p>{e(tally)}.</p>
<table role="table">
<thead role="rowgroup"><tr role="row">{heads}</tr></thead>
{body}
</table>
<h2>Status</h2>
<dl>
{legend}
</dl>
</body>
</html>
"""


def die():
    claim = Claim("", "gds", exactly("gds"), "", green)
    run, found, good = claim.evaluate()
    if run is None:
        return ["No gds run on main."]
    lines = [text for _, text in log(found[0]["id"])]
    header = next((i for i, t in enumerate(lines) if METRICS.match(t)), None)
    if header is None:
        return [f"No metrics in gds run {run_cell(run, good)}."]
    names = lines[header].split(",")
    values = lines[header + 1].split(",")
    out = [f"From gds run {run_cell(run, good)}, `test/check_metrics.py --csv`:", "",
           "| " + " | ".join(names) + " |", "|" + "---|" * len(names),
           "| " + " | ".join(values) + " |"]
    return out


def main():
    global REPO, RUNS
    p = argparse.ArgumentParser()
    p.add_argument("--repo", help="OWNER/NAME, by default this checkout's")
    p.add_argument("--runs", type=int, default=RUNS, help="runs to look back per workflow")
    p.add_argument("--html", metavar="PAGE", help="also write the results page to PAGE")
    args = p.parse_args()
    REPO = args.repo or gh("repo", "view", "--json", "nameWithOwner", "-q", ".nameWithOwner").strip()
    RUNS = args.runs
    claims = [c for _, section in CLAIMS for c in section]
    with ThreadPoolExecutor(8) as pool:
        rows = dict(zip(map(id, claims), pool.map(row, claims)))
    now = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    if args.html:
        with open(args.html, "w") as f:
            f.write(html_page(rows, now))
    print("# Results")
    print()
    print(f"Written by `test/results.py` at {now} from the GitHub Actions runs on main. Each "
          "row is the last run where every job behind the claim was green. Passes counts the "
          "proofs, covers and tests that passed; teeth are the weakened copies and mutants "
          "that have to fail, counted from the log. Job time is how long the checks took in "
          "their jobs, added up over jobs that ran in parallel.")
    for title, section in CLAIMS:
        print()
        print(f"## {title}")
        print()
        print("| Claim | Checked by | Last green | Passes | Teeth | Job time |")
        print("|---|---|---|---|---|---|")
        for claim in section:
            print(markdown_row(rows[id(claim)]))
    print()
    print("## The die")
    print()
    print("\n".join(die()))


if __name__ == "__main__":
    main()
