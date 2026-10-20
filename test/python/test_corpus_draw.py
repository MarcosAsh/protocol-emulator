# SPDX-License-Identifier: Apache-2.0
# demo/corpus_draw.py's rule and draw: the snapshot and pool are pinned, the round is the one
# announced, a past round replays to the same six, and the owner's exclusion list withholds
# exactly the decoders sealed in it whatever its padding.
import glob
import hashlib
import json
import os
import sys

sys.path.insert(0, sys.argv[1])
import corpus_draw as cd

HERE = os.path.dirname(os.path.abspath(__file__))
TRACES = sys.argv[2]
BEACON = json.load(open(os.path.join(HERE, "corpus_beacon_33000000.json")))["answers"]
RANDOMNESS = "3267554d34a7d7bbd3f547a168cda834dd94ca2f060386d48c49680ea9366cad"
SALT = "00" * 32


def nothing(_):
    return False


def test_pool():
    rows = cd.decoders()
    assert len(rows) == 131
    ids = cd.pool(rows)
    assert (len(ids), cd.digest(ids)) == (
        47, "204671810eda1e15d60fd4e9f261f13c4a9979fbe49f473952f325cde5bcc604")
    why = {d["id"]: cd.out_because(d) for d in rows}
    assert why["ir_nec"] is None and why["seven_segment"] is None and why["ieee488"] is None
    assert why["uart"] == "already in the library"
    assert why["eeprom24xx"] == "reads i2c, not pins (its timing is the bus beneath)"
    assert why["counter"] == "a measuring tool (tag Util), not a protocol"
    assert why["z80"] == "its channels are not a literal list in pd.py"
    assert cd.out_because(dict(rows[0], inputs="logic", tags="", channels="a,b,c,d,e,f,g,h,i",
                               optional_channels="", id="wide")) == "needs 9 channels, past 8"


def test_library():
    named = set()
    for path in glob.glob(os.path.join(TRACES, "**", "*.trace"), recursive=True):
        for line in open(path):
            if line.startswith("# sigrok decoder "):
                named.update(d.split(":")[0] for d in line.split()[3].split(","))
    assert set(cd.IN_LIBRARY) <= named, set(cd.IN_LIBRARY) - named


def test_round():
    assert cd.round_time(cd.ROUND).isoformat() == "2026-10-24T12:00:00+00:00"
    assert cd.round_time(cd.ROUND - 1).isoformat() == "2026-10-24T11:59:57+00:00"


def test_beacon():
    assert cd.check_beacon(33000000, BEACON) == (RANDOMNESS, BEACON["https://api.drand.sh"][
        "signature"])
    for bad in ({"randomness": "00" * 32}, {"round": 33000001}):
        answers = {"https://api.drand.sh": dict(BEACON["https://api.drand.sh"], **bad)}
        try:
            cd.check_beacon(33000000, answers)
        except SystemExit:
            continue
        raise AssertionError("took %r" % bad)
    split = dict(BEACON, **{"https://api2.drand.sh": dict(BEACON["https://api2.drand.sh"],
                                                          randomness="00" * 32)})
    try:
        cd.check_beacon(33000000, split)
    except SystemExit as e:
        assert "relays disagree" in str(e)
    else:
        raise AssertionError("relays disagreed and the draw went on")


def test_draw():
    ids = cd.pool()
    seed = bytes.fromhex(RANDOMNESS)
    assert min(ids, key=lambda i: hashlib.sha256(seed + i.encode()).digest()) == "morse"
    picks, withheld = cd.draw(RANDOMNESS, ids, nothing)
    assert picks == [(1, "morse"), (2, "flexray"), (3, "wiegand"), (4, "stepper_motor"),
                     (5, "sle44xx"), (6, "t55xx")]
    assert withheld == 0
    sealed = cd.seal(["flexray", "sle44xx", "not_a_decoder"], salt=SALT)
    assert len(sealed.splitlines()) == 1 + cd.PAD
    assert "flexray" not in sealed
    picks, withheld = cd.draw(RANDOMNESS, ids, cd.excluded(sealed))
    assert [d for _, d in picks] == ["morse", "wiegand", "stepper_motor", "t55xx", "em4305",
                                     "ook"]
    assert (picks[-1][0], withheld) == (8, 2)
    another = cd.seal(["flexray", "sle44xx"], pad=100)
    assert cd.draw(RANDOMNESS, ids, cd.excluded(another)) == (picks, withheld)


def test_record():
    sealed = cd.seal([], salt=SALT, pad=0)
    text = cd.record(33000000, BEACON, RANDOMNESS, "ab", sealed, cd.decoders())
    assert "REHEARSAL: the announced round is 33346612 (2026-10-24T12:00:00+00:00)\n" in text
    assert "0 of the first 6 withheld" in text
    assert text.endswith("6\tt55xx\tdata\tRFID T55xx\n"), text


test_pool()
test_library()
test_round()
test_beacon()
test_draw()
test_record()
