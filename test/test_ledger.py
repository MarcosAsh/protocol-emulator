# SPDX-License-Identifier: Apache-2.0
"""demo/ledger.py against stand-ins for openFPGALoader, mpremote and sigrok-cli, so no board:
the rows it adds, the hashes it keeps, and evidence never overwritten."""

import csv
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "demo"))
import ledger  # noqa: E402

# what each stand-in does is in its own words; VERDICT is what Pico A says
STANDINS = {
    "openFPGALoader": 'exit "${LOAD:-0}"\n',
    "mpremote": """shift 2
case "$1 $*" in
cat*) printf 'faults 0x0\\n%s\\n' "${VERDICT:-PASS}" ;;
run*--no-follow*) ;;
run*) printf 'table\\n%s\\n' "${VERDICT:-PASS}" ;;
exec*pico_listener*) sleep 100 ;;
exec*status*) printf "{'halted': 1}\\n%s\\n" "${VERDICT:-PASS}" ;;
esac
""",
    "sigrok-cli": """while [ $# -gt 0 ]; do
    case $1 in
    -o) printf 'samples' > "$2"; exit 0 ;;
    -i) echo "uart-1: 4a"; exit 0 ;;
    esac
    shift
done
""",
}


class Ledger(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        bin = self.tmp / "bin"
        bin.mkdir()
        for name, body in STANDINS.items():
            (bin / name).write_text("#!/bin/sh\n" + body)
            (bin / name).chmod(0o755)
        self.bit = self.tmp / "chip.bit"
        self.bit.write_bytes(b"bitstream")
        self.env = {k: v for k, v in os.environ.items() if not k.startswith("ANALYSER")}
        # no firmware for demo/pico_b.sh, so it stops before it looks for a Pico
        self.env.update(PATH="%s:%s" % (bin, os.environ["PATH"]), PICO="id:a",
                        PICO_B_SERIAL="nobody", MICROPYTHON_UF2="/nowhere",
                        CAN_NODE_UF2="/nowhere", START_HOLD_DIR="/nowhere")

    def run_ledger(self, *demos, **env):
        only = [w for d in demos for w in ("--only", d)]
        return subprocess.run(
            [sys.executable, str(ROOT / "demo/ledger.py"), str(self.bit), *only,
             "--evidence", str(self.tmp / "evidence"), "--results", str(self.tmp / "ledger.tsv")],
            env=self.env | env, capture_output=True, text=True, timeout=120)

    def rows(self):
        with open(self.tmp / "ledger.tsv") as f:
            return list(csv.DictReader(f, delimiter="\t"))

    def check_sums(self, row):
        d = self.tmp / "evidence" / row["evidence"]
        subprocess.run(["sha256sum", "--quiet", "-c", "SHA256SUMS"], cwd=d, check=True)
        self.assertEqual(row["sums_sha256"], ledger.sha256(d / "SHA256SUMS"))
        return d

    def test_rows_and_hashes(self):
        run = self.run_ledger("smoke", "self_timing", "sweep", "neopixel")
        self.assertEqual(run.returncode, 1, run.stdout + run.stderr)
        rows = {r["demo"]: r for r in self.rows()}
        self.assertEqual(list(rows), ["smoke", "self_timing", "sweep", "neopixel"])
        # Pico B is not on USB, so the demo that needs its listener never runs
        self.assertEqual({d: r["result"] for d, r in rows.items()},
                         {"smoke": "PASS", "self_timing": "ERROR", "sweep": "PASS",
                          "neopixel": "PASS"})
        bit_hash = ledger.sha256(self.bit)
        for d, row in rows.items():
            self.assertEqual(row["bitstream_sha256"], bit_hash)
            self.assertEqual(row["commit"].removesuffix("+dirty"),
                             subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True,
                                            capture_output=True).stdout.strip())
            evidence = self.check_sums(row)
            self.assertIn("$ openFPGALoader", (evidence / "run.txt").read_text())
            captures = list(evidence.glob("*.sr"))
            if d in ("sweep", "neopixel"):
                self.assertEqual(row["capture_sha256"], ledger.sha256(captures[0]))
            else:
                self.assertEqual((captures, row["capture_sha256"]), ([], "-"))
        neopixel = self.tmp / "evidence" / rows["neopixel"]["evidence"]
        self.assertEqual(sorted(p.name for p in neopixel.iterdir()),
                         ["SHA256SUMS", "ledger.txt", "neopixel.decode", "neopixel.log",
                          "neopixel.sr", "outside.txt", "run.txt"])
        runs = self.tmp / "evidence" / rows["smoke"]["date"] / "ledger"
        self.assertEqual(neopixel.parent, runs)
        kept = runs / "bitstreams" / (bit_hash[:16] + ".bit")
        self.assertEqual(kept.read_bytes(), self.bit.read_bytes())

    def test_fail_and_no_overwrite(self):
        self.assertEqual(self.run_ledger("smoke").returncode, 0)
        run = self.run_ledger("smoke", VERDICT="FAIL")
        self.assertEqual(run.returncode, 1)
        first, second = self.rows()
        self.assertEqual((first["result"], second["result"]), ("PASS", "FAIL"))
        self.assertEqual(second["evidence"], first["evidence"] + ".2")
        self.assertIn("result: PASS", (self.check_sums(first) / "ledger.txt").read_text())

    def test_no_bitstream_load(self):
        self.run_ledger("smoke", LOAD="1")
        (row,) = self.rows()
        self.assertEqual(row["result"], "ERROR")
        self.assertFalse((self.tmp / "evidence" / row["evidence"] / "smoke.log").exists())

    def test_dry_run_runs_nothing(self):
        run = subprocess.run(
            [sys.executable, str(ROOT / "demo/ledger.py"), "chip.bit", "--dry-run", "--keyboard",
             "--evidence", str(self.tmp / "evidence"), "--results", str(self.tmp / "ledger.tsv")],
            env=self.env, capture_output=True, text=True, check=True)
        for demo in ledger.NAMES:
            self.assertIn("\n%s, expect" % demo, run.stdout)
        self.assertFalse((self.tmp / "evidence").exists())
        self.assertFalse((self.tmp / "ledger.tsv").exists())

    def test_keyboard_needs_its_flag(self):
        run = self.run_ledger("keyboard")
        self.assertIn("--keyboard", run.stderr)
        self.assertFalse((self.tmp / "evidence").exists())

    def test_verdicts(self):
        self.assertEqual(ledger.last_verdict("PASS\n  x\r\n FAIL\r\nPASS within a cycle\n"), "FAIL")
        self.assertIsNone(ledger.last_verdict("faults 0x0\n"))
        self.assertEqual(ledger.typed("typed h\r\ntyped i\r\ntyped  \r\nreplugged\r\n"), "hi ")
        hold = "host, against t_HD;STA >= 4000 ns (192 cycles): %s, 0 of 64 short\nthe stick\n"
        self.assertEqual(ledger.hold_verdict(hold % "PASS within a cycle of it"), "PASS")
        self.assertEqual(ledger.hold_verdict(hold % "FAIL"), "FAIL")
        self.assertIsNone(ledger.hold_verdict("no START in 5000 ms\nno verdict\n"))


if __name__ == "__main__":
    unittest.main()
