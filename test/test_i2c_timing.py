# SPDX-License-Identifier: Apache-2.0
# demo/i2c_timing.py on two synthetic Standard-mode captures at 10 MHz, 100 ns a sample:
# a clean one, and one with a transaction per violation and three within a sample of
# their limit. The sigrok decoder must flag the same samples, when sigrok-cli is here.
# Usage: python3 test/test_i2c_timing.py

import os
import re
import shutil
import subprocess
import sys
import tempfile

DEMO = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "demo")
sys.path.insert(0, DEMO)
import i2c_timing  # noqa: E402
import sigrok  # noqa: E402

RATE = 10_000_000
# samples: each clears its Standard-mode limit by more than a sample
CLEAN = {"hd_sta": 50, "hd_dat": 10, "su_dat": 40, "high": 55, "su_sta": 50, "su_sto": 50,
         "buf": 60}


# transaction, its changes from CLEAN, and the (parameter, verdict) pairs it is flagged with
BAD = [
    ("first", {}, set()),
    ("hd_sta", {"hd_sta": 30}, {("tHD;STA", "fail")}),
    ("su_sta", {"su_sta": 40}, {("tSU;STA", "fail")}),
    ("su_sto", {"su_sto": 30}, {("tSU;STO", "fail")}),
    ("buf", {"buf": 30}, {("tBUF", "fail")}),
    # these two keep each period over the 100 samples 100 kHz allows
    ("low", {"su_dat": 30, "high": 65}, {("tLOW", "fail")}),
    ("high", {"su_dat": 65, "high": 30}, {("tHIGH", "fail")}),
    ("su_dat", {"hd_dat": 49, "su_dat": 1}, {("tSU;DAT", "fail")}),
    ("fast", {"high": 45}, {("fSCL", "fail")}),
    ("near_hd_sta", {"hd_sta": 40}, {("tHD;STA", "unsure")}),
    ("near_su_dat", {"hd_dat": 47, "su_dat": 3}, {("tSU;DAT", "unsure")}),
    ("zero_hold", {"hd_dat": 0, "su_dat": 50}, {("tHD;DAT", "unsure")}),
]


class Bus:
    """SCL on D7 and SDA on D6, as on the bench; marks name samples for the expectations."""

    def __init__(self):
        self.samples = bytearray()
        self.scl = self.sda = 1
        self.marks = {}

    def hold(self, n):
        self.samples += bytes([(self.scl << 7) | (self.sda << 6)]) * n

    def mark(self, name):
        self.marks[name] = len(self.samples)

    def bit(self, value, t, name=None):
        """From SCL high: SCL falls, SDA takes value, SCL rises and stays high."""
        self.scl = 0
        if name:
            self.mark(name + ".fall")
        self.hold(t["hd_dat"])
        self.sda = value
        if name:
            self.mark(name + ".sda")
        self.hold(t["su_dat"])
        self.scl = 1
        if name:
            self.mark(name + ".rise")
        self.hold(t["high"])

    def byte(self, value, t, name=None, at=None):
        """Eight bits and the ACK; the bit numbered [at] gets [name]'s marks."""
        for i in range(9):
            self.bit((value >> (7 - i)) & 1 if i < 8 else 0, t, name if i == at else None)

    def transaction(self, name, **changes):
        """START, a byte, a repeated START, a byte, STOP: each time from CLEAN unless
        changed, and marks named for each condition."""
        t = dict(CLEAN, **changes)
        self.hold(t["buf"])
        self.mark(name + ".start")
        self.sda = 0
        self.hold(t["hd_sta"])
        self.byte(0xA0, t, name + ".bit", at=3)
        self.bit(1, dict(t, high=t["su_sta"]))
        self.mark(name + ".sr")
        self.sda = 0
        self.hold(t["hd_sta"])
        self.byte(0x55, t)
        self.bit(0, dict(t, high=t["su_sto"]))
        self.mark(name + ".stop")
        self.sda = 1


def write(bus, directory, name):
    bus.hold(100)
    path = os.path.join(directory, name + ".sr")
    sigrok.write(path, RATE, bus.samples)
    return path


