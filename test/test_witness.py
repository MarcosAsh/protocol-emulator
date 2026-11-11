# SPDX-License-Identifier: Apache-2.0
"""Checks that demo/witness.py actually rejects bad input, on a copy of
test/board/self_timing. Each of these must fail: an edited file, a SHA256SUMS regenerated
to match it, firmware the board didn't run, and a witness.json that claims more than the
capture shows. Window sources, PARTIAL and the learn runs get theirs on copies too. The
kernel-vs-board and fault judges get what their teeth don't try."""

import hashlib
import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "demo"))
import learn_witness  # noqa: E402
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


def copy(name):
    """Returns a scratch copy of test/board/name, removed when the test ends."""
    scratch = Path(tempfile.mkdtemp())
    unittest.addModuleCleanup(shutil.rmtree, scratch)
    return Path(shutil.copytree(ROOT / "test/board" / name, scratch / name))


def edit(directory, change):
    path = directory / "witness.json"
    w = json.loads(path.read_text())
    change(w)
    path.write_text(json.dumps(w, indent=2) + "\n")


class Sources(unittest.TestCase):
    """Each window names where its limit comes from, and a PASS line counts our own apart."""

    def witnesses(self):
        return {p.parent.name: json.loads(p.read_text())
                for p in (ROOT / "test/board").glob("*/witness.json")}

    def test_every_window_has_a_source(self):
        for name, w in self.witnesses().items():
            for r in w.get("timing", []):
                self.assertIn(r["source"], witness.SOURCES, (name, r["parameter"]))

    def test_own_windows_are_not_spec(self):
        w = self.witnesses()
        for name in ("ir_rc6", "nec"):
            self.assertEqual(w[name]["proved"]["spec"], 0, name)
            self.assertEqual(w[name]["proved"]["own"], len(w[name]["timing"]), name)
        self.assertEqual(w["wiegand"]["proved"],
                         {"spec": 1, "own": 4, "decoder": 1, "derived": 0})
        self.assertEqual([r["source"] for r in w["spdif"]["timing"]
                          if r["parameter"].startswith("a block of 192 frames")],
                         ["derived", "derived"])

    def test_the_line_counts_them_apart(self):
        said = witness.says(self.witnesses()["wiegand"])
        self.assertIn("6 of 6 windows proved (1 spec, 4 own, 1 decoder), 0 unresolved", said)

    def test_a_source_claimed(self):
        run = copy("self_timing")
        edit(run, lambda w: [r.update(source="spec") for r in w["timing"]])
        self.assertTrue(any("witness.json's timing is not what the run makes" in p
                            for p in witness.check(run)[0]))

    def test_a_tally_claimed(self):
        run = copy("self_timing")
        edit(run, lambda w: w["proved"].update(spec=3, own=0))
        self.assertTrue(any("witness.json's proved is not what the run makes" in p
                            for p in witness.check(run)[0]))


class Partial(unittest.TestCase):
    """A run that passes on part of the protocol it names says PARTIAL and what it leaves out."""

    def test_the_partial_runs(self):
        self.assertEqual(sorted(n for n, d in witness.DEMOS.items() if d.partial),
                         ["dmx512", "lin", "spdif"])

    def test_the_line_says_partial(self):
        done = subprocess.run([sys.executable, "demo/witness.py", "check", str(copy("lin"))],
                              cwd=ROOT, capture_output=True, text=True)
        self.assertEqual(done.returncode, 0, done.stdout)
        line = done.stdout.splitlines()[-1]
        self.assertTrue(line.startswith("PARTIAL lin: "), line)
        self.assertTrue(line.endswith("without the response: no slave on the bench answers "
                                      "the header"), line)

    def test_partial_dropped(self):
        run = copy("lin")
        edit(run, lambda w: w.update(partial=None))
        self.assertTrue(any("witness.json's partial is not what the run makes" in p
                            for p in witness.check(run)[0]))


class Learn(unittest.TestCase):
    """A learn run's message must decode once for each frame sent, so a bit flipped in one
    frame is refused."""

    def test_each_frame(self):
        self.assertEqual(learn_witness.short(b"a\nb\na\nb\n", ["a\nb"], 2), [])
        self.assertEqual(learn_witness.short(b"a\nb\na\nc\n", ["a\nb"], 2),
                         ["sigrok's decode reads 'a\\nb' in 1 of the 2 frames sent"])

    def test_a_local_tooth(self):
        run = copy("learn_rc5")
        problems, bitten = learn_witness.check(run)
        self.assertEqual(problems, [])
        self.assertEqual(len(bitten), 1)
        self.assertIn("in 1 of the 2 frames sent", bitten[0][1])

    def test_provenance(self):
        for p in (ROOT / "test/board").glob("learn_*/witness.json"):
            w = json.loads(p.read_text())
            self.assertRegex(w["time"], r"^2026-11-03T08:\d\d:\d\d$", p)
            self.assertRegex(w["commit"], r"^[0-9a-f]{40}$", p)
            self.assertEqual(set(w["host_scripts"]), set(learn_witness.SCRIPTS), p)

    def test_firmware_claimed(self):
        run = copy("learn_rc5")
        edit(run, lambda w: w["firmware"].update({"firmware.asm": "0" * 64}))
        self.assertIn("witness.json's firmware is not the firmware.asm SHA256SUMS lists",
                      learn_witness.check(run)[0])


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


class FaultRelease(unittest.TestCase):
    def test_another_script(self):
        tree = witness.in_tree

        def edited(path):
            data = tree(path)
            return data.replace(b"57348", b"57349", 1) if path == witness.FAULT_SCRIPT else data

        witness.in_tree = edited
        self.addCleanup(setattr, witness, "in_tree", tree)
        problems = witness.fault_judge(witness.fault_run(ROOT / "test/board/fault_release"))[1]
        self.assertIn("python/demo_fault_release.py's FAULT is not test/fault_release_low.hex",
                      problems)


if __name__ == "__main__":
    unittest.main()
