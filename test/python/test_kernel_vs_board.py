# SPDX-License-Identifier: Apache-2.0
# Checks how demo/kernel_vs_board.py reads the Pico's lines. Each pairing of the kernel's
# verdict and what the board did gets its own word, and a late accepted variant is unsound.
# With the chip's check on, the board is held to chip_model.
import sys

sys.path.insert(0, sys.argv[1])
import kernel_vs_board as kvb


def verdict(accepted, line, chip=False, model="accepted"):
    result = kvb.parse(line)
    result["chip"] = chip
    return kvb.outcome({"accepted": accepted, "chip_model": model}, result).split()[0]


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
    assert verdict(True, refused) == "MISMATCH"
    assert verdict(False, refused) == "ok"
    assert verdict(False, started) == "BUG"
    assert kvb.parse("DONE") is None


def test_chip_outcomes():
    on_time = "RESULT uart_tx 3 ran 28 0 0 0 0"
    missed = "RESULT uart_tx 6 ran 28 0 0 10 0"
    refused = "RESULT uart_tx 6 refused 9 0 1"
    started = "RESULT uart_tx 6 refused 9 0 0"
    no = "refused: pc 9: spacing"
    assert verdict(True, on_time, chip=True) == "ok"
    assert verdict(False, refused, chip=True, model=no) == "ok"
    assert verdict(True, refused, chip=True, model=no) == "gap"
    assert verdict(True, refused, chip=True) == "MISMATCH"
    assert verdict(True, on_time, chip=True, model=no) == "MISMATCH"
    assert verdict(False, on_time, chip=True) == "pessimism"
    assert verdict(True, missed, chip=True) == "UNSOUND"
    assert verdict(False, missed, chip=True) == "UNSOUND"
    assert verdict(False, started, chip=True, model=no) == "BUG"
    result = dict(kvb.parse(refused), chip=True)
    assert "spacing" in kvb.outcome({"accepted": True, "chip_model": no}, result)


def test_summary():
    variants = [{"firmware": "uart_tx", "k": k, "wait_pc": 5, "slack": 2, "accepted": k < 3}
                for k in range(4)]
    results = [{"firmware": "uart_tx", "k": 0, "board": "ran", "out": 0, "fault0": 0,
                "outcome": "ok accepted, on time"},
               {"firmware": "uart_tx", "k": 1, "board": "refused",
                "outcome": "gap the chip refuses what the kernel accepts"}]
    row = kvb.summary(variants, results).splitlines()[1].split()
    # unsound, pessimism, gap, mismatches
    assert row[-4:] == ["0", "0", "1", "0"]


def test_batch_script():
    variant = {"firmware": "jtag", "k": 1, "words": [1, 2], "certificate": [3]}
    assert "[[\"jtag\", 1, [1, 2], None]]" in kvb.batch_script([variant], chip=False)
    assert "[[\"jtag\", 1, [1, 2], [3]]]" in kvb.batch_script([variant], chip=True)


test_outcomes()
test_chip_outcomes()
test_summary()
test_batch_script()
