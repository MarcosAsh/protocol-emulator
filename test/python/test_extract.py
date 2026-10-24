# SPDX-License-Identifier: Apache-2.0
# demo/extract.py's comparison of two blind readings: equal limits written differently agree,
# a reading carrying one of the three misreads the 10-18 prior-art scout found disputes against
# an honest one at the right page, and only a person's ruling settles a dispute. The readings
# in extract/ are the readers' tables from the blind run of 2026-10-18.
import copy
import os
import sys
import tempfile

sys.path.insert(0, sys.argv[1])
import extract as ex

HERE = os.path.dirname(os.path.abspath(__file__))


def reading(name):
    return ex.parse(open(os.path.join(HERE, "extract", name + ".txt")).read())


def outcome(a, b, ruled=None):
    result = ex.compare(a, b, ruled)
    return ex.verdict("doc.pdf", result), ex.agreement(result)


def disputed(a, b):
    return [(d["symbol"], d["field"], d["a"], d["b"], d["pages"])
            for d in ex.compare(a, b)["disputes"]]


def test_written_differently():
    row = {"symbol": "tHD;DAT", "parameter": "", "condition": "Standard-mode (Note 2)",
           "min": "0.25", "typ": "", "max": "", "unit": "µs", "page": "44", "where": "Table 11"}
    other = dict(row, symbol="THD:DAT", condition="Standard-mode", min="250", unit="ns",
                 page="p. 44", where="Table 11. Characteristics")
    assert all(ex.same(f, row, other) for f in ex.FIELDS)
    assert ex.same("min", dict(row, min=">0.25"), row)
    assert ex.same("min", dict(row, unit="µ s"), row)
    assert not ex.same("max", dict(row, max=">0.25"), dict(row, max="0.25"))
    assert not ex.same("min", dict(row, min="300", unit="ns"), dict(row, min="0", unit="ns"))
    assert ex.same("where", dict(row, where="9. IC电气参数 IC electrical parameters"),
                   dict(row, where="9. IC electrical parameters"))
    assert ex.same_revision("DS20001203W", "W")
    assert ex.same_revision("Rev. 7.0", "7.0")
    assert not ex.same_revision("B/1", "1")
    assert not ex.same_revision("B/0", "B/1")
    assert ex.same("date", {"date": "1 October 2021"}, {"date": "2021-10-01"})
    assert not ex.same("date", {"date": "2025-08-11"}, {"date": "2024-03-02"})


def test_parse():
    text = "notes\nBEGIN LIMITS\ndocument\tX\tA\t2020\nsymbol\tparameter\n" \
        "tA\tsetup\t\t5\t\t\tns\t3\ttext\nEND LIMITS\nleft out: none"
    assert ex.parse(text)["rows"][0]["page"] == "3"
    for broken in ("BEGIN LIMITS\ndocument\tX\n", "symbol\tparameter\ntA\tsetup\n",
                   "document\tX\tA\t2020\n"):
        try:
            ex.parse(broken)
        except ValueError:
            continue
        raise AssertionError("parsed " + repr(broken))


def test_blind_run():
    assert outcome(reading("eeprom_24lc256_a"), reading("eeprom_24lc256_b")) == (
        "limit disputed, doc.pdf p.5",
        "agreement 287/292 fields (98.3%), 57 rows agreed, 5 fields disputed, 0 ruled")
    assert disputed(reading("eeprom_24lc256_a"), reading("eeprom_24lc256_b"))[2] == (
        "TOF", "max", "250", ex.ABSENT, [5])
    assert outcome(reading("i2c_um10204_a"), reading("i2c_um10204_b")) == (
        "limit disputed, doc.pdf p.21",
        "agreement 572/587 fields (97.4%), 114 rows agreed, 15 fields disputed, 0 ruled")
    assert outcome(reading("sk6812_a"), reading("sk6812_b")) == (
        "limit disputed, doc.pdf p.7",
        "agreement 57/62 fields (91.9%), 11 rows agreed, 5 fields disputed, 0 ruled")


def with_rows(base, change):
    out = copy.deepcopy(base)
    for row in out["rows"]:
        change(row)
    return out


