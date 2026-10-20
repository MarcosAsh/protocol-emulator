# SPDX-License-Identifier: Apache-2.0
"""test/corpus.py on a two-protocol fixture: a failed limit and a missing source are shown,
nothing is hand-written per protocol, and the manifest catches an edited page."""

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
LIMITS = ("protocol firmware parameter side limit_ns bound_by needed_cycles bound_cycles "
          "bound_ns result margin part document page").split()


def tsv(path, head, rows):
    path.write_text("\n".join("\t".join(r) for r in [head, *rows]) + "\n")


class Corpus(unittest.TestCase):
    def setUp(self):
        self.dir = Path(tempfile.mkdtemp())
        data = self.dir / "data"
        (data / "firmware").mkdir(parents=True)
        (data / "firmware/bench-a.asm").write_text("nop <1>\n")
        (data / "firmware/bench-b.asm").write_text("nop\n")
        tsv(data / "firmware.tsv", "protocol class firmware clock_hz source".split(),
            [["ps2", "bench", "a", "48000000", "bench-a.asm"],
             ["nosuch", "bench", "b", "48000000", "bench-b.asm"]])
        tsv(data / "limits.tsv", LIMITS,
            [["ps2", "a", "T1", ">=", "5000", "kernel", "241", "100", "2083.3", "FAIL",
              "a cycle", "part", "doc", "p1"]])
        self.out = self.dir / "out"

    def run_corpus(self, *args):
        return subprocess.run(
            [sys.executable, str(HERE / "corpus.py"), "--data", str(self.dir / "data"),
             "--out", str(self.out), "--speed", str(self.dir / "none.tsv"), *args],
            capture_output=True, text=True)

    def test_failures_and_gaps_are_shown(self):
        (self.dir / "matrix").write_text("a\n")
        self.assertEqual(self.run_corpus("--matrix", str(self.dir / "matrix")).returncode, 0)
        ps2 = (self.out / "ps2.html").read_text()
        self.assertIn("<td>FAIL</td>", ps2)
        self.assertIn("nop &lt;1&gt;", ps2)
        self.assertIn("Not available", ps2)
        self.assertIn("a</code>: proved in CI by inductive_certificate", ps2)
        self.assertIn("no limits", (self.out / "nosuch.html").read_text())
        self.assertIn("not in CI's certificate matrix", (self.out / "nosuch.html").read_text())
        self.assertIn('class="bad">1<', (self.out / "index.html").read_text())

    def test_a_run_row_names_its_protocol(self):
        runs = self.dir / "runs.tsv"
        tsv(runs, "date protocol demo result attempts commit evidence".split(),
            [["2026-10-16", "ps2", "ps2_demo", "FAIL", "1", "abcdef012345", "ps2/ps2_demo"],
             ["2026-10-16", "other", "x", "PASS", "1", "abcdef012345", "other/x"]])
        self.assertEqual(self.run_corpus("--ledger", str(runs)).returncode, 0)
        ps2 = (self.out / "ps2.html").read_text()
        self.assertIn("<td>ps2_demo</td>", ps2)
        self.assertIn('<tr class="bad">', ps2)
        self.assertIn("Board runs tied to no protocol page", (self.out / "index.html").read_text())

    def test_same_inputs_same_bytes(self):
        self.run_corpus()
        first = (self.out / "corpus.sha256").read_text()
        self.run_corpus()
        self.assertEqual(first, (self.out / "corpus.sha256").read_text())

    def test_manifest_catches_an_edit(self):
        self.run_corpus()
        check = [sys.executable, str(HERE / "corpus.py"), "--check", str(self.out)]
        self.assertEqual(subprocess.run(check).returncode, 0)
        (self.out / "ps2.html").write_text("edited")
        self.assertNotEqual(subprocess.run(check, capture_output=True).returncode, 0)


if __name__ == "__main__":
    unittest.main()
