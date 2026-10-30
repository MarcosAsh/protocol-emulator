# SPDX-License-Identifier: Apache-2.0
# A bench run kept in test/board/<run>/ as demo/ledger.py wrote it, with witness.json naming
# its bitstream, firmware, host scripts and bench. A check re-hashes it, decodes the capture
# again, holds the bytes to what was sent and the edges to datasheet windows, then fails
# each on its teeth: a bit flipped in the waveform and an edge moved.
# Usage: python3 demo/witness.py check test/board/*/
#        python3 demo/witness.py write LEDGER_RUN test/board/RUN [--bitstream FROM]

import argparse
import hashlib
import json
import math
import re
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path

import numpy as np
import sigrok
import sweep_rates
import traffic

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "python"))
import demo_ir_rc6  # noqa: E402
import demo_lfast  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
# copied from the ledger run, each listed in its SHA256SUMS
KEPT = ["{}.sr", "{}.log", "ledger.txt", "run.txt"]
# the analyser's crystal against the chip's, either way
PPM = 100e-6
# 24LC256, Table 1-2 param 4: SDA and SCL rise in up to 300 ns, which the analyser's
# threshold does not see, so it comes off every I2C interval's least
TR = 300e-9


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def span(n, rate):
    """Where an interval the analyser saw as n samples lies, in seconds: each end is
    somewhere in its sample."""
    return (n - 1) / rate * (1 - PPM), (n + 1) / rate * (1 + PPM)


def show(seconds, limit):
    if math.isinf(seconds):
        return "open"
    if limit < 10e-6:
        return "%.0f ns" % (seconds * 1e9)
    return "%.2f us" % (seconds * 1e6)


def bound(parameter, sheet, spans, at_least=None, at_most=None, slack=0.0):
    """A datasheet window over spans, (lo, hi) each: proved when every span is inside it,
    slack less at the bottom, failed when one is wholly outside, else unresolved."""
    limit = at_least if at_most is None else at_most
    if not spans:
        verdict = "absent"
    elif at_most is None:
        verdict = ("fail" if any(hi < at_least for _, hi in spans) else
                   "proved" if all(lo - slack >= at_least for lo, _ in spans) else "unresolved")
    else:
        verdict = ("fail" if any(lo > at_most for lo, _ in spans) else
                   "proved" if all(hi <= at_most for _, hi in spans) else "unresolved")
    return {
        "parameter": parameter,
        "limit": "%s %s" % (">=" if at_most is None else "<=", show(limit, limit)),
        "sheet": sheet,
        "spans": len(spans),
        "measured": "%s to %s" % (show(min(s[0] for s in spans), limit),
                                  show(max(s[1] for s in spans), limit)) if spans else "-",
        "verdict": verdict,
    }


def count(parameter, sheet, counts, at_least=None, at_most=None, unit="bits"):
    """bound() over whole counts, which the analyser sees exactly."""
    record = bound(parameter, sheet, [(c, c) for c in counts], at_least, at_most)
    limit = at_least if at_most is None else at_most
    record["limit"] = "%s %d %s" % (record["limit"][:2], limit, unit)
    if counts:
        record["measured"] = "%d to %d %s" % (min(counts), max(counts), unit)
    return record


def runs(samples, bit):
    """Each run of one level on a channel, (level, first sample, samples), less the two the
    capture cuts."""
    at, to = sigrok.edges(samples, bit)
    return [(int(to[i]), int(at[i]), int(at[i + 1] - at[i])) for i in range(len(at) - 1)]


def edges(samples, bit):
    at, to = sigrok.edges(samples, bit)
    return at.tolist(), to.tolist()


def after(sorted_at, sample):
    """The first of sorted_at past sample, or None."""
    i = int(np.searchsorted(sorted_at, sample, side="right"))
    return sorted_at[i] if i < len(sorted_at) else None


def before(sorted_at, sample):
    i = int(np.searchsorted(sorted_at, sample, side="left"))
    return sorted_at[i - 1] if i else None


def annotations(capture, decode, classes):
    """sigrok's lines of the decode's stack for classes, each (first, last sample, text)."""
    stack = decode.split(" -A ")[0].split()
    lines = decode_lines(capture, stack + ["-A", classes, "--protocol-decoder-samplenum"])
    return [(int(a), int(b), text) for a, b, text in
            (re.match(r"(\d+)-(\d+) (.*)", line).groups() for line in lines)]


def decode_text(capture, arguments):
    done = subprocess.run(["sigrok-cli", "-i", str(capture)] + arguments, capture_output=True)
    if done.returncode or done.stderr.strip():
        raise RuntimeError("sigrok-cli: %s" % done.stderr.decode().strip())
    return done.stdout


def decode_lines(capture, arguments):
    return decode_text(capture, arguments).decode(errors="replace").splitlines()


def changed(samples, bit, first, last, level=None):
    """The samples with the channel inverted, or held at level, from first up to last."""
    out = np.frombuffer(samples, np.uint8).copy()
    mask = np.uint8(1 << bit)
    if level is None:
        out[first:last] ^= mask
    else:
        out[first:last] = (out[first:last] & ~mask) | (mask if level else 0)
    return out.tobytes()


def moved(samples, bit, at, to):
    """The samples with the channel's edge at at moved to to."""
    level = (samples[at - 1] >> bit) & 1
    if to > at:
        return changed(samples, bit, at, to, level)
    return changed(samples, bit, to, at, level ^ 1)


# 24LC256 at 2.5 to 5.5 V, Table 1-2's 400 kHz column, and UM10204's modes; tr is the most
# rise, which comes off every least
EEPROM = "24LC256, Microchip DS20001203W, Table 1-2 %s"
UM10204 = "I2C %s-mode, NXP UM10204 Rev. 7.0 Table 11, p.44"
I2C_WINDOWS = {
    None: (TR, [("1/fSCL", "p.4, param 1", 2500e-9), ("THIGH", "p.4, param 2", 600e-9),
                ("TLOW", "p.4, param 3", 1300e-9), ("THD:STA", "p.4, param 6", 600e-9),
                ("TSU:STA", "p.4, param 7", 600e-9), ("TSU:DAT", "p.4, param 9", 100e-9),
                ("TSU:STO", "p.4, param 10", 600e-9), ("TBUF", "p.5, param 14", 1300e-9)]),
    "standard": (1000e-9, [("1/fSCL", 10e-6), ("THIGH", 4000e-9), ("TLOW", 4700e-9),
                           ("THD:STA", 4000e-9), ("TSU:STA", 4700e-9), ("TSU:DAT", 250e-9),
                           ("TSU:STO", 4000e-9), ("TBUF", 4700e-9)]),
    "fast": (300e-9, [("1/fSCL", 2500e-9), ("THIGH", 600e-9), ("TLOW", 1300e-9),
                      ("THD:STA", 600e-9), ("TSU:STA", 600e-9), ("TSU:DAT", 100e-9),
                      ("TSU:STO", 600e-9), ("TBUF", 1300e-9)]),
}


