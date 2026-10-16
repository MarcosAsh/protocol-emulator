# SPDX-License-Identifier: Apache-2.0
"""demo/speed.py: rows only for a protocol that started, the first row of a stage counts, and
the table's minutes."""

import io
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "demo"))
import speed  # noqa: E402


class Speed(unittest.TestCase):
    def setUp(self):
        self.tsv = Path(tempfile.mkdtemp()) / "speed.tsv"

    def mark(self, stage, at, if_started=False, protocol="p"):
        speed.mark(self.tsv, protocol, stage, at, "", if_started)

    def table(self):
        out = io.StringIO()
        with redirect_stdout(out):
            speed.table(self.tsv)
        return out.getvalue().splitlines()[-1].split()

    def test_unstarted_protocol_gets_no_row(self):
        self.mark("bench", None, if_started=True)
        self.assertFalse(self.tsv.exists())
        self.mark("spec", "2026-10-15T10:00:00+01:00")
        self.mark("bench", "2026-10-15T10:30:00+01:00", if_started=True, protocol="other")
        self.assertEqual(len(speed.rows(self.tsv)), 1)

    def test_minutes_and_first_row(self):
        for stage, at in [("spec", "10:00:00"), ("file", "10:30:00"), ("certificate", "10:45:00"),
                          ("bench", "11:00:00"), ("bench", "12:00:00")]:
            self.mark(stage, "2026-10-15T%s+01:00" % at)
        self.assertEqual(self.table(), ["p", "30.0", "15.0", "15.0", "45.0", "60.0"])

    def test_missing_stage_is_a_dash(self):
        self.mark("spec", "2026-10-15T10:00:00+01:00")
        self.assertEqual(self.table(), ["p", "-", "-", "-", "-", "-"])

    def test_committed_ps2_row(self):
        committed = Path(speed.__file__).with_name("speed.tsv")
        self.assertIn("ps2", {r["protocol"] for r in speed.rows(committed)})


if __name__ == "__main__":
    unittest.main()
