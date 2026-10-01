# SPDX-License-Identifier: Apache-2.0
# The host library against a fake core whose clock runs on between SPI frames.
import sys

sys.path.insert(0, sys.argv[1])
import protocol_emulator as pe

# cycles a frame takes, 24 SCK bits and the gaps
FRAME = 300


def test_now_across_a_carry():
    for start in range(0xFE00, 0x10200, 7):
        clock = [start]

        def transfer(data):
            reg = data[0] & 0x7F
            value = {pe.NOW_LO: clock[0] & 0xFFFF, pe.NOW_HI: (clock[0] >> 16) & 0xFF}.get(reg, 0)
            clock[0] += FRAME
            return [0] + [(value >> 8) & 0xFF, value & 0xFF] * ((len(data) - 1) // 2)

        got = pe.Host(transfer).now()
        assert start <= got <= clock[0], (hex(start), hex(clock[0]), hex(got))


test_now_across_a_carry()