def i2c(sda, scl, mode=None):
    def timing(samples, rate, _capture, _decode, _log):
        s_at, s_to = edges(samples, sda)
        c_at, c_to = edges(samples, scl)
        scl_level = np.frombuffer(samples, np.uint8) >> scl & 1
        # SDA moving while SCL is high on both sides: a START falls, a STOP rises
        marks = [(a, t) for a, t in zip(s_at, s_to) if scl_level[a - 1] and scl_level[a]]
        starts = [a for a, t in marks if not t]
        stops = [a for a, t in marks if t]
        rises = [a for a, t in zip(c_at, c_to) if t]
        falls = [a for a, t in zip(c_at, c_to) if not t]
        n = {k: [] for k in ["THD:STA", "TSU:STA", "TSU:STO", "TBUF", "TLOW", "THIGH",
                             "1/fSCL", "TSU:DAT"]}
        for s in starts:
            if (f := after(falls, s)) is not None:
                n["THD:STA"].append(f - s)
            if (r := before(rises, s)) is not None:
                n["TSU:STA"].append(s - r)
            # from a STOP to the next START, not a repeated one
            p, q = before(stops, s), before(starts, s)
            if p is not None and (q is None or q < p):
                n["TBUF"].append(s - p)
        for p in stops:
            if (r := before(rises, p)) is not None:
                n["TSU:STO"].append(p - r)
        for f in falls:
            if (r := after(rises, f)) is not None:
                n["TLOW"].append(r - f)
                # the data's last move while SCL was low, to the rise that samples it
                moves = [a for a in s_at if f < a < r]
                if moves:
                    n["TSU:DAT"].append(r - moves[-1])
        for r in rises:
            f, r2 = after(falls, r), after(rises, r)
            stop = after(stops, r)
            if f is not None and (stop is None or stop > f):
                n["THIGH"].append(f - r)
            if r2 is not None and (stop is None or stop > r2):
                n["1/fSCL"].append(r2 - r)
        slack, windows = I2C_WINDOWS[mode]
        return [bound(w[0], EEPROM % w[1] if mode is None else UM10204 % mode.capitalize(),
                      [span(x, rate) for x in n[w[0]]], at_least=w[-1], slack=slack)
                for w in windows]

    def byte_tooth(samples, _rate, capture, decode):
        """Bit 1 of the page write's fifth byte inverted, SDA moving while SCL is low."""
        first, last, _ = next(a for a in annotations(capture, decode, "eeprom24xx=data-byte")
                              if "Data byte 7FC4:" in a[2])
        falls = [a for a, t in zip(*edges(samples, scl)) if not t and first <= a <= last]
        return (changed(samples, sda, falls[1] + 2, falls[2] + 2),
                "SDA inverted over bit 1 of the page write's byte at 0x7fc4")

    def edge_tooth(samples, _rate):
        """The tenth SCL pulse after the first START cut to six samples."""
        s_at, s_to = edges(samples, sda)
        scl_level = np.frombuffer(samples, np.uint8) >> scl & 1
        start = next(a for a, t in zip(s_at, s_to) if not t and scl_level[a - 1] and scl_level[a])
        c_at, c_to = edges(samples, scl)
        rise = [a for a, t in zip(c_at, c_to) if t and a > start][9]
        fall = after([a for a, t in zip(c_at, c_to) if not t], rise)
        return moved(samples, scl, fall, rise + 6), "SCL's tenth pulse cut to 6 samples", "THIGH"

    return timing, byte_tooth, edge_tooth


ONE_WIRE = "DS18B20, Maxim REV 042208 p.20"


def one_wire(dq):
    def lows(samples):
        return [(first, n) for level, first, n in runs(samples, dq) if not level]

    def timing(samples, rate, capture, decode, _log):
        found = lows(samples)
        us = rate * 1e-6
        resets = [i for i, (_, n) in enumerate(found) if n > 300 * us]
        n = {k: [] for k in ["tRSTL", "tRSTH", "tPDHIGH", "tPDLOW", "tLOW0", "tLOW1", "tREC",
                             "tSLOT + tREC"]}
        presence = set()
        for i in resets:
            fall, width = found[i]
            n["tRSTL"].append(width)
            if i + 2 < len(found):
                (p, pn), (nxt, _) = found[i + 1], found[i + 2]
                presence.add(i + 1)
                n["tPDHIGH"].append(p - fall - width)
                n["tPDLOW"].append(pn)
                n["tRSTH"].append(nxt - fall - width)
        slots = [i for i in range(len(found)) if i not in presence and i not in resets]
        # bytes the master writes: ROM commands, and the function command after a Skip ROM
        written, skip = [], False
        for first, last, text in annotations(capture, decode, "onewire_network"):
            command = re.search(r"(ROM command|Data): 0x(\w\w)", text)
            if command and (command.group(1) == "ROM command" or skip):
                written.append((first, last, int(command.group(2), 16)))
            skip = bool(command) and command.group(0) == "ROM command: 0xcc"
        slots_a_byte = []
        for first, last, byte in written:
            mine = [found[i][1] for i in slots if first <= found[i][0] <= last]
            slots_a_byte.append(len(mine))
            for b, w in enumerate(mine):
                n["tLOW1" if byte >> b & 1 else "tLOW0"].append(w)
        for i, j in zip(slots, slots[1:]):
            if j == i + 1:
                n["tSLOT + tREC"].append(found[j][0] - found[i][0])
                n["tREC"].append(found[j][0] - found[i][0] - found[i][1])
        windows = [("tRSTL", 480e-6, None), ("tRSTH", 480e-6, None), ("tPDHIGH", 15e-6, 60e-6),
                   ("tPDLOW", 60e-6, 240e-6), ("tLOW0", 60e-6, 120e-6), ("tLOW1", 1e-6, 15e-6),
                   ("tREC", 1e-6, None), ("tSLOT + tREC", 61e-6, None)]
        records = []
        for p, least, most in windows:
            spans = [span(w, rate) for w in n[p]]
            records.append(bound(p, ONE_WIRE, spans, at_least=least))
            if most:
                records.append(bound(p, ONE_WIRE, spans, at_most=most))
        return records + [count("slots a written byte", ONE_WIRE, slots_a_byte, at_least=8,
                                unit="slots"),
                          count("slots a written byte", ONE_WIRE, slots_a_byte, at_most=8,
                                unit="slots")]

    def byte_tooth(samples, rate, _capture, _decode):
        """READ ROM's bit 0, a 1, held low 66 us: a 0."""
        found = lows(samples)
        reset = next(i for i, (_, n) in enumerate(found) if n > 300e-6 * rate)
        fall, _ = found[reset + 2]
        return (changed(samples, dq, fall, fall + round(66e-6 * rate), 0),
                "READ ROM's first slot held low 66 us")

    def edge_tooth(samples, rate):
        """The first reset let go after 470 us."""
        fall, width = next((f, n) for f, n in lows(samples) if n > 300e-6 * rate)
        return (moved(samples, dq, fall + width, fall + round(470e-6 * rate)),
                "the first reset cut to 470 us", "tRSTL")

    return timing, byte_tooth, edge_tooth


SK6812 = "SK6812, OSK-SPC-SK6812-012 Rev. B/1 p.7"


def ws2812(din):
    def bits(samples, rate):
        """Each high, whether it is a 1, and the low after it, None for a reset."""
        found = runs(samples, din)
        out = []
        for i, (level, first, n) in enumerate(found):
            if level:
                low = found[i + 1][2] if i + 1 < len(found) else None
                out.append((first, n, n > 525e-9 * rate, low if low and low < 50e-6 * rate
                            else None))
        return out

    def timing(samples, rate, _capture, _decode, _log):
        n = {k: [] for k in ["T0H", "T1H", "T0L", "T1L", "T"]}
        for _, high, one, low in bits(samples, rate):
            n["T1H" if one else "T0H"].append(span(high, rate))
            if low is not None:
                n["T1L" if one else "T0L"].append(span(low, rate))
                n["T"].append(span(high + low, rate))
        found = runs(samples, din)
        resets = [span(w, rate) for level, _, w in found if not level and w >= 50e-6 * rate]
        # the lows the capture cuts, before the first frame and after the last
        at, _ = sigrok.edges(samples, din)
        if len(at) and not samples[0] >> din & 1:
            resets.append((span(int(at[0]), rate)[0], math.inf))
        if len(at) and not samples[-1] >> din & 1:
            resets.append((span(len(samples) - int(at[-1]), rate)[0], math.inf))
        return [bound("T0H", SK6812, n["T0H"], at_least=250e-9),
                bound("T0H", SK6812, n["T0H"], at_most=400e-9),
                bound("T1H", SK6812, n["T1H"], at_least=650e-9),
                bound("T1H", SK6812, n["T1H"], at_most=1000e-9),
                bound("T0L", SK6812, n["T0L"], at_least=800e-9),
                bound("T1L", SK6812, n["T1L"], at_least=200e-9),
                bound("T", SK6812 + ", note 2", n["T"], at_least=1200e-9),
                bound("reset", SK6812, resets, at_least=200e-6)]

    def byte_tooth(samples, rate, _capture, _decode):
        """The first bit, a 0, held high as long as a 1."""
        first, _, _, _ = bits(samples, rate)[0]
        return (changed(samples, din, first, first + round(700e-9 * rate), 1),
                "the first bit held high 700 ns")

    def edge_tooth(samples, rate):
        """The first 1's high 400 ns longer."""
        first, high, _, _ = next(b for b in bits(samples, rate) if b[2])
        return (moved(samples, din, first + high, first + high + round(400e-9 * rate)),
                "the first 1 held high 400 ns longer", "T1H")

    return timing, byte_tooth, edge_tooth


CAN_BIT = 2e-6
# the most a CAN node's clock may be off: Hartwich and Bassemir, The Configuration of the
# CAN Bit Timing, Bosch, 6th iCC 1999
CAN_TOLERANCE = 0.0158