def test_known_misreads():
    """Both blind readers got all three right, so each misread goes into one reading by hand."""
    eeprom = reading("eeprom_24lc256_a")
    params_2_to_10 = {"thigh", "tlow", "tr", "tf", "thdsta", "tsusta", "thddat", "tsudat",
                      "tsusto"}

    def old_pages(row):
        if ex.symbol_key(row) in params_2_to_10:
            row["page"] = "3"
        if ex.symbol_key(row) == "tbuf":
            row["page"] = "4"

    got = disputed(with_rows(eeprom, old_pages), reading("eeprom_24lc256_b"))
    assert ("THIGH", "page", "3", "4", [3, 4]) in got
    assert ("TBUF", "page", "4", "5", [4, 5]) in got
    assert outcome(with_rows(eeprom, old_pages), eeprom)[0] == "limit disputed, doc.pdf p.3/4"
    um10204 = reading("i2c_um10204_a")

    def table_10(row):
        if ex.symbol_key(row) == "fscl":
            row["where"] = "Table 10"

    got = disputed(with_rows(um10204, table_10), reading("i2c_um10204_b"))
    assert ("fSCL", "where", "Table 10", "Table 11", [44]) in got

    def hold_300(row):
        if ex.symbol_key(row) == "thddat" and row["condition"] == "I2C-bus devices; Standard-mode":
            row["min"] = "0.3"

    got = disputed(with_rows(um10204, hold_300), reading("i2c_um10204_b"))
    assert ("tHD;DAT", "min", "0.3", "0", [44]) in got
    # a superseded sheet read well twice agrees: both name Rev B/0 of 2024-03-02, and B/1's
    # T0H >= 0.25 us is not in it to read
    sk6812 = [reading("sk6812_" + r)["document"] for r in "ab"]
    assert [(d["revision"], d["date"]) for d in sk6812] == [("B/0", "2024-03-02")] * 2
    assert not [d for d in ex.compare(reading("sk6812_a"), reading("sk6812_b"))["disputes"]
                if d["symbol"] == "T0H"]


def test_rulings():
    a, b = reading("eeprom_24lc256_a"), reading("eeprom_24lc256_b")
    tof = {"symbol": "TOF", "condition": "All except 24FC256 (Note 1)"}
    page_4 = dict(zip(ex.FIELDS, ["10 + 0.1CB", "", "250", "5", "Table 1-2"]))
    ruled = {ex.ruling_key(tof, f): v for f, v in page_4.items()}
    assert outcome(a, b, ruled) == (
        "limits agreed, 58 rows, 5 fields ruled by hand",
        "agreement 287/292 fields (98.3%), 58 rows agreed, 0 fields disputed, 5 ruled")
    dropped = {ex.ruling_key(tof, f): ex.ABSENT for f in ex.FIELDS}
    assert outcome(a, b, dropped)[0] == "limits agreed, 57 rows, 5 fields ruled by hand"
    half = {ex.ruling_key(tof, "max"): "250"}
    assert outcome(a, b, half)[0] == "limit disputed, doc.pdf p.5"


def test_ruled_from_file():
    # a ruling read back from disputed.tsv can leave a field blank, and reaches a row one
    # reader wrote with no symbol, which the comparison keys by its parameter
    head = "document\tsheet\tRev. 1\t\nsymbol\tparameter\tcondition\tmin\ttyp\tmax\tunit\tpage\twhere\n"
    a = ex.parse(head + "\tclock frequency\t\t2\t\t\tMHz\t2\ttext\n"
                 "tDS\tsetup\t\t50\t\t\tns\t2\ttable\n")
    b = ex.parse(head + "fclk\tclock\t\t\t2\t\tMHz\t2\ttext\n"
                 "tDS\tsetup\t\t50\t\t\tns\t2\ttable\n")
    result = ex.compare(a, b)
    assert sorted({d["symbol"] for d in result["disputes"]}) == ["clock frequency", "fclk"]
    with tempfile.TemporaryDirectory() as run:
        ex.write(run, result, ex.verdict("doc.pdf", result))
        path = os.path.join(run, "disputed.tsv")
        lines = open(path).read().splitlines()
        ruled = [lines[0]]
        for line in lines[1:]:
            cells = line.split("\t")
            keep = {"typ": "2", "page": "2", "where": "text"}
            cells[-1] = (keep.get(cells[2], ex.EMPTY) if cells[0] == "fclk" else ex.ABSENT)
            ruled.append("\t".join(cells))
        open(path, "w").write("\n".join(ruled) + "\n")
        assert outcome(a, b, ex.rulings(path)) == (
            "limits agreed, 2 rows, 10 fields ruled by hand",
            "agreement 7/17 fields (41.2%), 2 rows agreed, 0 fields disputed, 10 ruled")
        fclk = [r for r in ex.compare(a, b, ex.rulings(path))["rows"] if r["symbol"] == "fclk"]
        assert [(r["min"], r["typ"], r["max"]) for r in fclk] == [("", "2", "")]
    # the document line's fields settle the same way
    dated = copy.deepcopy(b)
    dated["document"]["date"] = "Last updated: 1 May 2020"
    a["document"]["date"] = "1 May 2020"
    result = ex.compare(a, dated)
    assert [d["field"] for d in result["disputes"] if d["symbol"] == "document"] == ["date"]
    ruled = {ex.ruling_key({"symbol": "document", "condition": ""}, "date"): "1 May 2020"}
    assert not [d for d in ex.compare(a, dated, ruled)["disputes"] if d["symbol"] == "document"]


test_written_differently()
test_parse()
test_blind_run()
test_known_misreads()
test_rulings()
test_ruled_from_file()
