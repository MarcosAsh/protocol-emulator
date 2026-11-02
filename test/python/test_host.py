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


def test_pop_reads_no_further_than_the_level():
    """A read of RX past rx_level reads 0 and drops a word the engine pushes during it
    (host_port.ml pops at the low byte's end), so pop never makes one."""
    rx, frames = [0x1234], []

    def transfer(data):
        frames.append((data[0] & 0x7F, (len(data) - 1) // 2))
        reg, count = frames[-1]
        if reg == pe.STATUS:
            words = [len(rx) << 10]
        else:
            words = [rx.pop(0) if reg == pe.RX and rx else 0 for _ in range(count)]
        return [0] + [b for w in words for b in ((w >> 8) & 0xFF, w & 0xFF)]

    host = pe.Host(transfer)
    assert host.pop(3) == [0x1234, 0, 0]
    assert frames == [(pe.STATUS, 1), (pe.RX, 1)], frames
    frames.clear()
    assert host.pop(2) == [0, 0]
    assert frames == [(pe.STATUS, 1)], frames


test_now_across_a_carry()
test_pop_reads_no_further_than_the_level()
