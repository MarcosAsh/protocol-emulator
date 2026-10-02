# SPDX-License-Identifier: Apache-2.0
# Act 2 for every firmware engine 1 can stamp, on the host Pico (MicroPython): each runs
# on engine 0 with its watched output on wire 20, and every edge's stamp is held to the
# cycle the model gives it and the interval the kernel's rows allow along the model's
# path, from its frame's first edge. sweep_firmware.py says what runs, and why the rest
# do not. Needs protocol_emulator.py, pico_board.py, demo_self_timing.py and
# sweep_firmware.py.

import gc

import protocol_emulator as pe
import sweep_firmware as sf
from demo_self_timing import faults, host_drain

EXACT, WITHIN, OUT = 0, 1, 2


def config(changes):
    c = dict(sf.DEFAULTS)
    c.update(changes)
    return c


def write_program(host, words, dirty):
    """The selected engine's words from 0, halted, and zeros after them up to dirty, past
    which the memory is zero already. Returns how far it may now hold anything."""
    host.write(pe.PROGRAM_ADDR, [0])
    host.write(pe.PROGRAM, list(words) + [0] * (dirty - len(words)))
    return len(words)


def setup(host, firmware, dirty):
    """Engine 1 halted; engine 0 parked, its pins low as the model starts them, and
    loaded; then engine 1 started at the wire's level and engine 0 after it."""
    host.select(1)
    host.stop()
    host.flush()
    host.select(0)
    host.stop()
    host.flush()
    host.configure(config(firmware["config"]))
    host.write(pe.PROGRAM_ADDR, [0])
    host.write(pe.PROGRAM, firmware["park"])
    host.start()
    host.stop()
    dirty = write_program(host, firmware["words"], dirty)
    if firmware["preamble"]:
        host.push(firmware["preamble"])
    host.select(1)
    host.start()
    host.select(0)
    host.start()
    host.select(1)
    return dirty


def polls(cycles, pause):
    """How long to wait for edges cycles after a push: act 2's bound on the Pico, and with
    a pause of POLL cycles, that long and a few more."""
    return 100_000 if pause is None else cycles // sf.POLL + 8


def collect(drain, count, limit, pause):
    """The next count stamps, or what came in limit polls."""
    stamps = []
    for _ in range(limit):
        drain(stamps, ())
        if len(stamps) >= count:
            break
        if pause:
            pause()
    return stamps


def offsets(stamps):
    """Each stamp's cycles after the first, adding up 16-bit gaps."""
    out = [0] if stamps else []
    for k in range(1, len(stamps)):
        out.append(out[-1] + ((stamps[k] - stamps[k - 1]) & 0xFFFF))
    return out


def verdict(edge, got):
    predicted, lo, hi = (edge, edge, edge) if isinstance(edge, int) else edge
    if got == predicted:
        return EXACT
    if (lo is None or lo <= got) and (hi is None or got <= hi):
        return WITHIN
    return OUT


def sweep(host, firmware, drain, pause):
    """Exact, within and out counts over every edge, a missing or extra one out, and a
    line for each frame that is not exact. The setup's edges are dropped, as act 2 drops
    the line going idle."""
    counts = [0, 0, 0]
    notes = []
    s = firmware["setup"]
    got = collect(drain, s["edges"], polls(s["cycles"], pause), pause)
    if len(got) != s["edges"]:
        counts[OUT] += abs(len(got) - s["edges"])
        notes.append("setup: %d of %d edges" % (len(got), s["edges"]))
    for burst in firmware["bursts"]:
        # a collection mid-burst stalls the poll for milliseconds, and engine 1 overflows
        gc.collect()
        host.select(0)
        host.push(burst["words"])
        host.select(1)
        count = sum(len(frame) for frame in burst["frames"])
        stamps = collect(drain, count, polls(burst["cycles"], pause), pause)
        if len(stamps) != count:
            counts[OUT] += abs(len(stamps) - count)
            notes.append("%s: %d of %d edges" % (burst["words"], len(stamps), count))
        for frame in burst["frames"]:
            got, stamps = offsets(stamps[:len(frame)]), stamps[len(frame):]
            verdicts = [verdict(edge, g) for edge, g in zip(frame, got)]
            for v in verdicts:
                counts[v] += 1
            if any(verdicts):
                notes.append("predicted %s" % frame)
                notes.append("measured  %s" % got)
    extra = []
    drain(extra, ())
    if extra:
        counts[OUT] += len(extra)
        notes.append("%d edges after the last" % len(extra))
    return counts, notes


def run(transfer, pause=None, drain=None):
    """Every swept firmware in turn, a line each, and whether all passed. Faults hold until
    reset, so the sweep stops at the first."""
    host = pe.Host(transfer)
    found = faults(host)
    if any(found):
        raise RuntimeError("faults %s hold from an earlier run: reset the chip" % found)
    poll = host_drain(host) if drain is None else drain
    host.select(1)
    host.stop()
    host.flush()
    host.configure(config(sf.LOGGER["config"]))
    host.load(sf.LOGGER["words"])
    # nothing is known of engine 0's memory yet
    dirty = pe.PROGRAM_WORDS
    print("firmware           watch  edges  exact  within  out  faults")
    passed = 0
    for firmware in sf.SWEPT:
        dirty = setup(host, firmware, dirty)
        (exact, within, out), notes = sweep(host, firmware, poll, pause)
        found = faults(host)
        ok = out == 0 and not any(found)
        passed += ok
        edges = sum(len(f) for burst in firmware["bursts"] for f in burst["frames"])
        print("%-18s %-5s  %5d  %5d  %6d  %3d  %-6s  %s" % (
            firmware["name"], firmware["watch"], edges, exact, within, out,
            "%x %x" % tuple(found), "PASS" if ok else "FAIL"))
        for note in notes:
            print("    " + note)
        if any(found):
            print("faults hold until reset: the rest are not run")
            break
    print("\nnot swept:")
    for name, why in sf.NOT_SWEPT:
        print("%-18s %s" % (name, why))
    return passed == len(sf.SWEPT)


if __name__ == "__main__":
    import pico_board

    spi = pico_board.PicoSpi()
    print("PASS" if run(spi.transfer, drain=spi.drain) else "FAIL")
