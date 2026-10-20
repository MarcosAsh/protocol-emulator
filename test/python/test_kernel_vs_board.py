# SPDX-License-Identifier: Apache-2.0
# demo/kernel_vs_board.py's reading of the Pico's lines: every pairing of the kernel's
# verdict with what the board did gets its own word, and a late accepted variant is unsound.
import sys

sys.path.insert(0, sys.argv[1])
import kernel_vs_board as kvb


def verdict(accepted, line, chip=False):
    result = kvb.parse(line)
    result["chip"] = chip
    return kvb.outcome({"accepted": accepted}, result).split()[0]


def test_outcomes():
    on_time = "RESULT uart_tx 3 ran 28 0 0 0 0"
    within = "RESULT can 3 ran 20 2 0 0 0"
    missed = "RESULT uart_tx 6 ran 28 0 0 10 0"
    moved = "RESULT uart_tx 6 ran 20 0 8 0 0"
    refused = "RESULT uart_tx 6 refused 9 0 1"
    started = "RESULT uart_tx 6 refused 9 0 0"
    assert verdict(True, on_time) == "ok"
    assert verdict(True, within) == "ok"
    assert verdict(True, missed) == "UNSOUND"
    assert verdict(True, moved) == "UNSOUND"
    assert verdict(False, missed) == "ok"
    assert verdict(False, on_time) == "pessimism"
    assert verdict(False, on_time, chip=True) == "MISMATCH"
    assert verdict(False, refused, chip=True) == "ok"
    assert verdict(True, refused, chip=True) == "MISMATCH"
    assert verdict(False, started, chip=True) == "BUG"
    assert kvb.parse("DONE") is None


def test_batch_script():
    variant = {"firmware": "jtag", "k": 1, "words": [1, 2], "certificate": [3]}
    assert "[[\"jtag\", 1, [1, 2], None]]" in kvb.batch_script([variant], chip=False)
    assert "[[\"jtag\", 1, [1, 2], [3]]]" in kvb.batch_script([variant], chip=True)


test_outcomes()
test_batch_script()
