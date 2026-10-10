# SPDX-License-Identifier: Apache-2.0
# Holds a CAN capture to the kernel's edges. The host sends only the ID, control and data
# bits; the chip adds the stuff bits and the CRC-15, and the kernel places each edge it
# drives on a deadline a whole bit from SOF. Every edge from SOF to the CRC delimiter must
# be where the line built here puts it, none missing or extra. For can_node, also where
# the chip's ACK lands in each of Pico B's frames, a whole number of bits after the last
# falling edge it resynced on. D5 is the bus, CAN module A's R.
# Usage: python3 demo/post_freeze.py can|can_node DEMO.sr

import sys
from pathlib import Path

import sigrok
import traffic

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "python"))
import demo_can  # noqa: E402
import demo_can_node  # noqa: E402

CLOCK_HZ = 48_000_000
CHANNEL = 5
# SOF follows at least this many recessive bits, ACK delimiter and EOF among them
IDLE_BITS = 10


def stuffed(bits):
    """CAN's stuffing: after five equal bits, their complement."""
    out, run, last = [], 0, None
    for bit in bits:
        out.append(bit)
        run = run + 1 if bit == last else 1
        last = bit
        if run == 5:
            out.append(1 - bit)
            run, last = 1, 1 - bit
    return out


def line(ident, rtr, dlc, data):
    """SOF to the CRC delimiter as the node puts them on the bus, and the stuff bits."""
    fields = [0] + traffic.bits(ident, 11) + [rtr, 0, 0] + traffic.bits(dlc, 4)
    for byte in data:
        fields += traffic.bits(byte, 8)
    body = stuffed(fields + traffic.bits(traffic.crc15(fields), 15))
    return body + [1], len(body) - len(fields) - 15


def frames(at, to, bit):
    """Each SOF's sample, and the edges from it to the next SOF."""
    sofs = [i for i in range(len(at))
            if to[i] == 0 and (i == 0 or at[i] - at[i - 1] >= IDLE_BITS * bit)]
    return [(at[s], list(zip(at[s:e], to[s:e])))
            for s, e in zip(sofs, sofs[1:] + [len(at)])]


def check_sent(sof, edges, ident, rtr, dlc, data, bit, cycle):
    """The problems with one frame the chip sent, each edge's error in samples with the
    level it goes to, and the stuff bits."""
    bus, stuff = line(ident, rtr, dlc, data)
    want = [(n, bus[n]) for n in range(1, len(bus)) if bus[n] != bus[n - 1]]
    end = sof + (len(bus) - 0.5) * bit
    got = [(a, level) for a, level in edges[1:] if a < end]
    name = "id 0x%03x" % ident
    if [level for _, level in got] != [level for _, level in want]:
        return ["%s: %d edges, the line has %d" % (name, len(got), len(want))], None, stuff
    errors = [(a - sof - n * bit, level) for (a, level), (n, _) in zip(got, want)]
    problems = ["%s: edge %d is %.1f samples (%.0f cycles) off its bit"
                % (name, k + 1, e, e * cycle) for k, (e, _) in enumerate(errors)
                if abs(e) > bit / 8]
    return problems, errors, stuff


def check_ack(sof, edges, ident, rtr, dlc, data, bit):
    """Where the chip's ACK in Pico B's frame falls, from the last falling edge before it."""
    bus, _ = line(ident, rtr, dlc, data)
    slot = len(bus)
    before = [(a, level) for a, level in edges if a < sof + (slot - 0.5) * bit]
    ack = [(a, level) for a, level in edges if a >= sof + (slot - 0.5) * bit]
    if not ack or ack[0][1] != 0:
        return None
    last = max(a for a, level in before if level == 0)
    bits_after = round((ack[0][0] - last) / bit)
    return ack[0][0] - last - bits_after * bit, bits_after


def main():
    demo, path = sys.argv[1], sys.argv[2]
    rate, _, samples = sigrok.read(path)
    bit = 96 * rate / CLOCK_HZ
    cycle = CLOCK_HZ / rate
    at, to = sigrok.edges(samples, CHANNEL)
    found = frames(list(at), list(to), bit)
    sent = [(i, 0, len(d), d)
            for i, d in (demo_can.FRAMES if demo == "can" else demo_can_node.FRAMES)]
    replies = [] if demo == "can" else demo_can_node.REPLIES
    print("%s at %g MS/s: a bit is %g samples, a sample %g cycles of 48 MHz; %d frames"
          % (path, rate / 1e6, bit, cycle, len(found)))
    problems, worst = [], {0: 0.0, 1: 0.0}
    expected = len(sent) + len(replies)
    if len(found) != expected:
        problems.append("%d frames on the bus, expected %d" % (len(found), expected))
    for (sof, edges), (ident, rtr, dlc, data) in zip(found, sent):
        bad, errors, stuff = check_sent(sof, edges, ident, rtr, dlc, data, bit, cycle)
        problems += bad
        if errors is None:
            continue
        for e, level in errors:
            worst[level] = max(worst[level], abs(e))
        falls = [e for e, level in errors if level == 0]
        rises = [e for e, level in errors if level == 1]
        print("sent id 0x%03x: %d edges where the line puts them, %d stuff bits and the CRC "
              "the chip added; off its bit, falling %+.1f..%+.1f, rising %+.1f..%+.1f samples"
              % (ident, len(errors), stuff, min(falls), max(falls),
                 min(rises or [0]), max(rises or [0])))
    for (sof, edges), (ident, rtr, dlc, data) in zip(found[len(sent):], replies):
        ack = check_ack(sof, edges, ident, rtr, dlc, data, bit)
        if ack is None:
            problems.append("reply id 0x%03x: no ACK" % ident)
            continue
        off, bits_after = ack
        print("reply id 0x%03x: the chip's ACK %d bits after its last resync edge, "
              "%+.1f samples (%+.0f cycles) off the bit" % (ident, bits_after, off, off * cycle))
        if abs(off) > bit / 8:
            problems.append("reply id 0x%03x: ACK %.1f samples off its bit" % (ident, off))
    print("worst edge off its bit: falling %.1f, rising %.1f samples (%.0f, %.0f cycles)"
          % (worst[0], worst[1], worst[0] * cycle, worst[1] * cycle))
    for problem in problems:
        print(problem)
    print("FAIL" if problems else "PASS")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
