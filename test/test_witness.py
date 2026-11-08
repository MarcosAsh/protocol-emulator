# SPDX-License-Identifier: Apache-2.0
"""Checks that demo/witness.py actually rejects bad input, on a copy of
test/board/self_timing. Each of these must fail: an edited file, a SHA256SUMS regenerated
to match it, firmware the board didn't run, and a witness.json that claims more than the
capture shows. The kernel-vs-board judge gets what its teeth don't try."""

import hashlib
import json
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "demo"))
import witness  # noqa: E402

BOARD = ROOT / "test/board/self_timing"


class Witness(unittest.TestCase):
    def setUp(self):
        self.dir = Path(tempfile.mkdtemp()) / "self_timing"
        shutil.copytree(BOARD, self.dir)
        self.addCleanup(shutil.rmtree, self.dir.parent)

    def problems(self):
        return witness.check(self.dir)[0]

    def refused(self, why):
        problems = self.problems()
        self.assertTrue(any(why in p for p in problems), problems)

    def test_the_copy_passes(self):
        self.assertEqual(self.problems(), [])

    def test_an_edited_log(self):
        log = self.dir / "self_timing.log"
        log.write_text(log.read_text().replace("0x4a", "0x4b", 1))
        self.refused("self_timing.log does not match SHA256SUMS")

    def test_sums_made_again(self):
        log = self.dir / "self_timing.log"
        log.write_text(log.read_text().replace("0x4a", "0x4b", 1))
        sums = self.dir / "SHA256SUMS"
        lines = [("%s  self_timing.log" % hashlib.sha256(log.read_bytes()).hexdigest())
                 if line.endswith("self_timing.log") else line
                 for line in sums.read_text().splitlines()]
        sums.write_text("\n".join(lines) + "\n")
        self.refused("SHA256SUMS is not the one the ledger row names")

    def test_other_firmware(self):
        tree = witness.in_tree

        def edited(path):
            data = tree(path)
            return data.replace(b"0", b"1", 1) if path.endswith("edge_logger_echo.hex") else data

        witness.in_tree = edited
        self.addCleanup(setattr, witness, "in_tree", tree)
        self.refused("test/edge_logger_echo.hex is not the firmware the board ran")

    def test_a_window_claimed(self):
        path = self.dir / "witness.json"
        w = json.loads(path.read_text())
        w["timing"][0]["measured"] = "104.00 us to 104.30 us"
        path.write_text(json.dumps(w, indent=2) + "\n")
        self.refused("witness.json's timing is not what the run makes")


class KernelVsBoard(unittest.TestCase):
    """What the teeth leave alone, as they change results.jsonl and board.log together."""

    def problems(self, change):
        run = witness.kvb_run(ROOT / "test/board/kernel_vs_board")
        change(run)
        return witness.kvb_judge(run)[1]

    def test_the_run_passes(self):
        self.assertEqual(self.problems(lambda run: None), [])

    def test_a_row_board_log_does_not_have(self):
        problems = self.problems(lambda run: run["rows"][0].update(exact=9))
        self.assertIn("jtag k=0 is not board.log's last RESULT line for it", problems)

    def test_a_model_the_board_ran_against(self):
        problems = self.problems(
            lambda run: run["variants"][0].update(chip_model="refused: pc 9: in time"))
        self.assertIn("uart_tx k=0: MISMATCH the chip ran what its model refuses", problems)


if __name__ == "__main__":
    unittest.main()