def flagged(results):
    return sorted(
        (r.parameter, r.verdict, r.ss, r.es) for r in results if r.verdict != "pass")


def sigrok_flags(path):
    """The decoder's own fails and can't-tells, by sigrok-cli."""
    env = dict(os.environ, SIGROKDECODE_DIR=os.path.join(DEMO, "decoders"))
    out = subprocess.run(
        ["sigrok-cli", "-i", path, "-P", "i2c_timing:scl=D7:sda=D6", "-A",
         "i2c_timing=fail:unsure", "--protocol-decoder-samplenum"],
        env=env, capture_output=True, text=True, check=True).stdout
    return sorted(
        (int(a), int(b), text)
        for a, b, text in re.findall(r"^(\d+)-(\d+) i2c_timing-1: (.*)$", out, re.M))


def main():
    with tempfile.TemporaryDirectory() as directory:
        clean = Bus()
        clean.transaction("a")
        clean.transaction("b")
        clean_path = write(clean, directory, "clean")
        _, results, stray = i2c_timing.check(clean_path, "standard")
        assert stray == 0, stray
        assert flagged(results) == [], flagged(results)
        seen = {r.parameter for r in results}
        assert seen == {"fSCL", "tHD;STA", "tLOW", "tHIGH", "tSU;STA", "tHD;DAT", "tSU;DAT",
                        "tSU;STO", "tBUF"}, seen

        bad = Bus()
        for name, changes, _ in BAD:
            bad.transaction(name, **changes)
        bad_path = write(bad, directory, "bad")
        _, results, _ = i2c_timing.check(bad_path, "standard")
        m = bad.marks
        stops = [0] + [m[name + ".stop"] for name, _, _ in BAD]
        for (name, _, flags), after, stop in zip(BAD, stops, stops[1:]):
            mine = {(r.parameter, r.verdict) for r in results
                    if after < r.es <= stop and r.verdict != "pass"}
            assert mine == flags, (name, mine)
        flags = {(r.parameter, r.verdict, r.ss, r.es) for r in results}
        for expect in [
            ("tHD;STA", "fail", m["hd_sta.start"], m["hd_sta.start"] + 30),
            ("tHD;STA", "fail", m["hd_sta.sr"], m["hd_sta.sr"] + 30),
            ("tSU;STA", "fail", m["su_sta.sr"] - 40, m["su_sta.sr"]),
            ("tSU;STO", "fail", m["su_sto.stop"] - 30, m["su_sto.stop"]),
            ("tBUF", "fail", m["buf.start"] - 30, m["buf.start"]),
            ("tLOW", "fail", m["low.bit.fall"], m["low.bit.rise"]),
            ("tHIGH", "fail", m["high.bit.rise"], m["high.bit.rise"] + 30),
            ("tSU;DAT", "fail", m["su_dat.bit.sda"], m["su_dat.bit.rise"]),
            ("tHD;STA", "unsure", m["near_hd_sta.start"], m["near_hd_sta.start"] + 40),
            ("tSU;DAT", "unsure", m["near_su_dat.bit.sda"], m["near_su_dat.bit.rise"]),
            ("tHD;DAT", "unsure", m["zero_hold.bit.fall"], m["zero_hold.bit.fall"]),
        ]:
            assert expect in flags, expect

        # every fault here is a Standard-mode one
        _, results, _ = i2c_timing.check(bad_path, "fast")
        assert not [r for r in results if r.verdict == "fail"]

        if shutil.which("sigrok-cli"):
            for path in clean_path, bad_path:
                _, results, _ = i2c_timing.check(path, "standard")
                mine = sorted((r.ss, r.es, r.text) for r in results if r.verdict != "pass")
                assert sigrok_flags(path) == mine, path
            print("sigrok's i2c_timing decoder flags the same samples")
        else:
            print("no sigrok-cli: the decoder itself is not run")
    print("i2c timing: the clean capture passes, each planted fault flagged at its samples")


if __name__ == "__main__":
    main()
