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

import frames
import numpy as np
import sigrok
import sweep_rates
import traffic

ROOT = Path(__file__).resolve().parent.parent
# copied from the ledger run, each listed in its SHA256SUMS
KEPT = ["{}.sr", "{}.log", "ledger.txt", "run.txt"]
# a demo with no capture keeps its log alone
LOG_KEPT = ["{}.log", "ledger.txt", "run.txt"]
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


@dataclass(frozen=True)
class LogDemo:
    # what the chip runs, test/ files, and what Pico A runs
    firmware: tuple
    scripts: tuple
    peer: str
    # the log's tally and problems, and its teeth
    judge: object
    teeth: object
    limits: tuple = ()


LOG_DEMOS = {
    "eth_rx": LogDemo(
        ("test/ethernet_rx.hex", "test/ethernet_rx.cert.hex"),
        ("python/demo_ethernet_rx.py", "python/ethernet.py", "python/bench.py"),
        "Pico A's PIO as the 10BASE-T sender on IO0, at 10 Mb/s off its own crystal",
        frames.judge, frames.teeth,
        ("10 Mb/s is past the analyser, so the log is the run's only record: CI judges its "
         "frames again from the bytes it says were sent",
         "the line is Pico A's 3.3 V logic, as a line receiver with squelch would give "
         "the chip, not a twisted pair through a transformer")),
}


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
    if demo in LOG_DEMOS:
        return [k.format(demo) for k in LOG_KEPT]
    name = DEMOS[demo].name(demo)
    return [k.format(name) for k in KEPT]


def log_witness(directory):
    """witness.json's fields a run with no capture makes, and its teeth."""
    fields = ledger_fields(directory)
    demo = fields["demo"]
    d = LOG_DEMOS[demo]
    log = (directory / ("%s.log" % demo)).read_text(errors="replace")
    tally, _ = d.judge(log)
    bitten = d.teeth(log)
    return {
        "demo": demo,
        "time": fields["time"],
        "result": fields["result"],
        "commit": fields["commit"],
        "bitstream_sha256": fields["bitstream_sha256"],
        "netlist_sha256": fields.get("netlist_sha256", "not recorded"),
        "sums_sha256": sha256((directory / "SHA256SUMS").read_bytes()),
        "log": {"file": "%s.log" % demo, "sha256": sums(directory)["%s.log" % demo]},
        "tally": tally,
        "teeth": [what for what, _ in bitten],
    }, bitten


def check_log(directory, w):
    """check() for a demo with no capture."""
    demo = w["demo"]
    d = LOG_DEMOS[demo]
    problems = []
    listed = sums(directory)
    for kept in files(demo):
        if kept not in listed:
            problems.append("SHA256SUMS lists no %s" % kept)
        elif sha256((directory / kept).read_bytes()) != listed[kept]:
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
    made, bitten = log_witness(directory)
    for key, value in made.items():
        if w.get(key) != value:
            problems.append("witness.json's %s is not what the run makes: %s" % (
                key, json.dumps(value)[:400]))
    log = (directory / ("%s.log" % demo)).read_text(errors="replace")
    return problems + d.judge(log)[1], bitten


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
    if demo in LOG_DEMOS:
        return check_log(directory, w)
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
    d = LOG_DEMOS.get(demo) or DEMOS[demo]
    directory.mkdir(parents=True, exist_ok=True)
    for kept in files(demo) + ["SHA256SUMS"]:
        shutil.copy(run / kept, directory / kept)
    ran = at_commit(fields["commit"])
    if demo in LOG_DEMOS:
        made, _ = log_witness(directory)
    else:
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
        "bench": ("an Icepi Zero (ECP5 LFE5U-25F) running the chip at %s on bench carrier "
                  "%s, Pico A as the host on SPI, %s%s" % (
                      "40 MHz" if demo in LOG_DEMOS else "48 MHz", carrier, d.peer,
                      "" if demo in LOG_DEMOS else ", analyser %s (fx2lafw) at %g MS/s" % (
                          d.analyser, made["capture"]["rate_hz"] / 1e6))),
        "scope": ("each frame's bytes and the receiver's verdict in one run of %s, as Pico "
                  "A logged them" % demo if demo in LOG_DEMOS else
                  "the bytes on the wire and their timing in one run of %s, as the analyser "
                  "saw them" % demo),
        "limits": list((LIMITS[0],) + (built,) + dirty + d.limits if demo in LOG_DEMOS
                       else LIMITS + (built,) + dirty + d.limits),
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
        if not problems and "tally" in json.loads((Path(directory) / "witness.json").read_text()):
            t = json.loads((Path(directory) / "witness.json").read_text())["tally"]
            print("PASS %s: %d of %d frames received whole, %d with a bad FCS refused" % (
                name, t["received_whole"], t["frames"], t["bad_fcs"]))
        elif not problems:
            w = json.loads((Path(directory) / "witness.json").read_text())
            proved = sum(r["verdict"] == "proved" for r in w["timing"])
            print("PASS %s: %s, bitstream %s, %d of %d windows proved, %d unresolved" % (
                name, w["capture"]["sha256"][:16], w["bitstream_sha256"][:16], proved,
                len(w["timing"]), len(w["timing"]) - proved))
        ok = ok and not problems and all(why for _, why in bitten)
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