def can(rx):
    def frames(samples, rate):
        """Each frame's edges, its first the start of frame after eleven recessive bits."""
        at, to = edges(samples, rx)
        out, last = [], 0
        for a, t in zip(at, to):
            if not t and (not out or a - last > 11 * CAN_BIT * rate):
                out.append([])
            if out:
                out[-1].append(a)
            last = a
        return out

    def timing(samples, rate, _capture, _decode, _log):
        bit = CAN_BIT * rate
        frame_bits, run_bits, stuffed, runs_, idle = [], [], [], [], []
        previous = None
        for frame in frames(samples, rate):
            # the last two edges are the receiver's ACK, the rest the transmitter's
            sent = frame[:-2]
            k = round((sent[-1] - sent[0]) / bit)
            lo, hi = span(sent[-1] - sent[0], rate)
            frame_bits.append((lo / k, hi / k))
            for a, b in zip(sent, sent[1:]):
                k = round((b - a) / bit)
                lo, hi = span(b - a, rate)
                run_bits.append((lo / k, hi / k))
                stuffed.append(k)
            runs_ += [span(b - a, rate) for a, b in zip(frame, frame[1:])]
            # recessive before the start of frame, from the capture's start for the first
            gap = frame[0] - (previous if previous is not None else 0)
            idle.append(span(gap, rate) if previous is not None else (span(gap, rate)[0], math.inf))
            previous = frame[-1]
        fast, slow = CAN_BIT * (1 - CAN_TOLERANCE), CAN_BIT * (1 + CAN_TOLERANCE)
        tolerance = "500 kbit/s within 1.58%, Hartwich and Bassemir, Bosch, 6th iCC 1999"
        return [bound("bit time, a frame", tolerance, frame_bits, at_least=fast),
                bound("bit time, a frame", tolerance, frame_bits, at_most=slow),
                bound("bit time, a run", tolerance, run_bits, at_least=fast),
                bound("bit time, a run", tolerance, run_bits, at_most=slow),
                bound("bit", "SN65HVD230, TI SLOS346O p.1, up to 1 Mbps", runs_,
                      at_least=1000e-9),
                count("equal bits", "Bosch CAN 2.0 Part A, a stuff bit after five", stuffed,
                      at_most=5),
                bound("idle to SOF", "CAN 2.0A, Bosch CAN 2.0, BCANPSV2.0 Rev. 3 s.2.15 p.2-6, "
                      "eleven recessive bits", idle, at_least=11 * CAN_BIT)]

    def byte_tooth(samples, rate, capture, decode):
        """The first data byte's fourth bit inverted. sigrok's annotation starts at the
        byte's first bit."""
        first, _, _ = next(a for a in annotations(capture, decode, "can=data")
                           if "Data byte 0:" in a[2])
        bit = CAN_BIT * rate
        return (changed(samples, rx, round(first + 3 * bit), round(first + 4 * bit)),
                "CAN R inverted over the first data byte's fourth bit")

    def edge_tooth(samples, rate):
        """An edge after a one-bit run of the first frame, a quarter bit late."""
        frame = frames(samples, rate)[0]
        bit = round(CAN_BIT * rate)
        at = next(b for a, b in zip(frame, frame[1:-2]) if b - a == bit)
        return (moved(samples, rx, at, at + bit // 4),
                "an edge of the first frame a quarter bit late", "bit time, a run")

    return timing, byte_tooth, edge_tooth


def swd(swclk, swdio):
    rp2040 = "RP2040, RP2040 datasheet, 2025-02-20 s.2.3.4 p.61"

    def resets(samples):
        """SWDIO's high runs over more SWCLK rises than a read nobody answers, each with
        its first sample and the rises: the park bit, turnaround, ACK, 32 bits, parity and
        turnaround are 39."""
        rises = [a for a, t in zip(*edges(samples, swclk)) if t]
        out = []
        for level, first, n in runs(samples, swdio):
            clocks = [r for r in rises if first <= r < first + n]
            if level and len(clocks) > 39:
                out.append((first, clocks))
        return out

    def timing(samples, rate, _capture, _decode, _log):
        found = runs(samples, swclk)
        half = 1 / 48e6
        return [bound("SWCLK high", rp2040, [span(n, rate) for level, _, n in found if level],
                      at_least=half),
                bound("SWCLK low", rp2040, [span(n, rate) for level, _, n in found if not level],
                      at_least=half),
                count("line reset", "ADIv5.2, Arm IHI 0031, B4.3.3, SWDIO high",
                      [len(clocks) for _, clocks in resets(samples)], at_least=50,
                      unit="cycles")]

    def byte_tooth(samples, _rate, capture, decode):
        """SWDIO inverted over a bit of AP 0's IDR, read once."""
        first, last, _ = next(a for a in annotations(capture, decode, "swd")
                              if a[2] == "swd-1: 0x04770031")
        falls = [a for a, t in zip(*edges(samples, swclk)) if not t and first <= a <= last]
        return (changed(samples, swdio, falls[3] + 2, falls[4] + 2),
                "SWDIO inverted over a bit of AP 0's IDR")

    def edge_tooth(samples, _rate):
        """The first line reset's SWDIO rise moved 20 SWCLK rises later."""
        first, clocks = resets(samples)[0]
        return (moved(samples, swdio, first, clocks[20] - 3),
                "the first line reset's rise 20 cycles late", "line reset")

    return timing, byte_tooth, edge_tooth


def uart(line, baud, clock_hz):
    sheet = "UART at %d baud, Maxim AN2141 p.4, 2%%" % baud

    def frames(samples, rate):
        """Each frame's edges, from its start bit's fall, in samples."""
        bit = rate / baud
        at, to = edges(samples, line)
        out = []
        for a, t in zip(at, to):
            if out and a - out[-1][0] < 9.5 * bit:
                out[-1].append(a)
            elif not t:
                out.append([a])
        return out

    def timing(samples, rate, _capture, _decode, log):
        bit = rate / baud
        spans, misses, wrong = [], [], 0
        # the chip's own edge log, cycles after each start bit
        logged = [[int(c) for c in row.split()[:-1]]
                  for row in re.findall(r"^ {10,}(\d[\d ]*ok)$", log, re.M)]
        found = frames(samples, rate)
        for frame in found:
            for a in frame[1:]:
                k = round((a - frame[0]) / bit)
                lo, hi = span(a - frame[0], rate)
                spans.append((lo / k, hi / k))
        for frame, cycles in zip(found, logged):
            if len(frame) != len(cycles):
                wrong += 1
                continue
            for a, c in zip(frame, cycles):
                lo, hi = span(a - frame[0], rate)
                misses.append(max(0.0, lo - c / clock_hz, c / clock_hz - hi))
        records = [bound("bit", sheet, spans, at_least=(1 - 0.02) / baud),
                   bound("bit", sheet, spans, at_most=(1 + 0.02) / baud)]
        records.append({
            "parameter": "edge after its start bit",
            "limit": "where the chip's edge log puts it",
            "sheet": "Pico A's log, the chip's cycles at %g MHz" % (clock_hz / 1e6),
            "spans": len(misses),
            "measured": "%d frames of %d logged, misses %s" % (
                len(found), len(logged), show(max(misses, default=0.0), 1e-6)),
            "verdict": "proved" if misses and not any(misses) and not wrong
            and len(found) == len(logged) else "fail",
        })
        return records

    def byte_tooth(samples, rate, _capture, _decode):
        """Bit 0 of the first byte inverted at its middle."""
        start, bit = frames(samples, rate)[0][0], rate / baud
        return (changed(samples, line, round(start + 1.25 * bit), round(start + 1.75 * bit)),
                "half of the first byte's bit 0 inverted")

    def edge_tooth(samples, rate):
        """The first frame's second edge 12 samples late."""
        at = frames(samples, rate)[0][1]
        return moved(samples, line, at, at + 12), "the first frame's second edge 12 samples late", "bit"

    return timing, byte_tooth, edge_tooth


W25Q64JV = "W25Q64JV, Winbond Rev. M %s"


def spi(sck, mosi, miso, cs):
    """Modes 0 and 3, the flash's: it samples on SCK's rise."""

    def frames(samples):
        """Each CS-low frame: its fall, its rise, SCK's rises and falls inside, and the
        bytes MOSI sends at the rises."""
        cs_at, cs_to = edges(samples, cs)
        c_at, c_to = edges(samples, sck)
        data = np.frombuffer(samples, np.uint8) >> mosi & 1
        out = []
        for fall, rise in zip([a for a, t in zip(cs_at, cs_to) if not t],
                              [a for a, t in zip(cs_at, cs_to) if t and a > cs_at[0]]):
            rises = [a for a, t in zip(c_at, c_to) if t and fall < a < rise]
            falls = [a for a, t in zip(c_at, c_to) if not t and fall < a < rise]
            bits = [int(data[a]) for a in rises]
            sent = [int("".join(map(str, bits[k:k + 8])), 2) for k in range(0, len(bits) - 7, 8)]
            out.append((fall, rise, rises, falls, sent))
        return out

    def timing(samples, rate, _capture, _decode, _log):
        found = frames(samples)
        n = {k: [] for k in ["tCLH", "tCLL", "tSLCH", "tCHSH", "tSHSL2", "tRES1"]}
        for fall, rise, rises, falls, sent in found:
            if rises:
                n["tSLCH"].append(rises[0] - fall)
                n["tCHSH"].append(rise - rises[-1])
            n["tCLH"] += [after(falls, r) - r for r in rises if after(falls, r) is not None]
            n["tCLL"] += [after(rises, f) - f for f in falls if after(rises, f) is not None]
        for (_, rise, _, _, sent), (fall, _, _, _, _) in zip(found, found[1:]):
            n["tSHSL2"].append(fall - rise)
            # release from power-down
            if sent == [0xAB]:
                n["tRES1"].append(fall - rise)
        windows = [("tCLH", "p.64", 9e-9), ("tCLL", "p.64", 9e-9), ("tSLCH", "p.64", 3e-9),
                   ("tCHSH", "p.64", 3e-9), ("tSHSL2", "p.64", 50e-9), ("tRES1", "p.65", 3e-6)]
        return [bound(p, W25Q64JV % at, [span(w, rate) for w in n[p]], at_least=limit)
                for p, at, limit in windows]

    def jedec(samples):
        return next(f for f in frames(samples) if f[4][:1] == [0x9F])

    def byte_tooth(samples, _rate, _capture, _decode):
        """MISO inverted over the first bit of the flash's manufacturer ID."""
        _, _, rises, falls, _ = jedec(samples)
        return (changed(samples, miso, before(falls, rises[8]) + 1, after(falls, rises[8]) + 1),
                "MISO inverted over the first bit of the JEDEC ID's manufacturer byte")

    def edge_tooth(samples, rate):
        """The JEDEC frame's CS fall 2 us after the ABh frame's rise."""
        found = frames(samples)
        at = next(i for i, f in enumerate(found) if f[4][:1] == [0x9F])
        return (moved(samples, cs, found[at][0], found[at - 1][1] + round(2e-6 * rate)),
                "the JEDEC frame's CS fall 2 us after ABh", "tRES1")

    return timing, byte_tooth, edge_tooth


# NEC in units of 562.5 us, as test/nec.ml holds it (SB-Projects' page), each mark and space
# within 5% as Nec.decode takes it, the period at least 5% under its 192
NEC = "NEC, test/nec.ml's frames and Nec.decode's 5%"
NEC_UNIT = 562.5e-6


def nec(line):
    def marks(samples):
        """Each mark, the line low, as (first sample, samples, the space after it)."""
        found = runs(samples, line)
        return [(first, n, found[i + 1][2] if i + 1 < len(found) else None)
                for i, (level, first, n) in enumerate(found) if not level]

    def messages(samples, rate):
        """Each leader's mark, and the marks after it up to the next leader."""
        out = []
        for m in marks(samples):
            if m[1] > 8 * NEC_UNIT * rate:
                out.append([m])
            elif out:
                out[-1].append(m)
        return out

    def timing(samples, rate, _capture, _decode, _log):
        n = {k: [] for k in ["leader mark", "leader space", "repeat space", "bit mark",
                             "zero space", "one space", "final mark", "period"]}
        found = messages(samples, rate)
        for message, after in zip(found, found[1:] + [None]):
            (start, mark, space), rest = message[0], message[1:]
            n["leader mark"].append(mark)
            if space is not None and space < 6 * NEC_UNIT * rate:
                n["repeat space"].append(space)
            elif space is not None:
                n["leader space"].append(space)
                for _, bit, gap in rest[:32]:
                    n["bit mark"].append(bit)
                    if gap is not None:
                        n["one space" if gap > 2 * NEC_UNIT * rate else "zero space"].append(gap)
                rest = rest[32:]
            n["final mark"] += [m for _, m, _ in rest[:1]]
            if after:
                n["period"].append(after[0][0] - start)
        units = {"leader mark": 16, "leader space": 8, "repeat space": 4, "bit mark": 1,
                 "zero space": 1, "one space": 3, "final mark": 1}
        records = []
        for p, k in units.items():
            spans = [span(w, rate) for w in n[p]]
            records.append(bound(p, NEC, spans, at_least=0.95 * k * NEC_UNIT))
            records.append(bound(p, NEC, spans, at_most=1.05 * k * NEC_UNIT))
        return records + [bound("period", NEC, [span(w, rate) for w in n["period"]],
                                at_least=0.95 * 192 * NEC_UNIT)]

    def byte_tooth(samples, rate, _capture, _decode):
        """The first command's bits 3 and 4, a one then a zero, swapped in the same six
        units: the command reads 0x10."""
        bits = messages(samples, rate)[0][1:]
        start, end, unit = bits[19][0], bits[21][0], round(NEC_UNIT * rate)
        out = changed(samples, line, start, start + unit, 0)
        out = changed(out, line, start + unit, start + 2 * unit, 1)
        out = changed(out, line, start + 2 * unit, start + 3 * unit, 0)
        return (changed(out, line, start + 3 * unit, end, 1),
                "the first command's bits 3 and 4 swapped")

    def edge_tooth(samples, rate):
        """The first leader's mark a unit short."""
        start, mark, _ = messages(samples, rate)[0][0]
        return (moved(samples, line, start + mark, start + mark - round(NEC_UNIT * rate)),
                "the first leader mark a unit short", "leader mark")

    return timing, byte_tooth, edge_tooth


# The protocols drawn at random (docs/flexibility.md). The windows are their specs' limits
# where the spec has any, else the nominal times the library's firmware and decoder hold to,
# each named for where it comes from.
AN452 = "National AN-452 (1992), %s"


def microwire(sk, di, cs):
    """Each window the strictest the library's AN-452 parts give."""

    def frames(samples):
        """Each CS high with SK rising inside: its rise, its fall, SK's rises and falls."""
        cs_at, cs_to = edges(samples, cs)
        k_at, k_to = edges(samples, sk)
        rises = [a for a, t in zip(k_at, k_to) if t]
        falls = [a for a, t in zip(k_at, k_to) if not t]
        out = []
        for up, down in zip([a for a, t in zip(cs_at, cs_to) if t],
                            [a for a, t in zip(cs_at, cs_to) if not t and a > cs_at[0]]):
            inside = [r for r in rises if up < r < down]
            out.append((up, down, inside, [f for f in falls if up < f < down]))
        return out

    def timing(samples, rate, _capture, _decode, _log):
        d_at = edges(samples, di)[0]
        n = {k: [] for k in ["SK period", "SK high", "DI setup", "DI hold", "CS setup",
                             "CS hold", "CS low after an erase/write"]}
        found = frames(samples)
        for up, down, rises, falls in found:
            if not rises:
                continue
            n["CS setup"].append(rises[0] - up)
            n["CS hold"].append(down - max(rises[-1], falls[-1] if falls else 0))
            n["SK period"] += [b - a for a, b in zip(rises, rises[1:])]
            n["SK high"] += [after(falls, r) - r for r in rises if after(falls, r)]
            for last, r, nxt in zip([up] + rises, rises, rises[1:] + [down]):
                moves = [a for a in d_at if last < a <= r]
                if moves:
                    n["DI setup"].append(r - moves[-1])
                moves = [a for a in d_at if r < a < nxt]
                if moves:
                    n["DI hold"].append(moves[0] - r)
        # an erase/write's CS low ends in a status window, a CS high with no SK in it
        for (_, down, rises, _), (up, _, later, _) in zip(found, found[1:]):
            if rises and not later:
                n["CS low after an erase/write"].append(up - down)
        windows = [("SK period", "COP430, Table I p.5", 5000e-9, None),
                   ("SK period", "COP420, p.6 note 1", None, 10e-6),
                   ("SK high", "NM93C06A, p.6 note 1", 1000e-9, None),
                   ("DI setup", "COP472-3, Table I p.5", 1000e-9, None),
                   ("DI hold", "DS8908, Table I p.5", 800e-9, None),
                   ("CS setup", "COP472-3, Table I p.5", 1000e-9, None),
                   ("CS hold", "COP472-3, Table I p.5", 1000e-9, None),
                   ("CS low after an erase/write", "COP494 TWE, p.10", 20e-3, None),
                   ("CS low after an erase/write", "NM93C06A, p.6 note 2", None, 30e-3)]
        return [bound(p, AN452 % sheet, [span(x, rate) for x in n[p]], at_least=least,
                      at_most=most) for p, sheet, least, most in windows]

    def byte_tooth(samples, _rate, _capture, _decode):
        """DI inverted over EWEN's second bit, its first opcode bit."""
        _, _, rises, falls = frames(samples)[0]
        return (changed(samples, di, before(falls, rises[1]), after(falls, rises[1])),
                "DI inverted over EWEN's first opcode bit")

    def edge_tooth(samples, rate):
        """EWEN's CS rise half a microsecond before SK's first rise."""
        up, _, rises, _ = frames(samples)[0]
        return (moved(samples, cs, up, rises[0] - round(0.5e-6 * rate)),
                "EWEN's CS rise 0.5 us before SK's first rise", "CS setup")

    return timing, byte_tooth, edge_tooth


XY2 = "Newson rhothor X7 XY2-100 datasheet rev. 0703, p.2"


def xy2_100(sendck, data):
    """DATA moves at SENDCK's rise and is read at its fall."""

    def clock(samples):
        c_at, c_to = edges(samples, sendck)
        return [a for a, t in zip(c_at, c_to) if t], [a for a, t in zip(c_at, c_to) if not t]

    def timing(samples, rate, _capture, _decode, _log):
        rises, falls = clock(samples)
        d_at = edges(samples, data)[0]
        n = {"tDS": [], "tDH": []}
        for last, f, nxt in zip(falls, falls[1:], falls[2:]):
            # DATA's last move up to this fall since the one before, and its next after it
            i = int(np.searchsorted(d_at, f, side="right"))
            if i and d_at[i - 1] > last:
                n["tDS"].append(f - int(d_at[i - 1]))
            if i < len(d_at) and d_at[i] < nxt:
                n["tDH"].append(int(d_at[i]) - f)
        return [bound("tDS", XY2, [span(x, rate) for x in n["tDS"]], at_least=50e-9),
                bound("tDH", XY2, [span(x, rate) for x in n["tDH"]], at_least=100e-9)]

    def byte_tooth(samples, _rate, _capture, _decode):
        """DATA inverted over the first word's D15, its fourth bit: the parity no longer
        holds."""
        rises, _ = clock(samples)
        return changed(samples, data, rises[3], rises[4]), "DATA inverted over the first D15"

    def edge_tooth(samples, _rate):
        """DATA's first move after the first word's tenth fall put on the next fall."""
        rises, falls = clock(samples)
        d_at = edges(samples, data)[0]
        at = int(d_at[np.searchsorted(d_at, falls[10], side="right")])
        return (moved(samples, data, at, after(falls, at)),
                "a DATA move put on the SENDCK fall after it", "tDS")

    return timing, byte_tooth, edge_tooth


CALIPER = "ShumaTech, Chinese Scales, page 1, %s"


def caliper(clk, data):
    """The page's nominal clock and pauses, which the library reads as least times. A pause
    is a clock high over four half periods."""
    half = 270 / 48e6

    def clock(samples, rate):
        found = [(level, first, n) for level, first, n in runs(samples, clk)]
        pauses = [r for r in found if r[0] and r[2] > 4 * half * rate]
        return found, pauses

    def timing(samples, rate, _capture, _decode, _log):
        found, pauses = clock(samples, rate)
        firsts = {p[1] for p in pauses}
        # the first pause runs from the firmware's start, and a frame's last into the next
        # frame's first: first, between, last and first, between, ...
        n = {"clock high": [w for level, f, w in found if level and f not in firsts],
             "clock low": [w for level, _, w in found if not level],
             "first pause": [p[2] for p in pauses[0::2]],
             "pause between the words": [p[2] for p in pauses[1::2]],
             "last pause": [p[2] for p in pauses[2::2]]}
        windows = [("clock high", "lines 52-54, 90 kHz", 5555.5e-9),
                   ("clock low", "lines 52-54, 90 kHz", 5555.5e-9),
                   ("first pause", "lines 55-57", 55e-6),
                   ("pause between the words", "lines 58-60", 110e-6),
                   ("last pause", "lines 61-63", 55e-6)]
        return [bound(p, CALIPER % sheet, [span(x, rate) for x in n[p]], at_least=least)
                for p, sheet, least in windows]

    def byte_tooth(samples, rate, _capture, _decode):
        """DATA inverted from the first fall to just past the first rise, which sigrok
        samples it at: the first position's bit 0."""
        found, pauses = clock(samples, rate)
        fall = pauses[0][1] + pauses[0][2]
        rise = next(f for level, f, _ in found if level and f > fall)
        return changed(samples, data, fall, rise + 2), "DATA inverted over the first bit"

    def edge_tooth(samples, rate):
        """The first clock low a microsecond short."""
        found, pauses = clock(samples, rate)
        fall = pauses[0][1] + pauses[0][2]
        rise = next(f for level, f, _ in found if level and f > fall)
        return (moved(samples, clk, rise, rise - round(1e-6 * rate)),
                "the first clock low 1 us short", "clock low")

    return timing, byte_tooth, edge_tooth


def nominal(levels):
    """levels, one a bit or a unit, as runs of (level, count)."""
    out = []
    for level in levels:
        if out and out[-1][0] == level:
            out[-1][1] += 1
        else:
            out.append([level, 1])
    return out


def first_rise(found, idle):
    """The index in runs() of the first high after more than idle samples low, or after
    the start of the capture."""
    return next((k for k, (level, _, n) in enumerate(found)
                 if level and (k == 0 or found[k - 1][2] > idle)), len(found))


def framed(samples, line, idle, frames):
    """The line's runs from the first rise after more than idle samples low, paired with
    each frame's in turn, as (expected level, count, samples), a low run between frames
    skipped; and each such low as (samples, the frame's trailing low units in it). A frame
    whose runs disagree in level or number ends it, as its bytes will show."""
    found = runs(samples, line)
    i = first_rise(found, idle)
    paired, gaps = [], []
    for levels in frames:
        trailing = len(levels) - len("".join(map(str, levels)).rstrip("0"))
        expected = nominal(levels[:len(levels) - trailing])
        got = found[i:i + len(expected)]
        if [g[0] for g in got] != [e[0] for e in expected]:
            break
        paired.append([(e[0], e[1], g[2]) for e, g in zip(expected, got)])
        i += len(expected)
        if i < len(found) - 1:
            gaps.append((found[i][2], trailing))
        i += 1
    return paired, gaps


LFAST_BIT = 10 / 48e6
LFAST = ("10 cycles at 48 MHz, the firmware's bit, to half a bit: past it sigrok's lfast "
         "counts another (NXP AN5134 gives no least or most for it)")


def lfast_bits(byte):
    """A frame on the wire, MSB first: sync 0xA84B, header 0x09, the byte, the stop bit."""
    return [(w >> (n - 1 - i)) & 1 for w, n in ((0xA84B, 16), (0x09, 8), (byte, 8), (1, 1))
            for i in range(n)]


def lfast(line, words):
    def frames(samples, rate):
        return framed(samples, line, 40 * LFAST_BIT * rate, [lfast_bits(w) for w in words])[0]

    def timing(samples, rate, _capture, _decode, _log):
        n = {}
        for frame in frames(samples, rate):
            for _, k, w in frame:
                n.setdefault(k, []).append(w)
        return ([bound("%d-bit level" % k, LFAST, [span(w, rate) for w in n.get(k, [])],
                       at_least=(k - 0.5) * LFAST_BIT) for k in sorted(n)]
                + [bound("%d-bit level" % k, LFAST, [span(w, rate) for w in n.get(k, [])],
                         at_most=(k + 0.5) * LFAST_BIT) for k in sorted(n)]
                + [bound("a level", "NXP AN5134 Rev. 0, p.3: rates up to 320 Mb/s",
                         [span(w, rate) for v in n.values() for w in v], at_least=3.125e-9)])

    def start(samples, rate):
        found = runs(samples, line)
        return found[first_rise(found, 40 * LFAST_BIT * rate)][1]

    def byte_tooth(samples, rate, _capture, _decode):
        """The first payload's first bit inverted."""
        at = start(samples, rate) + round(24 * LFAST_BIT * rate)
        return (changed(samples, line, at, at + round(LFAST_BIT * rate)),
                "the first payload's first bit inverted")

    def edge_tooth(samples, rate):
        """The first frame's first bit 0.8 of a bit long."""
        at = start(samples, rate)
        end = at + next(n for level, f, n in runs(samples, line) if f == at)
        return (moved(samples, line, end, end + round(0.8 * LFAST_BIT * rate)),
                "the first sync bit 1.8 bits long", "1-bit level")

    return timing, byte_tooth, edge_tooth


RC6_UNIT = 444e-6
RC6 = ("SB-Projects' RC-6 page, 444 us a unit, to Ir_rc6.decode's 5% (the page gives no "
       "tolerance)")


def rc6_units(toggle, address, command):
    """A mode 0 frame's levels a unit each, high a mark: the leader, the start bit, mode
    000, the trailer bit of two units a half, then address and command MSB first."""
    def bit(b, width=1):
        return [1] * width + [0] * width if b else [0] * width + [1] * width

    out = [1] * 6 + [0] * 2 + bit(1) + bit(0) + bit(0) + bit(0) + bit(toggle, 2)
    for i in range(16):
        out += bit(((address << 8 | command) >> (15 - i)) & 1)
    return out


def ir_rc6(line, frames_sent):
    def frames(samples, rate):
        return framed(samples, line, 8 * RC6_UNIT * rate,
                      [rc6_units(*f) for f in frames_sent])

    def timing(samples, rate, _capture, _decode, _log):
        n = {}
        found, gaps = frames(samples, rate)
        for frame in found:
            for level, k, w in frame:
                n.setdefault("%s %dt" % ("mark" if level else "space", k), []).append(w)
        # the low to the next frame, less the units of the last bit's space in it
        free = [w - round(k * RC6_UNIT * rate) for w, k in gaps]
        records = []
        for p in sorted(n, key=lambda p: (p[:4], int(p.split()[1][:-1]))):
            k = int(p.split()[1][:-1])
            spans = [span(w, rate) for w in n[p]]
            records.append(bound(p, RC6, spans, at_least=0.95 * k * RC6_UNIT))
            records.append(bound(p, RC6, spans, at_most=1.05 * k * RC6_UNIT))
        return records + [bound("signal free time", RC6, [span(w, rate) for w in free],
                                at_least=0.95 * 6 * RC6_UNIT)]

    def byte_tooth(samples, rate, _capture, _decode):
        """The first frame's first address bit, its halves swapped: 20 units in, after the
        leader, the start bit, the mode and the trailer bit."""
        start = next(f for level, f, n in runs(samples, line)
                     if level and n > 5 * RC6_UNIT * rate)
        unit = round(RC6_UNIT * rate)
        return (changed(samples, line, start + 20 * unit, start + 22 * unit),
                "the first address bit's halves swapped")

    def edge_tooth(samples, rate):
        """The first leader mark a unit short."""
        start, n = next((f, n) for level, f, n in runs(samples, line)
                        if level and n > 5 * RC6_UNIT * rate)
        return (moved(samples, line, start + n, start + n - round(RC6_UNIT * rate)),
                "the first leader mark a unit short", "mark 6t")

    return timing, byte_tooth, edge_tooth


TDM_BIT = 6 / 48e6
AN301 = "Cirrus Logic AN301 Rev. 1, %s"


def tdm_audio(sclk, fsync, sdata):
    """AN301 gives no times, only the frame in SCLK periods: FSYNC high for one at least,
    and eight 32-bit blocks a frame as the firmware and sigrok's options take it."""

    def clock(samples):
        c_at, c_to = edges(samples, sclk)
        f_at, f_to = edges(samples, fsync)
        return ([a for a, t in zip(c_at, c_to) if t], [a for a, t in zip(c_at, c_to) if not t],
                [a for a, t in zip(f_at, f_to) if t], [a for a, t in zip(f_at, f_to) if not t])

    def timing(samples, rate, _capture, _decode, _log):
        rises, _, ups, downs = clock(samples)
        at = np.array(rises)

        def between(a, b):
            return int(np.searchsorted(at, b) - np.searchsorted(at, a))

        high = [between(u, d) for u, d in zip(ups, [d for d in downs if d > ups[0]])]
        frames = [between(a, b) for a, b in zip(ups, ups[1:])]
        periods = [b - a for a, b in zip(rises, rises[1:])]
        return [count("SCLK periods FSYNC is high", AN301 % "p.3 and Figure 4", high,
                      at_least=1, unit="periods"),
                count("SCLK rises a frame", AN301 % "Figure 3, 8 channels of 32 bits", frames,
                      at_least=256, unit="rises"),
                count("SCLK rises a frame", AN301 % "Figure 3, 8 channels of 32 bits", frames,
                      at_most=256, unit="rises"),
                bound("SCLK period", "6 cycles at 48 MHz, the firmware's SCLK, to half a period "
                      "(AN301 gives no least or most)", [span(p, rate) for p in periods],
                      at_least=0.5 * TDM_BIT),
                bound("SCLK period", "6 cycles at 48 MHz, the firmware's SCLK, to half a period "
                      "(AN301 gives no least or most)", [span(p, rate) for p in periods],
                      at_most=1.5 * TDM_BIT)]

    def byte_tooth(samples, _rate, _capture, _decode):
        """SDATA inverted over channel 1's MSB, from FSYNC's fall to the next SCLK fall."""
        _, falls, _, downs = clock(samples)
        return (changed(samples, sdata, downs[0], after(falls, downs[0])),
                "SDATA inverted over channel 1's MSB")

    def edge_tooth(samples, rate):
        """The second FSYNC rise six bits early."""
        _, _, ups, downs = clock(samples)
        early = ups[1] - round(6 * TDM_BIT * rate)
        out = moved(samples, fsync, downs[1], early + (downs[1] - ups[1]))
        return (moved(out, fsync, ups[1], early), "the second FSYNC six bits early",
                "SCLK rises a frame")

    return timing, byte_tooth, edge_tooth


@dataclass(frozen=True)
class Demo:
    # demo/outside.sh's sigrok arguments, or demo/ledger.py's
    decode: str
    analyser: str
    channels: dict
    # what the chip runs: python/bench_firmware.py's names, or test/ files
    firmware: tuple
    # what Pico A runs
    scripts: tuple
    peer: str
    protocol: tuple
    limits: tuple = ()
    # the run's file names, the demo's unless given
    stem: str = ""
    # what the capture, sigrok's decode and Pico A's log lack of the demo's bytes, from
    # demo/traffic.py unless given
    judge: object = None

    def name(self, demo):
        return self.stem or demo

    def problems(self, demo, capture, samples, decoded, log):
        if self.judge:
            return self.judge(capture, decoded, log)
        name = self.name(demo)
        return traffic.judge(name, traffic.lines(name, samples), decoded.splitlines(), log)


I2C = "-P i2c:sda=D6:scl=D7,eeprom24xx:chip=onsemi_cat24c256 -A eeprom24xx"
I2C_PINS = {"D6": "SDA, IO3, 2k2 pull-up", "D7": "SCL, IO2, 2k2 pull-up"}
I2C_LIMITS = ("SCL and SDA as the analyser's threshold sees them, so the most rise time "
              "comes off each least",)
CAN_DECODE = ("-P can:can_rx=D5:nominal_bitrate=500000 "
              "-A can=id:dlc:data:crc-sequence:ack-slot:warnings")
CAN_PINS = {"D5": "CAN board A's R, the bus as both nodes drive it"}
CAN_LIMITS = ("the bus at CAN board A's receiver, so its edges carry the SN65HVD230's delay",
              "the ACK slot is the receiver's and only must be there, not on the grid")
SPI_PINS = {"D0": "SCK, OUT5", "D1": "MOSI, OUT4", "D2": "MISO, IN0", "D3": "CS, OUT6"}


def outside(name):
    """The sigrok arguments on python/demo_<name>.py's "# outside:" line."""
    for line in (ROOT / "python" / ("demo_%s.py" % name)).read_text().splitlines():
        if line.startswith("# outside: "):
            return line.split("decode=", 1)[1]
    raise ValueError("python/demo_%s.py has no outside: line" % name)


DRAWN = ("drawn at random and written blind from its spec (docs/flexibility.md)",)


def sweep_i2c(mode, firmware):
    return Demo(I2C, "B", I2C_PINS, (firmware,), ("python/demo_rates.py", "python/demo_eeprom.py"),
                "a 24LC256 on the I2C bus", i2c(6, 7, mode), I2C_LIMITS,
                stem="i2c_%s" % ("100k" if mode == "standard" else "400k"),
                judge=lambda capture, decoded, log: sweep_rates.i2c_problems(
                    capture, mode, decoded, log))


def sweep_spi(mode):
    return Demo("-P spi:clk=D0:mosi=D1:miso=D2:cs=D3:cpol=%d:cpha=%d "
                "-A spi=mosi-transfer:miso-transfer" % (mode >> 1, mode & 1), "B", SPI_PINS,
                ("SPI_CS_MODE%d" % mode,), ("python/demo_rates.py", "python/demo_flash.py"),
                "a W25Q64JV flash, read for its JEDEC ID", spi(0, 1, 2, 3), (),
                stem="spi_mode%d" % mode,
                judge=lambda capture, decoded, _log: sweep_rates.spi_problems(
                    capture, mode, decoded))


DEMOS = {
    "eeprom": Demo(I2C, "B", I2C_PINS, ("I2C_MASTER", "START_HOLD"), ("python/demo_eeprom.py",),
                   "a 24LC256 on the I2C bus", i2c(6, 7), I2C_LIMITS),
    "flash": Demo("-P spi:clk=D0:mosi=D1:miso=D2:cs=D3,spiflash:chip=winbond_w25q80dv "
                  "-A spiflash", "B", SPI_PINS, ("SPI_CS_MODE0",), ("python/demo_flash.py",),
                  "a W25Q64JV flash, erased, programmed and read back", spi(0, 1, 2, 3)),
    "sweep_i2c_100k": sweep_i2c("standard", "I2C_STANDARD"),
    "sweep_i2c_400k": sweep_i2c("fast", "I2C_FAST"),
    "sweep_spi_mode0": sweep_spi(0),
    "sweep_spi_mode3": sweep_spi(3),
    "ds18b20": Demo("-P onewire_link:owr=D5,onewire_network -A onewire_network", "B",
                    {"D5": "DQ, IO4, 4k7 pull-up"}, ("ONE_WIRE",), ("python/demo_ds18b20.py",),
                    "a DS18B20 on DQ", one_wire(5),
                    ("read slots, the DS18B20's, are counted but not held to a window",)),
    "neopixel": Demo("-P rgb_led_ws281x:din=D4 -A rgb_led_ws281x=rgb:reset", "B",
                     {"D4": "OUT3 at the 74AHCT125's input, not the stick's DIN"},
                     ("SK6812",), ("python/demo_neopixel.py",),
                     "an SK6812 stick behind a 74AHCT125", ws2812(4),
                     ("the SK6812's windows are a few samples wide, so some stay "
                      "unresolved",)),
    "can": Demo(CAN_DECODE, "A", CAN_PINS, ("CAN",), ("python/demo_can.py",),
                "Pico B as a CAN node on the far SN65HVD230, which ACKs", can(5), CAN_LIMITS),
    "can_node": Demo(CAN_DECODE, "A", CAN_PINS, ("CAN_SENDER", "CAN_RECEIVER"),
                     ("python/demo_can_node.py",),
                     "Pico B as a CAN node on the far SN65HVD230, sending and ACKing", can(5),
                     CAN_LIMITS + ("Pico B's own frames are held to the same windows",)),
    "swd": Demo("-P swd:swclk=D6:swdio=D7 -A swd", "A",
                {"D6": "SWCLK, OUT2", "D7": "SWDIO, IO5, 4k7 pull-up"}, ("SWD",),
                ("python/demo_swd.py",), "Pico B's RP2040 as the SWD target", swd(6, 7),
                ("sigrok misreads the dormant wake and TARGETSEL, so only reads are held to "
                 "the bytes",)),
    "nec": Demo("-P ir_nec:ir=D4 -A ir_nec=addr:addr-inv:cmd:cmd-inv:repeat-code", "A",
                {"D4": "OUT0, low for a mark"}, ("NEC_TX",), ("python/demo_nec.py",),
                "nothing, OUT0 as an IR receiver module's output would be, Pico B idle on it",
                nec(4),
                ("NEC has no datasheet table, so its windows are test/nec.ml's frames and "
                 "Nec.decode's 5%",)),
    "microwire": Demo(outside("microwire"), "B",
                      {"D0": "SK, OUT5, the flash's CLK", "D1": "DI, OUT4, the flash's DI",
                       "D2": "DO, IN0, the flash's DO", "D3": "CS, OUT6, the flash's CS"},
                      ("MICROWIRE",), ("python/demo_microwire.py",),
                      "nothing: the flash on the same pins is deselected while CS is high",
                      microwire(0, 1, 3),
                      DRAWN + ("no bench part answers MICROWIRE, so DO is not held to "
                               "anything",
                               "each window is the strictest the library's AN-452 parts "
                               "give")),
    "xy2_100": Demo(outside("xy2_100"), "B",
                    {"D4": "SENDCK, OUT3", "D1": "SYNC, OUT4, the flash's DI",
                     "D3": "DATA, OUT6, the flash's CS"},
                    ("XY2_100",), ("python/demo_xy2_100.py",),
                    "nothing, the flash's clock held still", xy2_100(4, 3),
                    DRAWN + ("tDS and tDH are held on DATA only, as the library holds them",)),
    "caliper": Demo(outside("caliper"), "A",
                    {"D4": "CLK, OUT0", "D6": "DATA, OUT2, SWCLK to Pico B's idle RP2040"},
                    ("CALIPER",), ("python/demo_caliper.py",),
                    "nothing, Pico B idle on OUT0", caliper(4, 6),
                    DRAWN + ("the page gives its times as about, which the library holds as "
                             "least times",)),
    "lfast": Demo(outside("lfast"), "A", {"D4": "OUT0"}, ("LFAST",), ("python/demo_lfast.py",),
                  "nothing, Pico B idle on OUT0", lfast(4, demo_lfast.WORDS),
                  DRAWN + ("AN5134's one limit is a top rate, so the bit windows are the "
                           "firmware's own bit to half a bit",)),
    "ir_rc6": Demo(outside("ir_rc6"), "A", {"D4": "OUT0, high for a mark, no carrier"},
                   ("IR_RC6",), ("python/demo_ir_rc6.py",),
                   "nothing, Pico B idle on OUT0", ir_rc6(4, demo_ir_rc6.FRAMES),
                   DRAWN + ("the page gives no tolerance, so the windows are its nominal "
                            "times to Ir_rc6.decode's 5%",)),
    "tdm_audio": Demo(outside("tdm_audio"), "B",
                      {"D4": "SCLK, OUT3", "D1": "FSYNC, OUT4, the flash's DI",
                       "D3": "SDATA, OUT6, the flash's CS"},
                      ("TDM_AUDIO",), ("python/demo_tdm_audio.py",),
                      "nothing, the flash's clock held still", tdm_audio(4, 1, 3),
                      DRAWN + ("AN301 gives no times, so the SCLK window is the firmware's own "
                               "period to half a period, and the frame is held in SCLK "
                               "periods",)),
    "self_timing": Demo("-P uart:rx=D4:baudrate=9600 -A uart=rx-data", "A",
                        {"D4": "OUT0, engine 1's echo of wire 20"},
                        ("test/uart_tx_host_rate.hex", "test/edge_logger_echo.hex"),
                        ("python/demo_self_timing.py",),
                        "Pico B listening on OUT0", uart(4, 9600, 48e6),
                        ("the echo's delay is the same for every edge, so only offsets from "
                         "each start bit are compared",)),
}
LIMITS = (
    "one run of one board, the ECP5 build of the chip's RTL, not the ASIC",
    "the run's files are the bench's own record, tied together by SHA256SUMS, and CI "
    "derives the decode and the timing from the capture alone",
    "each edge is known to a sample either way and the analyser's crystal to 100 ppm, and a "
    "window the capture cannot settle is unresolved, not passed",
)


def firmware_hash(name, text_at):
    """sha256 of a test/ file, or of one of python/bench_firmware.py's entries as sorted
    JSON. text_at(path) reads a file as the run had it."""
    if "/" in name:
        return sha256(text_at(name))
    scope = {}
    exec(text_at("python/bench_firmware.py").decode(), scope)
    return sha256(json.dumps(scope[name], sort_keys=True, separators=(",", ":")).encode())


def in_tree(path):
    return (ROOT / path).read_bytes()


def at_commit(commit):
    """A file as commit has it; a dirty run's tree is read at the commit it was dirty on."""
    commit = commit.removesuffix("+dirty")
    return lambda path: subprocess.run(["git", "-C", str(ROOT), "show", "%s:%s" % (commit, path)],
                                       capture_output=True, check=True).stdout


def ledger_fields(directory):
    return dict(re.findall(r"^(\w+): (.*)$", (directory / "ledger.txt").read_text(), re.M))


def sums(directory):
    return {name.lstrip("*"): sha for sha, name in
            (line.split(maxsplit=1) for line in (directory / "SHA256SUMS").read_text().splitlines())}


def teeth(demo, samples, rate, capture, log, scratch):
    """Each tooth's description and why it was refused, or None when it was not."""
    d = DEMOS[demo]
    timing, byte_tooth, edge_tooth = d.protocol
    toothed, what = byte_tooth(samples, rate, capture, d.decode)
    path = Path(scratch) / "byte.sr"
    sigrok.write(path, rate, toothed)
    wrong = d.problems(demo, path, toothed, decode_text(path, d.decode.split()).decode(), log)
    out = [(what, wrong[0] if wrong else None)]
    toothed, what, parameter = edge_tooth(samples, rate)
    path = Path(scratch) / "edge.sr"
    sigrok.write(path, rate, toothed)
    failed = [r for r in timing(toothed, rate, path, d.decode, log)
              if r["parameter"] == parameter and r["verdict"] == "fail"]
    out.append((what, "%s %s measured %s" % (parameter, failed[0]["limit"], failed[0]["measured"])
                if failed else None))
    return out


def files(demo):
    name = DEMOS[demo].name(demo)
    return [k.format(name) for k in KEPT]


def witness(directory, scratch):
    """witness.json's fields the run in directory makes, all but what it cannot say, and
    its teeth()."""
    fields = ledger_fields(directory)
    demo = fields["demo"]
    d = DEMOS[demo]
    name = d.name(demo)
    capture = directory / ("%s.sr" % name)
    rate, _, samples = sigrok.read(capture)
    log = (directory / ("%s.log" % name)).read_text(errors="replace")
    timing = d.protocol[0](samples, rate, capture, d.decode, log)
    bitten = teeth(demo, samples, rate, capture, log, scratch)
    return {
        "demo": demo,
        "time": fields["time"],
        "result": fields["result"],
        "commit": fields["commit"],
        "bitstream_sha256": fields["bitstream_sha256"],
        "netlist_sha256": fields.get("netlist_sha256", "not recorded"),
        "sums_sha256": sha256((directory / "SHA256SUMS").read_bytes()),
        "capture": {"file": capture.name, "sha256": sums(directory)[capture.name],
                    "rate_hz": int(rate), "seconds": len(samples) / rate,
                    "analyser": d.analyser, "channels": d.channels},
        "decode": {"arguments": d.decode, "sha256": sums(directory)["%s.decode" % name]},
        "timing": timing,
        "teeth": [what for what, _ in bitten],
    }, bitten


def check(directory):
    """What is wrong with the witness in directory, and its teeth's verdicts."""
    directory = Path(directory)
    w = json.loads((directory / "witness.json").read_text())
    demo = w["demo"]
    d = DEMOS[demo]
    name = d.name(demo)
    problems = []
    listed = sums(directory)
    for kept in files(demo) + ["%s.decode" % name]:
        if kept not in listed:
            problems.append("SHA256SUMS lists no %s" % kept)
        elif not kept.endswith(".decode") and sha256((directory / kept).read_bytes()) != listed[kept]:
            problems.append("%s does not match SHA256SUMS" % kept)
    if sha256((directory / "SHA256SUMS").read_bytes()) != w["sums_sha256"]:
        problems.append("SHA256SUMS is not the one the ledger row names")
    for firmware in d.firmware:
        if firmware_hash(firmware, in_tree) != w["firmware"].get(firmware):
            problems.append("%s is not the firmware the board ran" % firmware)
    for script in d.scripts:
        if sha256(in_tree(script)) != w["host_scripts"].get(script):
            problems.append("%s is not the script Pico A ran" % script)
    if problems:
        return problems, []
    with tempfile.TemporaryDirectory() as scratch:
        made, bitten = witness(directory, scratch)
    for key, value in made.items():
        if w.get(key) != value:
            problems.append("witness.json's %s is not what the run makes: %s" % (
                key, json.dumps(value)[:400]))
    capture = directory / ("%s.sr" % name)
    decoded = decode_text(capture, d.decode.split())
    if sha256(decoded) != w["decode"]["sha256"]:
        problems.append("sigrok decodes the capture otherwise than the bench did")
    _, _, samples = sigrok.read(capture)
    log = (directory / ("%s.log" % name)).read_text(errors="replace")
    problems += d.problems(demo, capture, samples, decoded.decode(), log)
    problems += ["%s %s: %s, measured %s" % (r["parameter"], r["limit"], r["verdict"],
                                             r["measured"])
                 for r in made["timing"] if r["verdict"] in ("fail", "absent")]
    return problems, bitten


def write(run, directory, carrier, bitstream):
    """A ledger run's witness, its files copied into directory. bitstream says what the
    bitstream was built from, when the run does not."""
    run, directory = Path(run), Path(directory)
    fields = ledger_fields(run)
    demo = fields["demo"]
    d = DEMOS[demo]
    directory.mkdir(parents=True, exist_ok=True)
    for kept in files(demo) + ["SHA256SUMS"]:
        shutil.copy(run / kept, directory / kept)
    ran = at_commit(fields["commit"])
    with tempfile.TemporaryDirectory() as scratch:
        made, _ = witness(directory, scratch)
    built = ("the bitstream is named by its sha256, and its netlist's, built from %s by the "
             "bench's notes, which CI does not rebuild" % bitstream if bitstream else
             "the bitstream is named by its sha256, which CI cannot rebuild, and its source "
             "commit was not recorded")
    dirty = ("the run's tree had uncommitted changes, so its firmware and scripts are hashed "
             "at the commit under them",) if fields["commit"].endswith("+dirty") else ()
    w = {
        **made,
        "bitstream_source": bitstream or "not recorded",
        "firmware_sha256": "of each python/bench_firmware.py entry as sorted, compact JSON, "
                           "or of the test/ file, at the run's commit",
        "firmware": {f: firmware_hash(f, ran) for f in d.firmware},
        "host_scripts": {f: sha256(ran(f)) for f in d.scripts},
        "bench": ("an Icepi Zero (ECP5 LFE5U-25F) running the chip at 48 MHz on bench carrier "
                  "%s, Pico A as the host on SPI, %s, analyser %s (fx2lafw) at %g MS/s" % (
                      carrier, d.peer, d.analyser, made["capture"]["rate_hz"] / 1e6)),
        "scope": "the bytes on the wire and their timing in one run of %s, as the analyser "
                 "saw them" % demo,
        "limits": list(LIMITS + (built,) + dirty + d.limits),
    }
    (directory / "witness.json").write_text(json.dumps(w, indent=2) + "\n")
    problems, _ = check(directory)
    for problem in problems:
        print("%s: %s" % (demo, problem))
    return not problems


def main():
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    checking = sub.add_parser("check")
    checking.add_argument("directories", nargs="+")
    writing = sub.add_parser("write")
    writing.add_argument("run")
    writing.add_argument("directory")
    writing.add_argument("--carrier", default="v1.2")
    writing.add_argument("--bitstream", help="what the bitstream was built from")
    args = parser.parse_args()
    if args.command == "write":
        sys.exit(0 if write(args.run, args.directory, args.carrier, args.bitstream) else 1)
    ok = True
    for directory in args.directories:
        problems, bitten = check(directory)
        name = Path(directory).name
        for problem in problems:
            print("FAIL %s: %s" % (name, problem))
        for what, why in bitten:
            print("TOOTH %s: %s refused: %s" % (name, what, why[:200]) if why else
                  "MISSED %s: %s passed" % (name, what))
        if not problems:
            w = json.loads((Path(directory) / "witness.json").read_text())
            proved = sum(r["verdict"] == "proved" for r in w["timing"])
            print("PASS %s: %s, bitstream %s, %d of %d windows proved, %d unresolved" % (
                name, w["capture"]["sha256"][:16], w["bitstream_sha256"][:16], proved,
                len(w["timing"]), len(w["timing"]) - proved))
        ok = ok and not problems and all(why for _, why in bitten)
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
