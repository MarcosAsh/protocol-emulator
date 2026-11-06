# SPDX-License-Identifier: Apache-2.0
# Checks that demo/margins.py judges a DS18B20 sweep from the replies alone. With no part on
# the wire every read is 0xff, before the sweep and during it, and no point may pass.
import sys

sys.path.insert(0, sys.argv[1])
import margins  # noqa: E402

ABSENT = [0xFF] * 8
# the ROM a DS18B20 sends: family 0x28, a serial, then the CRC of those seven bytes
ROM = [0x28, 0x61, 0x64, 0x12, 0x3C, 0x7C, 0x2F]
ROM.append(margins.crc8(ROM))


def judged(present, rom):
    """Two repeats of the read sample point: a reset, READ ROM and its eight bytes each."""
    reply = [0 if present else 1, 0x33] + rom
    out = {"before": [present, rom, [0xFF] * 9], "after": [present, rom, [0xFF] * 9],
           "replies": [reply, reply], "stopped": None}
    ok, _ = margins.judge({"part": "DS18B20", "parameter": "read sample"}, out, 2)
    return ok


def test_no_part_passes_no_point():
    assert judged(True, ROM) == [True, True]
    assert judged(False, ABSENT) == [False, False]


test_no_part_passes_no_point()
