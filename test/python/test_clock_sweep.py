# SPDX-License-Identifier: Apache-2.0
# demo/clock_sweep.py's reading of a sweep against the sealed windows.
import sys

sys.path.insert(0, sys.argv[1])
import clock_sweep as cs

ROOT = sys.argv[2]


def test_outcomes():
    windows = cs.predictions(ROOT)
    w = windows["uart_tx_115200"]
    md5 = w["words_md5"]
    low, high = w["lowest_hz"], w["highest_hz"]
    assert cs.outcome(w, 48_000_000, md5, "pass", "works") == "ok"
    assert cs.outcome(w, low, md5, "pass", "-") == "ok"
    assert cs.outcome(w, high + 1, md5, "fail", "-") == "cliff"
    assert cs.outcome(w, low - 1, md5, "pass", "works").startswith("conservative")
    assert cs.outcome(w, high, md5, "fail", "-") == "UNSOUND"
    assert cs.outcome(w, high, md5, "pass", "fails") == "ok, DEVICE FAILS INSIDE"
    assert cs.outcome(w, high, "0" * 32, "pass", "-") == "WRONG IMAGE"


def test_plan():
    plan = dict(cs.plan(cs.predictions(ROOT), 2000))
    clocks = plan["sk6812"]
    assert 48_000_000 in clocks and len(clocks) == 5
    assert plan["i2c_standard"][0] == 48_000_000


test_outcomes()
test_plan()
