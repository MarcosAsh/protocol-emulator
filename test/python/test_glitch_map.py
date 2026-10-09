# SPDX-License-Identifier: Apache-2.0
# demo/glitch_map.py's reading of the Pico's lines: a frame agrees with the rows only when
# its bytes and its framing error both do, and a fault is never an agreement.
import sys

sys.path.insert(0, sys.argv[1])
import glitch_map as gm


def verdict(predict, framing_error, line):
    return gm.verdict({"predict": predict, "framing_error": framing_error}, gm.parse(line))


def test_verdicts():
    assert verdict([0xFE], False, "RESULT 24 0 0 0 fe") == "ok"
    assert verdict([0xFE], False, "RESULT 24 0 0 0 ff") == "DIFFERS"
    assert verdict([0xFF], True, "RESULT 150 0 1 0 ff") == "ok"
    assert verdict([0xFF], True, "RESULT 150 0 0 0 ff") == "DIFFERS"
    assert verdict([0xFF, 0xFF], False, "RESULT 160 1 0 0 ff ff") == "ok"
    assert verdict([0xFF, 0xFF], False, "RESULT 160 1 0 0 ff") == "DIFFERS"
    assert verdict([0xFF], False, "RESULT 30 0 0 8 ff") == "FAULT 8"
    assert gm.parse("DONE") is None


def test_summary():
    images = [{"k": k, "predict": [0xFF], "framing_error": False} for k in (23, 25)]
    images.insert(1, {"k": 24, "predict": [0xFE], "framing_error": False})
    results = [dict(gm.parse(line), verdict="ok")
               for line in ("RESULT 23 0 0 0 ff", "RESULT 24 0 0 0 fe", "RESULT 25 0 0 0 ff")]
    text = gm.summary(images, results)
    assert "23        ff                  ff\n24        fe" in text, text
    assert "3 frames over 3 of 3 k: 3 as the rows say, 0 not" in text
    assert "bit 0 cleared at k = 24\n" in text


def test_batch_script():
    head = {"receiver": [1, 2], "config": {"in_base": 20}}
    script = gm.batch_script(head, [{"k": 17, "words": [3], "config": {"set_base": 20}}], 2)
    assert "def run(" in script
    assert "run(spi.transfer, [1, 2], {\"in_base\": 20}, [[17, [3], {\"set_base\": 20}]], " \
        "frames=2)" in script


test_verdicts()
test_summary()
test_batch_script()
