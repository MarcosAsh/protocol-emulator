# SPDX-License-Identifier: Apache-2.0
"""demo/bench_run.py against stand-ins for openFPGALoader, mpremote, sigrok-cli and dune, so
no board: the result folder, the row with its protocol, and the reset and retry."""

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
import sigrok  # noqa: E402
import traffic  # noqa: E402

# a load that fails once, then works, is HANG_ONCE: a file the stand-in removes
STANDINS = {
    "openFPGALoader": 'echo "$*" >> "$TMP/loads"\n'
                      '[ "$1 $2 $3" = "-b icepi-zero -r" ] && exit 0\n'
                      'exit "${LOAD:-0}"\n',
    "mpremote": """shift 2
case "$1 $*" in
cp*|exec*) ;;
cat*) printf '%s\\n' "${VERDICT:-PASS}" ;;
run*) ;;
esac
""",
    "sigrok-cli": """while [ $# -gt 0 ]; do
    case $1 in
    -o) if [ -n "$HANG" ]; then sleep 30; fi
        if [ -f "$TMP/hang_once" ]; then rm "$TMP/hang_once"; sleep 30; fi
        cp "$CAPTURE" "$2"; exit 0 ;;
    -i) cat "$DECODE"; exit 0 ;;
    esac
    shift
done
""",
    "dune": 'cat > /dev/null\necho "t_HD;STA ok"\nexit "${LIMITS_EXIT:-0}"\n',
}


class BenchRun(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        bin = self.tmp / "bin"
        bin.mkdir()
        for name, body in STANDINS.items():
            (bin / name).write_text("#!/bin/sh\n" + body)
            (bin / name).chmod(0o755)
        self.bit = self.tmp / "chip.bit"
        self.bit.write_bytes(b"bitstream")
        sigrok.write(self.tmp / "capture.sr", 12_000_000, bytes([0, 0xFF, 0]))
        p = traffic.demo_neopixel.PIXELS
        decode = self.tmp / "neopixel.decode"
        decode.write_text("".join(d + "\n" for d in traffic.stick([p, p[1:] + p[:1]])))
        self.env = {k: v for k, v in os.environ.items() if not k.startswith("ANALYSER")}
        self.env.update(PATH="%s:%s" % (bin, os.environ["PATH"]), PICO="id:a", TMP=str(self.tmp),
                        CAPTURE=str(self.tmp / "capture.sr"), DECODE=str(decode), TRIES="1",
                        # not the carrier's analyser ports, which only the bench has
                        DEVICE="fx2lafw")

    def run_bench(self, *args, **env):
        return subprocess.run(
            [sys.executable, str(ROOT / "demo/bench_run.py"), "neopixel",
             "--timeout-run", "10", *args,
             "--evidence", str(self.tmp / "evidence"), "--results", str(self.tmp / "runs.tsv")],
            env=self.env | env, capture_output=True, text=True, timeout=120)

    def rows(self):
        with open(self.tmp / "runs.tsv") as f:
            return list(csv.DictReader(f, delimiter="\t"))

    def test_folder_and_row(self):
        run = self.run_bench("--bitstream", str(self.bit),
                             "--measure", "sk6812", "--probe", "IO0=D4")
        self.assertEqual(run.returncode, 0, run.stdout + run.stderr)
        (row,) = self.rows()
        self.assertEqual((row["protocol"], row["demo"], row["result"], row["attempts"],
                          row["measured"]), ("ws2812", "neopixel", "PASS", "1", "hold"))
        self.assertEqual(row["bitstream_sha256"], ledger.sha256(self.bit))
        folder = self.tmp / "evidence" / row["evidence"]
        self.assertEqual(folder.parts[-2:], ("ws2812", "neopixel"))
        for name in ("neopixel.sr", "neopixel.decode", "neopixel.log", "measure.txt",
                     "result.txt", "SHA256SUMS", "attempt1/run.txt"):
            self.assertTrue((folder / name).exists(), name)
        self.assertEqual(row["capture_sha256"], ledger.sha256(folder / "neopixel.sr"))
        text = (folder / "result.txt").read_text()
        self.assertIn("verdict: PASS\n", text)
        self.assertIn("commit: " + row["commit"], text)
        subprocess.run(["sha256sum", "--quiet", "-c", "SHA256SUMS"], cwd=folder, check=True)

    def test_limit_failure_is_fail_without_retry(self):
        run = self.run_bench("--from-flash", "--measure", "sk6812", "--probe", "IO0=D4",
                             LIMITS_EXIT="1")
        self.assertEqual(run.returncode, 1)
        (row,) = self.rows()
        self.assertEqual((row["result"], row["attempts"], row["measured"]), ("FAIL", "1", "fail"))
        self.assertEqual(row["bitstream_sha256"], "flash")

    def test_hung_capture_resets_to_flash_and_retries(self):
        (self.tmp / "hang_once").write_text("")
        run = self.run_bench("--bitstream", str(self.bit), "--timeout-run", "3")
        self.assertEqual(run.returncode, 0, run.stdout + run.stderr)
        (row,) = self.rows()
        self.assertEqual((row["result"], row["attempts"]), ("PASS", "2"))
        loads = (self.tmp / "loads").read_text().splitlines()
        self.assertEqual(loads, ["-b icepi-zero %s" % self.bit, "-b icepi-zero -r"])
        folder = self.tmp / "evidence" / row["evidence"]
        self.assertIn("stopped after 3 s", (folder / "attempt1/run.txt").read_text())
        self.assertIn("attempt1: ERROR", (folder / "result.txt").read_text())
        self.assertTrue((folder / "attempt2/neopixel.sr").exists())

    def test_failed_load_is_recovered_from_flash(self):
        run = self.run_bench("--bitstream", str(self.bit), LOAD="1")
        self.assertEqual(run.returncode, 0, run.stdout + run.stderr)
        (row,) = self.rows()
        self.assertEqual((row["result"], row["attempts"]), ("PASS", "2"))

    def test_two_hung_attempts_are_an_error(self):
        run = self.run_bench("--bitstream", str(self.bit), "--timeout-run", "2", HANG="1")
        self.assertEqual(run.returncode, 1)
        (row,) = self.rows()
        self.assertEqual((row["result"], row["attempts"]), ("ERROR", "2"))

    def test_dry_run_runs_nothing(self):
        run = self.run_bench("--bitstream", str(self.bit), "--dry-run")
        self.assertEqual(run.returncode, 0, run.stderr)
        for word in ("openFPGALoader -b icepi-zero %s" % self.bit,
                     "demo/outside.sh neopixel", "-b icepi-zero -r"):
            self.assertIn(word, run.stdout)
        self.assertFalse((self.tmp / "evidence").exists())
        self.assertFalse((self.tmp / "runs.tsv").exists())
        self.assertFalse((self.tmp / "loads").exists())

    def test_needs_a_chip_source(self):
        self.assertIn("--bitstream", self.run_bench().stderr)


if __name__ == "__main__":
    unittest.main()
