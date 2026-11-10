# SPDX-License-Identifier: Apache-2.0
# Checks a bench run kept in test/board/<run>/ as demo/ledger.py wrote it, where witness.json
# names its bitstream, firmware, host scripts and bench. A check re-hashes the files,
# decodes the capture again, compares the bytes with what was sent and the edges with the
# datasheet windows, then breaks each with its teeth (a bit flipped in the waveform, an edge
# moved) and expects the check to fail.
# Usage: python3 demo/witness.py check test/board/*/
#        python3 demo/witness.py write LEDGER_RUN test/board/RUN [--bitstream FROM]
#        python3 demo/witness.py refresh test/board/*/

import argparse
import ast
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

import ffmpeg_referee
import frames
import kernel_vs_board
import keys
import learn_witness
import numpy as np
import sigrok
import sweep_rates
import traffic

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "python"))
import demo_ir_rc6  # noqa: E402
import demo_lfast  # noqa: E402
import demo_spdif_ac3  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
# copied from the ledger run; each is listed in its SHA256SUMS
KEPT = ["{}.sr", "{}.log", "ledger.txt", "run.txt"]
# what a LogDemo keeps besides its own files
LOG_KEPT = ("ledger.txt", "run.txt")
# allowed difference between the analyser's crystal and the chip's, in either direction
PPM = 100e-6
# 24LC256, Table 1-2 param 4: SDA and SCL take up to 300 ns to rise, which the analyser's
# threshold doesn't see, so subtract it from every I2C interval's minimum
TR = 300e-9
# a window's limit is the cited spec's, our firmware's or decoder's where the spec gives none,
# sigrok's decoder's, or derived from what the capture holds
SOURCES = ("spec", "own", "decoder", "derived")


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def span(n, rate):
    """Returns where an interval the analyser saw as n samples lies, in seconds. Each end
    could be anywhere within its sample."""
    return (n - 1) / rate * (1 - PPM), (n + 1) / rate * (1 + PPM)


def show(seconds, limit):
    if math.isinf(seconds):
        return "open"
    if limit < 10e-6:
        return "%.0f ns" % (seconds * 1e9)
    return "%.2f us" % (seconds * 1e6)


def bound(parameter, sheet, spans, at_least=None, at_most=None, slack=0.0, source="spec"):
    """Checks a datasheet window against spans, each (lo, hi). Proved if every span is
    inside the window (with `slack` less at the bottom), failed if one is wholly outside,
    otherwise unresolved."""
    assert source in SOURCES
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
        "source": source,
        "spans": len(spans),
        "measured": "%s to %s" % (show(min(s[0] for s in spans), limit),
                                  show(max(s[1] for s in spans), limit)) if spans else "-",
        "verdict": verdict,
    }


def count(parameter, sheet, counts, at_least=None, at_most=None, unit="bits", source="spec"):
    """Like bound(), but over whole counts, which the analyser sees exactly."""
    record = bound(parameter, sheet, [(c, c) for c in counts], at_least, at_most,
                   source=source)
    limit = at_least if at_most is None else at_most
    record["limit"] = "%s %d %s" % (record["limit"][:2], limit, unit)
    if counts:
        record["measured"] = "%d to %d %s" % (min(counts), max(counts), unit)
    return record


def runs(samples, bit):
    """Returns each run of one level on a channel as (level, first sample, samples), without
    the two runs cut off by the capture's ends."""
    at, to = sigrok.edges(samples, bit)
    return [(int(to[i]), int(at[i]), int(at[i + 1] - at[i])) for i in range(len(at) - 1)]


def edges(samples, bit):
    at, to = sigrok.edges(samples, bit)
    return at.tolist(), to.tolist()


def after(sorted_at, sample):
    """Returns the first entry of sorted_at after sample, or None."""
    i = int(np.searchsorted(sorted_at, sample, side="right"))
    return sorted_at[i] if i < len(sorted_at) else None


def before(sorted_at, sample):
    i = int(np.searchsorted(sorted_at, sample, side="left"))
    return sorted_at[i - 1] if i else None


def annotations(capture, decode, classes):
    """Returns sigrok's lines for the given classes from the decode's stack, each (first, last sample, text)."""
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
    """Returns the samples with the channel inverted, or held at level, from first up to last."""
    out = np.frombuffer(samples, np.uint8).copy()
    mask = np.uint8(1 << bit)
    if level is None:
        out[first:last] ^= mask
    else:
        out[first:last] = (out[first:last] & ~mask) | (mask if level else 0)
    return out.tobytes()


def moved(samples, bit, at, to):
    """Returns the samples with the channel's edge at `at` moved to `to`."""
    level = (samples[at - 1] >> bit) & 1
    if to > at:
        return changed(samples, bit, at, to, level)
    return changed(samples, bit, to, at, level ^ 1)


# 24LC256 at 2.5..5.5 V (Table 1-2's 400 kHz column) and UM10204's modes. tr is the maximum
# rise time, which is subtracted from every minimum
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
        # SDA moves while SCL is high on both sides: a falling SDA is a START, a rising one a STOP
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
            # from a STOP to the next START (not a repeated START)
            p, q = before(stops, s), before(starts, s)
            if p is not None and (q is None or q < p):
                n["TBUF"].append(s - p)
        for p in stops:
            if (r := before(rises, p)) is not None:
                n["TSU:STO"].append(p - r)
        for f in falls:
            if (r := after(rises, f)) is not None:
                n["TLOW"].append(r - f)
                # from the data's last move while SCL was low to the rise that samples it
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
        """Inverts bit 1 of the page write's fifth byte; SDA moves while SCL is low."""
        first, last, _ = next(a for a in annotations(capture, decode, "eeprom24xx=data-byte")
                              if "Data byte 7FC4:" in a[2])
        falls = [a for a, t in zip(*edges(samples, scl)) if not t and first <= a <= last]
        return (changed(samples, sda, falls[1] + 2, falls[2] + 2),
                "SDA inverted over bit 1 of the page write's byte at 0x7fc4")

    def edge_tooth(samples, _rate):
        """Cuts the tenth SCL pulse after the first START to six samples."""
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
        # bytes the master writes: ROM commands, and the function command after Skip ROM
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
        """Holds READ ROM's bit 0 (a 1) low for 66 us, which makes it a 0."""
        found = lows(samples)
        reset = next(i for i, (_, n) in enumerate(found) if n > 300e-6 * rate)
        fall, _ = found[reset + 2]
        return (changed(samples, dq, fall, fall + round(66e-6 * rate), 0),
                "READ ROM's first slot held low 66 us")

    def edge_tooth(samples, rate):
        """Lets go of the first reset after 470 us."""
        fall, width = next((f, n) for f, n in lows(samples) if n > 300e-6 * rate)
        return (moved(samples, dq, fall + width, fall + round(470e-6 * rate)),
                "the first reset cut to 470 us", "tRSTL")

    return timing, byte_tooth, edge_tooth


SK6812 = "SK6812, OSK-SPC-SK6812-012 Rev. B/1 p.7"


def ws2812(din):
    def bits(samples, rate):
        """Returns each high, whether it is a 1, and the low after it (None for a reset)."""
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
        # the lows cut by the capture, before the first frame and after the last
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
        """Holds the first bit (a 0) high as long as a 1."""
        first, _, _, _ = bits(samples, rate)[0]
        return (changed(samples, din, first, first + round(700e-9 * rate), 1),
                "the first bit held high 700 ns")

    def edge_tooth(samples, rate):
        """Makes the first 1's high 400 ns longer."""
        first, high, _, _ = next(b for b in bits(samples, rate) if b[2])
        return (moved(samples, din, first + high, first + high + round(400e-9 * rate)),
                "the first 1 held high 400 ns longer", "T1H")

    return timing, byte_tooth, edge_tooth


CAN_BIT = 2e-6
# the maximum clock error of a CAN node (Hartwich and Bassemir, The Configuration of the CAN
# Bit Timing, Bosch, 6th iCC 1999)
CAN_TOLERANCE = 0.0158


def can(rx):
    def frames(samples, rate):
        """Returns each frame's edges. The first frame starts at the start of frame after eleven recessive bits."""
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
            # the last two edges are the receiver's ACK; the rest are the transmitter's
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
            # recessive before the start of frame (from the capture's start for the first frame)
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
        """Inverts the first data byte's fourth bit. sigrok's annotation starts at the
        byte's first bit."""
        first, _, _ = next(a for a in annotations(capture, decode, "can=data")
                           if "Data byte 0:" in a[2])
        bit = CAN_BIT * rate
        return (changed(samples, rx, round(first + 3 * bit), round(first + 4 * bit)),
                "CAN R inverted over the first data byte's fourth bit")

    def edge_tooth(samples, rate):
        """Moves an edge after a one-bit run of the first frame a quarter bit late. A run is
        a sample either side of a bit, because the analyser's clock isn't the chip's."""
        frame = frames(samples, rate)[0]
        bit = round(CAN_BIT * rate)
        at = next(b for a, b in zip(frame, frame[1:-2]) if abs(b - a - bit) <= 1)
        return (moved(samples, rx, at, at + bit // 4),
                "an edge of the first frame a quarter bit late", "bit time, a run")

    return timing, byte_tooth, edge_tooth


def swd(swclk, swdio):
    rp2040 = "RP2040, RP2040 datasheet, 2025-02-20 s.2.3.4 p.61"

    def resets(samples):
        """Returns SWDIO's high runs that span more SWCLK rises than a read nobody answers,
        each with its first sample and its rises. The park bit, turnaround, ACK, 32 bits,
        parity and turnaround add up to 39."""
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
        """Inverts SWDIO over one bit of AP 0's IDR, which is read once."""
        first, last, _ = next(a for a in annotations(capture, decode, "swd")
                              if a[2] == "swd-1: 0x04770031")
        falls = [a for a, t in zip(*edges(samples, swclk)) if not t and first <= a <= last]
        return (changed(samples, swdio, falls[3] + 2, falls[4] + 2),
                "SWDIO inverted over a bit of AP 0's IDR")

    def edge_tooth(samples, _rate):
        """Moves the first line reset's SWDIO rise 20 SWCLK rises later."""
        first, clocks = resets(samples)[0]
        return (moved(samples, swdio, first, clocks[20] - 3),
                "the first line reset's rise 20 cycles late", "line reset")

    return timing, byte_tooth, edge_tooth


def uart(line, baud, clock_hz, logged=True):
    """logged: Pico A's log has the chip's edge log of each frame, to compare the edges with."""
    sheet = "UART at %d baud, Maxim AN2141 p.4, 2%%" % baud

    def frames(samples, rate):
        """Returns each frame's edges in samples, starting from its start bit's fall."""
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
        # the chip's own edge log, in cycles after each start bit
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
        if not logged:
            return records
        records.append({
            "parameter": "edge after its start bit",
            "limit": "where the chip's edge log puts it",
            "sheet": "Pico A's log, the chip's cycles at %g MHz" % (clock_hz / 1e6),
            "source": "own",
            "spans": len(misses),
            "measured": "%d frames of %d logged, misses %s" % (
                len(found), len(logged), show(max(misses, default=0.0), 1e-6)),
            "verdict": "proved" if misses and not any(misses) and not wrong
            and len(found) == len(logged) else "fail",
        })
        return records

    def byte_tooth(samples, rate, _capture, _decode):
        """Inverts bit 0 of the first byte at its middle."""
        start, bit = frames(samples, rate)[0][0], rate / baud
        return (changed(samples, line, round(start + 1.25 * bit), round(start + 1.75 * bit)),
                "half of the first byte's bit 0 inverted")

    def edge_tooth(samples, rate):
        """Moves the first frame's second edge 12 samples later."""
        at = frames(samples, rate)[0][1]
        return moved(samples, line, at, at + 12), "the first frame's second edge 12 samples late", "bit"

    return timing, byte_tooth, edge_tooth


W25Q64JV = "W25Q64JV, Winbond Rev. M %s"


def spi(sck, mosi, miso, cs):
    """Modes 0 and 3, the flash's: it samples on SCK's rising edge."""

    def frames(samples):
        """Returns each CS-low frame: its fall, its rise, SCK's rises and falls inside it, and
        the bytes MOSI sends at the rises."""
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
        """Inverts MISO over the first bit of the flash's manufacturer ID."""
        _, _, rises, falls, _ = jedec(samples)
        return (changed(samples, miso, before(falls, rises[8]) + 1, after(falls, rises[8]) + 1),
                "MISO inverted over the first bit of the JEDEC ID's manufacturer byte")

    def edge_tooth(samples, rate):
        """Puts the JEDEC frame's CS fall 2 us after the ABh frame's rise."""
        found = frames(samples)
        at = next(i for i, f in enumerate(found) if f[4][:1] == [0x9F])
        return (moved(samples, cs, found[at][0], found[at - 1][1] + round(2e-6 * rate)),
                "the JEDEC frame's CS fall 2 us after ABh", "tRES1")

    return timing, byte_tooth, edge_tooth


# NEC in units of 562.5 us, as test/nec.ml has it (SB-Projects' page). Each mark and space
# must be within 5%, as Nec.decode requires, and the period at least 5% under its 192
NEC = "NEC, test/nec.ml's frames and Nec.decode's 5%"
NEC_UNIT = 562.5e-6


def nec(line):
    def marks(samples):
        """Returns each mark (line low) as (first sample, samples, the space after it)."""
        found = runs(samples, line)
        return [(first, n, found[i + 1][2] if i + 1 < len(found) else None)
                for i, (level, first, n) in enumerate(found) if not level]

    def messages(samples, rate):
        """Returns each leader's mark, and the marks after it up to the next leader."""
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
            records.append(bound(p, NEC, spans, at_least=0.95 * k * NEC_UNIT, source="own"))
            records.append(bound(p, NEC, spans, at_most=1.05 * k * NEC_UNIT, source="own"))
        return records + [bound("period", NEC, [span(w, rate) for w in n["period"]],
                                at_least=0.95 * 192 * NEC_UNIT, source="own")]

    def byte_tooth(samples, rate, _capture, _decode):
        """Swaps the first command's bits 3 and 4 (a one then a zero) within the same six
        units, so the command reads 0x10."""
        bits = messages(samples, rate)[0][1:]
        start, end, unit = bits[19][0], bits[21][0], round(NEC_UNIT * rate)
        out = changed(samples, line, start, start + unit, 0)
        out = changed(out, line, start + unit, start + 2 * unit, 1)
        out = changed(out, line, start + 2 * unit, start + 3 * unit, 0)
        return (changed(out, line, start + 3 * unit, end, 1),
                "the first command's bits 3 and 4 swapped")

    def edge_tooth(samples, rate):
        """Shortens the first leader's mark by a unit."""
        start, mark, _ = messages(samples, rate)[0][0]
        return (moved(samples, line, start + mark, start + mark - round(NEC_UNIT * rate)),
                "the first leader mark a unit short", "leader mark")

    return timing, byte_tooth, edge_tooth


# The protocols drawn at random (docs/flexibility.md). The windows are the specs' limits
# where the spec has any, otherwise the nominal times that the library's firmware and
# decoder stick to. Each is named after its source.
AN452 = "National AN-452 (1992), %s"


def microwire(sk, di, cs):
    """Each window is the strictest that the library's AN-452 parts give."""

    def frames(samples):
        """Returns each CS high with SK rising inside: its rise, its fall, SK's rises and falls."""
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
        # an erase/write's CS low ends in a status window: a CS high with no SK in it
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
        """Inverts DI over EWEN's second bit, its first opcode bit."""
        _, _, rises, falls = frames(samples)[0]
        return (changed(samples, di, before(falls, rises[1]), after(falls, rises[1])),
                "DI inverted over EWEN's first opcode bit")

    def edge_tooth(samples, rate):
        """Puts EWEN's CS rise half a microsecond before SK's first rise."""
        up, _, rises, _ = frames(samples)[0]
        return (moved(samples, cs, up, rises[0] - round(0.5e-6 * rate)),
                "EWEN's CS rise 0.5 us before SK's first rise", "CS setup")

    return timing, byte_tooth, edge_tooth


XY2 = "Newson rhothor X7 XY2-100 datasheet rev. 0703, p.2"


def xy2_100(sendck, data):
    """DATA moves on SENDCK's rise and is read on its fall."""

    def clock(samples):
        c_at, c_to = edges(samples, sendck)
        return [a for a, t in zip(c_at, c_to) if t], [a for a, t in zip(c_at, c_to) if not t]

    def timing(samples, rate, _capture, _decode, _log):
        rises, falls = clock(samples)
        d_at = edges(samples, data)[0]
        n = {"tDS": [], "tDH": []}
        for last, f, nxt in zip(falls, falls[1:], falls[2:]):
            # DATA's last move up to this fall since the previous one, and its next one after it
            i = int(np.searchsorted(d_at, f, side="right"))
            if i and d_at[i - 1] > last:
                n["tDS"].append(f - int(d_at[i - 1]))
            if i < len(d_at) and d_at[i] < nxt:
                n["tDH"].append(int(d_at[i]) - f)
        return [bound("tDS", XY2, [span(x, rate) for x in n["tDS"]], at_least=50e-9),
                bound("tDH", XY2, [span(x, rate) for x in n["tDH"]], at_least=100e-9)]

    def byte_tooth(samples, _rate, _capture, _decode):
        """Inverts DATA over the first word's D15 (its fourth bit), so the parity no longer
        holds."""
        rises, _ = clock(samples)
        return changed(samples, data, rises[3], rises[4]), "DATA inverted over the first D15"

    def edge_tooth(samples, _rate):
        """Moves DATA's first change after the first word's tenth fall onto the next fall."""
        rises, falls = clock(samples)
        d_at = edges(samples, data)[0]
        at = int(d_at[np.searchsorted(d_at, falls[10], side="right")])
        return (moved(samples, data, at, after(falls, at)),
                "a DATA move put on the SENDCK fall after it", "tDS")

    return timing, byte_tooth, edge_tooth


CALIPER = "ShumaTech, Chinese Scales, page 1, %s"


def caliper(clk, data):
    """The page's nominal clock and pauses, which the library treats as minimum times. A
    pause is a clock high lasting four half periods."""
    half = 270 / 48e6

    def clock(samples, rate):
        found = [(level, first, n) for level, first, n in runs(samples, clk)]
        pauses = [r for r in found if r[0] and r[2] > 4 * half * rate]
        return found, pauses

    def timing(samples, rate, _capture, _decode, _log):
        found, pauses = clock(samples, rate)
        firsts = {p[1] for p in pauses}
        # the first pause runs from the firmware's start, and a frame's last pause runs into
        # the next frame's first: first, between, last and first, between, ...
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
        """Inverts DATA from the first fall to just past the first rise, where sigrok samples
        it: the first position's bit 0."""
        found, pauses = clock(samples, rate)
        fall = pauses[0][1] + pauses[0][2]
        rise = next(f for level, f, _ in found if level and f > fall)
        return changed(samples, data, fall, rise + 2), "DATA inverted over the first bit"

    def edge_tooth(samples, rate):
        """Shortens the first clock low by a microsecond."""
        found, pauses = clock(samples, rate)
        fall = pauses[0][1] + pauses[0][2]
        rise = next(f for level, f, _ in found if level and f > fall)
        return (moved(samples, clk, rise, rise - round(1e-6 * rate)),
                "the first clock low 1 us short", "clock low")

    return timing, byte_tooth, edge_tooth


def nominal(levels):
    """Returns levels, one per bit or unit, as runs of (level, count)."""
    out = []
    for level in levels:
        if out and out[-1][0] == level:
            out[-1][1] += 1
        else:
            out.append([level, 1])
    return out


def first_rise(found, idle):
    """Returns the index in runs() of the first high after more than `idle` samples low, or
    after the start of the capture."""
    return next((k for k, (level, _, n) in enumerate(found)
                 if level and (k == 0 or found[k - 1][2] > idle)), len(found))


def framed(samples, line, idle, frames):
    """Returns the line's runs from the first rise after more than `idle` samples low,
    paired with each frame's runs in turn as (expected level, count, samples), skipping
    low runs between frames; also returns each such low as (samples, the frame's trailing
    low units in it). A frame whose runs disagree in level or number ends the pairing,
    which its bytes will show."""
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
    """Returns a frame as it goes on the wire, MSB first: sync 0xA84B, header 0x09, the byte, the stop bit."""
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
                       at_least=(k - 0.5) * LFAST_BIT, source="own") for k in sorted(n)]
                + [bound("%d-bit level" % k, LFAST, [span(w, rate) for w in n.get(k, [])],
                         at_most=(k + 0.5) * LFAST_BIT, source="own") for k in sorted(n)]
                + [bound("a level", "NXP AN5134 Rev. 0, p.3: rates up to 320 Mb/s",
                         [span(w, rate) for v in n.values() for w in v], at_least=3.125e-9)])

    def start(samples, rate):
        found = runs(samples, line)
        return found[first_rise(found, 40 * LFAST_BIT * rate)][1]

    def byte_tooth(samples, rate, _capture, _decode):
        """Inverts the first payload's first bit."""
        at = start(samples, rate) + round(24 * LFAST_BIT * rate)
        return (changed(samples, line, at, at + round(LFAST_BIT * rate)),
                "the first payload's first bit inverted")

    def edge_tooth(samples, rate):
        """Makes the first frame's first bit 0.8 of a bit long."""
        at = start(samples, rate)
        end = at + next(n for level, f, n in runs(samples, line) if f == at)
        return (moved(samples, line, end, end + round(0.8 * LFAST_BIT * rate)),
                "the first sync bit 1.8 bits long", "1-bit level")

    return timing, byte_tooth, edge_tooth


RC6_UNIT = 444e-6
RC6 = ("SB-Projects' RC-6 page, 444 us a unit, to Ir_rc6.decode's 5% (the page gives no "
       "tolerance)")


def rc6_units(toggle, address, command):
    """Returns a mode 0 frame's levels, one per unit, with high meaning a mark: the leader,
    the start bit, mode 000, the trailer bit (two units, a half each), then address and
    command, MSB first."""
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
        # the low up to the next frame, minus the units of the last bit's space in it
        free = [w - round(k * RC6_UNIT * rate) for w, k in gaps]
        records = []
        for p in sorted(n, key=lambda p: (p[:4], int(p.split()[1][:-1]))):
            k = int(p.split()[1][:-1])
            spans = [span(w, rate) for w in n[p]]
            records.append(bound(p, RC6, spans, at_least=0.95 * k * RC6_UNIT, source="own"))
            records.append(bound(p, RC6, spans, at_most=1.05 * k * RC6_UNIT, source="own"))
        return records + [bound("signal free time", RC6, [span(w, rate) for w in free],
                                at_least=0.95 * 6 * RC6_UNIT, source="own")]

    def byte_tooth(samples, rate, _capture, _decode):
        """Swaps the halves of the first frame's first address bit, 20 units in (after the
        leader, the start bit, the mode and the trailer bit)."""
        start = next(f for level, f, n in runs(samples, line)
                     if level and n > 5 * RC6_UNIT * rate)
        unit = round(RC6_UNIT * rate)
        return (changed(samples, line, start + 20 * unit, start + 22 * unit),
                "the first address bit's halves swapped")

    def edge_tooth(samples, rate):
        """Shortens the first leader mark by a unit."""
        start, n = next((f, n) for level, f, n in runs(samples, line)
                        if level and n > 5 * RC6_UNIT * rate)
        return (moved(samples, line, start + n, start + n - round(RC6_UNIT * rate)),
                "the first leader mark a unit short", "mark 6t")

    return timing, byte_tooth, edge_tooth


TDM_BIT = 6 / 48e6
AN301 = "Cirrus Logic AN301 Rev. 1, %s"


def tdm_audio(sclk, fsync, sdata):
    """AN301 gives no times, only the frame in SCLK periods: FSYNC high for at least one,
    and eight 32-bit blocks per frame, as the firmware and sigrok's options assume."""

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
                      at_least=0.5 * TDM_BIT, source="own"),
                bound("SCLK period", "6 cycles at 48 MHz, the firmware's SCLK, to half a period "
                      "(AN301 gives no least or most)", [span(p, rate) for p in periods],
                      at_most=1.5 * TDM_BIT, source="own")]

    def byte_tooth(samples, _rate, _capture, _decode):
        """Inverts SDATA over channel 1's MSB, from FSYNC's fall to the next SCLK fall."""
        _, falls, _, downs = clock(samples)
        return (changed(samples, sdata, downs[0], after(falls, downs[0])),
                "SDATA inverted over channel 1's MSB")

    def edge_tooth(samples, rate):
        """Moves the second FSYNC rise six bits earlier."""
        _, _, ups, downs = clock(samples)
        early = ups[1] - round(6 * TDM_BIT * rate)
        out = moved(samples, fsync, downs[1], early + (downs[1] - ups[1]))
        return (moved(out, fsync, ups[1], early), "the second FSYNC six bits early",
                "SCLK rises a frame")

    return timing, byte_tooth, edge_tooth


# The held-out protocols (test/heldout.txt). The windows are the rows the kernel certified
# each firmware against (the limits in test/<name>.ml), with the same sheet; where the spec
# gives no tolerance, the firmware's nominal to a stated fraction.


def difference(n, m, rate):
    """Returns where n samples less m samples lies, in seconds, as span() does."""
    return span(n, rate)[0] - span(m, rate)[1], span(n, rate)[1] - span(m, rate)[0]


def nearest(sorted_at, sample, within):
    """Returns the entry of sorted_at nearest sample if it is within `within`, else sample."""
    near = [a for a in (before(sorted_at, sample + 1), after(sorted_at, sample)) if a is not None]
    best = min(near, key=lambda a: abs(a - sample), default=None)
    return best if best is not None and abs(best - sample) <= within else sample


DALI = "DALI, Wikipedia, Digital Addressable Lighting Interface, oldid 1363488623 p.1, line %d"
DALI_HALF = 20000 / 48e6
DALI_RATE = ("1200 bit/s, Wikipedia's DALI page (oldid 1363488623, line 157), to Dali.read's 5% "
             "(the page gives no tolerance)")


def dali(line):
    def frames(samples, rate):
        """Returns each frame's runs from its start bit's fall, and the high after it (None if
        the capture ends first). The line's first high is its rise from reset."""
        found = runs(samples, line)
        start = next(i for i, (level, _, _) in enumerate(found) if level) + 1
        out, frame = [], []
        for run in found[start:]:
            if run[0] and run[2] > 2.5 * DALI_HALF * rate:
                out.append((frame, run))
                frame = []
            else:
                frame.append(run)
        return out + [(frame, None)] if frame else out

    def timing(samples, rate, _capture, _decode, _log):
        half = DALI_HALF * rate
        n = {1: [], 2: []}
        idle = []
        for frame, high in frames(samples, rate):
            for _, _, w in frame:
                n.setdefault(round(w / half), []).append(span(w, rate))
            # a last bit of 1 ends high into the idle, so take a half (the start bit's low) off it
            odd = sum(round(w / half) for _, _, w in frame) % 2
            start = frame[0][2] if odd else 0
            if high:
                idle.append(difference(high[2], start, rate))
            elif samples[-1] >> line & 1:
                at = frame[-1][1] + frame[-1][2]
                idle.append((difference(len(samples) - at, start, rate)[0], math.inf))
        records = []
        for k in sorted(n):
            name = "1 half bit" if k == 1 else "%d half bits" % k
            records += [bound(name, DALI_RATE, n[k], at_least=0.95 * k * DALI_HALF, source="own"),
                        bound(name, DALI_RATE, n[k], at_most=1.05 * k * DALI_HALF, source="own")]
        return records + [bound("idle after a frame", DALI % 178, idle, at_least=2.45e-3)]

    def byte_tooth(samples, rate, _capture, _decode):
        """Swaps the halves of the forward frame's opcode MSB, 18 half bits in, so the opcode
        reads 0x20."""
        frame, _ = frames(samples, rate)[0]
        at = edges(samples, line)[0]
        half = DALI_HALF * rate
        first, last = (nearest(at, round(frame[0][1] + k * half), half / 4) for k in (18, 20))
        return changed(samples, line, first, last), "the forward frame's opcode MSB inverted"

    def edge_tooth(samples, rate):
        """Moves the start bit's middle edge 50 us late."""
        frame, _ = frames(samples, rate)[0]
        at = frame[0][1] + frame[0][2]
        return (moved(samples, line, at, at + round(50e-6 * rate)),
                "the forward frame's start bit edge 50 us late", "1 half bit")

    return timing, byte_tooth, edge_tooth


DMX = "DMX512, Wikipedia, DMX512, oldid 1380777110 page 1, %s"
DMX_BIT = 192 / 48e6


def dmx512(line):
    def breaks(samples, rate):
        """Returns the line's runs and the index of each break, a low of more than ten bits."""
        found = runs(samples, line)
        return found, [i for i, (level, _, n) in enumerate(found)
                       if not level and n > 10 * DMX_BIT * rate]

    def timing(samples, rate, _capture, _decode, _log):
        found, at = breaks(samples, rate)
        bit = DMX_BIT * rate
        # a low is a start bit and any zeros after it, so whole bits
        per_bit = [tuple(x / round(n / bit) for x in span(n, rate))
                   for level, _, n in found if not level and n <= 10 * bit]
        brk = [span(found[i][2], rate) for i in at]
        mab = [span(found[i + 1][2], rate) for i in at if i + 1 < len(found)]
        apart = [span(found[j][1] - found[i][1], rate) for i, j in zip(at, at[1:])]
        exact = DMX % "line 291, no tolerance"
        fraction = ("192 cycles at 48 MHz, the firmware's bit, to half a bit over nine "
                    "(Wikipedia's DMX512 page gives 250 kbit/s no tolerance)")
        return [bound("bit at 250 kbit/s, a low per bit", exact, per_bit, at_least=4e-6),
                bound("bit at 250 kbit/s, a low per bit", exact, per_bit, at_most=4e-6),
                bound("bit, a low per bit", fraction, per_bit, at_least=(1 - 1 / 18) * DMX_BIT,
                      source="own"),
                bound("bit, a low per bit", fraction, per_bit, at_most=(1 + 1 / 18) * DMX_BIT,
                      source="own"),
                bound("BREAK transmitted", DMX % "table, lines 303-306", brk, at_least=92e-6),
                bound("BREAK receiver recognized", DMX % "table, lines 303, 308-309", brk,
                      at_least=88e-6),
                bound("MAB transmitted", DMX % "table, lines 304-305, 307", mab, at_least=12e-6),
                bound("MAB receiver recognized", DMX % "table, lines 304, 308, 310", mab,
                      at_least=8e-6),
                bound("MAB since 1990", DMX % "line 301", mab, at_least=8e-6),
                bound("break to break transmitted", DMX % "line 313", apart, at_least=1204e-6),
                bound("break to break receivers handle", DMX % "line 313", apart,
                      at_least=1196e-6),
                bound("refresh rate of 512 channels, at most 44 Hz", DMX % "line 312", apart,
                      at_least=1 / 44)]

    def byte_tooth(samples, rate, _capture, _decode):
        """Inverts the second packet's channel 1 bit 0 at its middle. The first packet reads
        misframed, from the line's low from reset."""
        found, at = breaks(samples, rate)
        # the break, MAB, the start code's low and high, then channel 1's start bit
        fall, bit = found[at[1] + 4][1], DMX_BIT * rate
        return (changed(samples, line, round(fall + 1.25 * bit), round(fall + 1.75 * bit)),
                "half of the second packet's channel 1 bit 0 inverted")

    def edge_tooth(samples, rate):
        """Ends the first break 10 us early."""
        found, at = breaks(samples, rate)
        _, first, n = found[at[0]]
        return (moved(samples, line, first + n, first + n - round(10e-6 * rate)),
                "the first break 10 us short", "BREAK transmitted")

    return timing, byte_tooth, edge_tooth


SPDIF = "S/PDIF, IEC 60958 type II, Wikipedia, S/PDIF, revision 1378032122 p.1, %s"
SPDIF_HALF = (8 + 32991 / 65536) / 48e6
SPDIF_CELL = ("8 32991/65536 cycles at 48 MHz, the firmware's half slot, to half of it "
              "(the page gives no tolerance)")


def spdif(line):
    def subframes(samples, rate):
        """Returns the line's runs, the index of the first preamble's, and each subframe's
        start with whether it starts a frame. A preamble opens with three half slots low, which
        biphase mark never holds, then one or three high for B or M, two for W."""
        found = runs(samples, line)
        half = SPDIF_HALF * rate
        at = [i for i, (level, _, n) in enumerate(found[:-1]) if not level and n > 2.5 * half]
        return found, at[0], [(found[i][1], round(found[i + 1][2] / half) != 2) for i in at]

    def timing(samples, rate, _capture, _decode, _log):
        found, first, starts = subframes(samples, rate)
        half = SPDIF_HALF * rate
        n = {}
        for _, _, w in found[first:]:
            n.setdefault(max(1, round(w / half)), []).append(span(w, rate))
        frames = [s for s, b in starts if b]
        each = [span(b - a, rate) for a, b in zip(frames, frames[1:])]
        # the capture holds fewer than a block's 192, so the block is 192 of their mean
        block = [tuple(192 * x / (len(frames) - 1) for x in span(frames[-1] - frames[0], rate))]
        records = []
        for k in sorted(n):
            name = "%d half slot%s" % (k, "" if k == 1 else "s")
            records += [bound(name, SPDIF_CELL, n[k], at_least=(k - 0.5) * SPDIF_HALF,
                              source="own"),
                        bound(name, SPDIF_CELL, n[k], at_most=(k + 0.5) * SPDIF_HALF,
                              source="own")]
        byte_3 = SPDIF % "S/PDIF control word components, byte 3, spec.txt l.222-224"
        return records + [
            bound("a block of 192 frames, 44.1 kHz and 1100 ppm", byte_3, block,
                  at_least=192 / 44100 * (1 - 1100e-6), source="derived"),
            bound("a block of 192 frames, 44.1 kHz less 1100 ppm", byte_3, block,
                  at_most=192 / 44100 * (1 + 1100e-6), source="derived"),
            bound("a frame, Mode 0's 192 kHz at most", SPDIF % "text, spec.txt l.180", each,
                  at_least=1 / 192e3)]

    def byte_tooth(samples, rate, _capture, _decode):
        """Removes the middle edges of slots 14 and 15 in the first right subframe, sigrok's
        first, which turns the sample's bits 2 and 3 (both 1) to 0 and keeps the parity."""
        _, _, starts = subframes(samples, rate)
        at, half = edges(samples, line)[0], SPDIF_HALF * rate
        start = starts[1][0]
        first, last = (nearest(at, round(start + (2 * slot + 1) * half), half / 2)
                       for slot in (14, 15))
        return changed(samples, line, first, last), "the first right sample's bits 2 and 3 cleared"

    def edge_tooth(samples, rate):
        """Cuts the first one-half-slot run after the first preamble's low to a sample."""
        found, first, _ = subframes(samples, rate)
        half = SPDIF_HALF * rate
        _, at, n = next(r for r in found[first + 1:] if round(r[2] / half) == 1)
        return (moved(samples, line, at + n, at + 1), "the first half slot cut to a sample",
                "1 half slot")

    return timing, byte_tooth, edge_tooth


def spdif_problems(capture, _decoded, log):
    """sigrok's spdif reads nothing past a line low from reset, so this judges its decode
    from the firmware's idle high on, as demo/traffic.py does."""
    rate, _, samples = sigrok.read(capture)
    joined = traffic.joined("spdif", rate, samples)
    return traffic.judge("spdif", traffic.lines("spdif", samples),
                         joined.splitlines() if joined else [], log)


def spdif_ac3(line):
    timing, _, edge_tooth = spdif(line)

    def byte_tooth(samples, rate, _capture, _decode):
        """Removes the middle edges of slots 16 and 17 in the subframe with the burst's
        first word, which turns its bits 4 and 5 (both 1) to 0 and keeps the parity."""
        start = next(at for at, word in ffmpeg_referee.subframes(samples, rate)
                     if word == demo_spdif_ac3.BURST[0])
        at, half = edges(samples, line)[0], SPDIF_HALF * rate
        first, last = (nearest(at, round(start + (2 * slot + 1) * half), half / 2)
                       for slot in (16, 17))
        return changed(samples, line, first, last), "the burst's first word's bits 4 and 5 cleared"

    return timing, byte_tooth, edge_tooth


def spdif_ac3_problems(capture, _decoded, log):
    """Judges the words demo/traffic.py reads by run length, as it does."""
    rate, _, samples = sigrok.read(capture)
    return traffic.judge("spdif_ac3", traffic.lines("spdif_ac3", samples),
                         traffic.own("spdif_ac3", rate, samples), log)


PD = "USB PD BMC transmitter, USB Power Delivery Specification r3.2 v1.2, Aug 2026 %s"


def usb_power_delivery(line):
    def packets(samples, rate):
        """Returns each packet's bit cells as (first sample, samples), as test/
        usb_power_delivery.ml cuts them: a level under 2.5 us is a half and pairs with the
        next, a longer one is a cell, and a low past 5 us is idle."""
        found = runs(samples, line)

        def idle(run):
            return not run[0] and run[2] > 5e-6 * rate

        out, cells, i = [], [], 0
        while i < len(found):
            if idle(found[i]):
                if cells:
                    out.append(cells)
                cells, i = [], i + 1
            elif (found[i][2] < 2.5e-6 * rate and i + 1 < len(found)
                  and not idle(found[i + 1])):
                cells.append((found[i][1], found[i][2] + found[i + 1][2]))
                i += 2
            else:
                cells.append(found[i][1:])
                i += 1
        return out + [cells] if cells else out

    def timing(samples, rate, _capture, _decode, _log):
        found = packets(samples, rate)
        cells = [span(n, rate) for cells in found for _, n in cells]
        # each 32 cells from the preamble's last on, against the preamble's last 32
        drift = []
        for packet in found:
            widths = [n for _, n in packet]
            reference = sum(widths[32:64])
            for last in range(64, len(widths)):
                d = abs(sum(widths[last - 31:last + 1]) - reference)
                drift.append((max(0, d - 2) / rate * (1 - PPM), (d + 2) / rate * (1 + PPM)))
        lows = [r for r in runs(samples, line) if not r[0]]
        gaps = [span(n, rate) for _, _, n in lows if n > 5e-6 * rate]
        # the idle lows cut by the capture's ends
        at, _ = sigrok.edges(samples, line)
        if len(at) and not samples[0] >> line & 1:
            gaps.append((span(int(at[0]), rate)[0], math.inf))
        if len(at) and not samples[-1] >> line & 1:
            gaps.append((span(len(samples) - int(at[-1]), rate)[0], math.inf))
        table_9, table_10 = PD % "Table 5.9, p.110", PD % "Table 5.10, p.110"
        return [bound("fBitRate max 330 kbps: each bit cell", table_9, cells, at_least=1 / 330e3),
                bound("fBitRate min 270 kbps: each bit cell", table_9, cells, at_most=1 / 270e3),
                bound("tUnitInterval min", table_9, cells, at_least=3030e-9),
                bound("tUnitInterval max", table_9, cells, at_most=3700e-9),
                bound("pBitRate 0.25 %: 32 bits against the preamble's last 32, of 32 UI at "
                      "300 kbps", PD % "Table 5.10, p.110, and 5.3.4.8 p.108; 300 kbps "
                      "nominal, Table 5.9", drift, at_most=0.0025 * 32 / 300e3),
                bound("tHoldLowBMC: every low", table_10, [span(n, rate) for _, _, n in lows],
                      at_least=1000e-9),
                bound("tInterFrameGap: each idle low", table_10, gaps, at_least=25e-6)]

    def byte_tooth(samples, rate, _capture, _decode):
        """Inverts the middle half of line bit 22 after the preamble, in the header, as
        test/usb_power_delivery.ml's first tooth does."""
        first, n = packets(samples, rate)[0][64 + 22]
        return (changed(samples, line, first + round(n / 4), first + round(3 * n / 4)),
                "a stray half bit in the header")

    def edge_tooth(samples, rate):
        """Cuts the packet's first half-bit low to 0.8 us."""
        _, first, n = next(r for r in runs(samples, line)
                           if not r[0] and r[2] < 2.5e-6 * rate)
        return (moved(samples, line, first + n, first + round(0.8e-6 * rate)),
                "the first half-bit low cut to 0.8 us", "tHoldLowBMC: every low")

    return timing, byte_tooth, edge_tooth


WIEGAND = "Wikipedia, Wiegand interface, oldid 1374164469, page 1, lines 91 and 94"
WIEGAND_PULSE = 2400 / 48e6


def wiegand(d0, d1):
    def pulses(samples):
        """Returns each pulse on either line as (first sample, samples, its bit), in order."""
        return sorted((f, n, b) for b in (d0, d1) for level, f, n in runs(samples, b)
                      if not level)

    def timing(samples, rate, _capture, _decode, _log):
        found = pulses(samples)
        levels = np.frombuffer(samples, np.uint8)
        # the bench sends one read
        apart = [span(b[0] - a[0], rate) for a, b in zip(found, found[1:])]
        low = [1 + bool(np.any((levels[f:f + n] >> (d1 if b == d0 else d0) & 1) == 0))
               for f, n, b in found]
        width = ("2400 cycles at 48 MHz, the firmware's pulse, to half of it (the page gives "
                 "no timing)")
        interval = ("10 pulses, the firmware's interval, to half a pulse (the page gives no "
                    "timing)")
        return [bound("pulse", width, [span(n, rate) for _, n, _ in found],
                      at_least=0.5 * WIEGAND_PULSE, source="own"),
                bound("pulse", width, [span(n, rate) for _, n, _ in found],
                      at_most=1.5 * WIEGAND_PULSE, source="own"),
                bound("pulse to pulse", interval, apart, at_least=9.5 * WIEGAND_PULSE,
                      source="own"),
                bound("pulse to pulse", interval, apart, at_most=10.5 * WIEGAND_PULSE,
                      source="own"),
                bound("pulse to pulse", "sigrok's wiegand, bitwidth_ms=1: past it the read "
                      "ends", apart, at_most=1e-3, source="decoder"),
                count("lines low at once", WIEGAND, low, at_most=1, unit="lines")]

    def byte_tooth(samples, _rate, _capture, _decode):
        """Moves the first pulse, a 0, from DATA0 to DATA1."""
        f, n, _ = pulses(samples)[0]
        return (changed(changed(samples, d0, f, f + n, 1), d1, f, f + n, 0),
                "the first pulse moved from DATA0 to DATA1")

    def edge_tooth(samples, rate):
        """Ends the first pulse 30 us late."""
        f, n, b = pulses(samples)[0]
        return (moved(samples, b, f + n, f + n + round(30e-6 * rate)),
                "the first pulse 30 us long", "pulse")

    return timing, byte_tooth, edge_tooth


IR_NEC = "NEC infrared remote, SB-Projects, NEC Protocol, updated 17 July 2025 page 1, line %d"


def ir_nec(line):
    def messages(samples, rate):
        """Returns each AGC burst, 4 ms or more, with the bursts after it up to the next, as
        test/ir_nec.ml cuts them. A burst is (rise, fall, its pulses' rises); a low of two
        carrier periods ends one."""
        bursts = []
        for level, f, n in runs(samples, line):
            if not level:
                continue
            if bursts and f - bursts[-1][1] < 2 / 38e3 * rate:
                bursts[-1][1] = f + n
                bursts[-1][2].append(f)
            else:
                bursts.append([f, f + n, [f]])
        out = []
        for b in bursts:
            if b[1] - b[0] >= 4e-3 * rate:
                out.append((b, []))
            elif out:
                out[-1][1].append(b)
        return out

    def timing(samples, rate, _capture, _decode, _log):
        found = messages(samples, rate)
        frames = [m for m in found if len(m[1]) > 1]
        repeats = [m for m in found if len(m[1]) == 1]

        def widths(xs):
            return [span(x, rate) for x in xs]

        def length(b):
            return b[1] - b[0]

        bits = [b[0] - a[0] for _, rest in frames for a, b in zip(rest, rest[1:])]
        one = 1.6875e-3 * rate
        windows = [
            ("Carrier frequency, as its period", 17, 1 / 38e3,
             [b - a for agc, rest in found for x in [agc] + rest for a, b in zip(x[2], x[2][1:])]),
            ("Bit time, logical 0", 18, 1.125e-3, [x for x in bits if x < one]),
            ("Bit time, logical 1", 18, 2.25e-3, [x for x in bits if x >= one]),
            ("Carrier burst length", 21, 560e-6, [length(b) for _, rest in found for b in rest]),
            ("AGC burst, message start", 28, 9e-3, [length(agc) for agc, _ in frames]),
            ("Space after AGC burst, message start", 29, 4.5e-3,
             [rest[0][0] - agc[1] for agc, rest in frames]),
            ("Extra burst at end of message", 34, 560e-6, [length(rest[-1]) for _, rest in frames]),
            ("AGC pulse, repeat code", 37, 9e-3, [length(agc) for agc, _ in repeats]),
            ("Space after AGC pulse, repeat code", 37, 2.25e-3,
             [rest[0][0] - agc[1] for agc, rest in repeats]),
            ("Burst, repeat code", 37, 560e-6, [length(rest[0]) for _, rest in repeats])]
        return [bound(p, IR_NEC % at, widths(xs), at_least=least) for p, at, least, xs in windows]

    def byte_tooth(samples, rate, _capture, _decode):
        """Swaps the first command's bits 0 and 1 (a zero then a one) by moving bit 1's burst
        to where a one's would end, so the command reads 0x15."""
        _, rest = messages(samples, rate)[0]
        (a, _, _), (b, end, _), (c, _, _) = rest[16:19]
        mask = np.uint8(1 << line)
        out = np.frombuffer(samples, np.uint8).copy()
        burst = out[b:end] & mask
        out[b:end] &= ~mask
        to = c - (b - a)
        out[to:to + end - b] = (out[to:to + end - b] & ~mask) | burst
        return out.tobytes(), "the first command's bits 0 and 1 swapped"

    def edge_tooth(samples, rate):
        """Ends the first AGC burst 1 ms early."""
        (_, fall, _), _ = messages(samples, rate)[0]
        return (moved(samples, line, fall, fall - round(1e-3 * rate)),
                "the first AGC burst 1 ms short", "AGC burst, message start")

    return timing, byte_tooth, edge_tooth


LIN = "LIN master, LIN Specification Package Revision 2.2A %s"
LIN_BIT = 1 / 19200


def lin(line):
    def headers(samples, rate):
        """Returns the line's runs from each break on, a low of 11 bits or more."""
        found = runs(samples, line)
        return [found[i:] for i, (level, _, n) in enumerate(found)
                if not level and n >= 11 * LIN_BIT * rate]

    def timing(samples, rate, _capture, _decode, _log):
        n = {k: [] for k in ["break", "delimiter", "field", "header", "bits"]}
        for header in headers(samples, rate):
            n["break"].append(span(header[0][2], rate))
            n["delimiter"].append(span(header[1][2], rate))
            n["field"].append(span(header[2][1] - header[0][1], rate))
            # the PID's stop bit ends ten bits after its start bit's fall
            falls = [f for level, f, _ in header if not level]
            lo, hi = span(falls[6] - header[0][1], rate)
            n["header"].append((lo + 10 * LIN_BIT, hi + 10 * LIN_BIT))
            # from after the delimiter, which a slow rise can bring under a bit and a half
            n["bits"] += [span(w, rate) for _, _, w in header[2:] if w < 1.5 * LIN_BIT * rate]
        field, table = LIN % "2.3.1.1, p. 30", LIN % "Table 6.1, p. 113"
        return [bound("break field", field, n["break"], at_least=13 * LIN_BIT),
                bound("break delimiter", field, n["delimiter"], at_least=LIN_BIT),
                bound("break field length (dominant + delimiter)", LIN % "Table 2.3, p. 52",
                      n["field"], at_least=14 * LIN_BIT),
                bound("THeader_Maximum, 1.4 * THeader_Nominal of 34 TBit",
                      LIN % "2.3.2 eq. (3), p. 32, eq. (6), p. 33", n["header"],
                      at_most=1.4 * 34 * LIN_BIT),
                bound("FTOL_RES_MASTER, bit", table, n["bits"], at_least=0.995 * LIN_BIT),
                bound("FTOL_RES_MASTER, bit", table, n["bits"], at_most=1.005 * LIN_BIT),
                bound("bit rate, 20 kbit/s", LIN % "6.3, p. 112", n["bits"], at_least=50e-6),
                bound("bit rate, 1 kbit/s", LIN % "6.3, p. 112", n["bits"], at_most=1e-3)]

    def byte_tooth(samples, rate, _capture, _decode):
        """Inverts half of the PID's bit 0 at its middle."""
        header = headers(samples, rate)[0]
        fall, bit = [f for level, f, _ in header if not level][6], LIN_BIT * rate
        return (changed(samples, line, round(fall + 1.25 * bit), round(fall + 1.75 * bit)),
                "half of the PID's bit 0 inverted")

    def edge_tooth(samples, rate):
        """Ends the first break 30 us early."""
        _, first, n = headers(samples, rate)[0][0]
        return (moved(samples, line, first + n, first + n - round(30e-6 * rate)),
                "the break 30 us short", "break field")

    return timing, byte_tooth, edge_tooth


ADI = "SW-DP, ARM IHI 0031C ADIv5.0 to ADIv5.2, ID080813 %s"


def swd_blind(swclk, swdio):
    def resets(samples):
        """Returns SWDIO's high runs that span more SWCLK rises than a read nobody answers,
        each with its first sample, its rises and the run after it."""
        rises = [a for a, t in zip(*edges(samples, swclk)) if t]
        found = runs(samples, swdio)
        out = []
        for i, (level, first, n) in enumerate(found):
            clocks = [r for r in rises if first <= r < first + n]
            if level and len(clocks) > 39 and i + 1 < len(found):
                _, f, m = found[i + 1]
                out.append((first, clocks, [r for r in rises if f <= r < f + m]))
        return out

    def timing(samples, rate, _capture, _decode, _log):
        found = runs(samples, swclk)
        half = ("24 cycles at 48 MHz, the firmware's half period, to half of it (IHI 0031C "
                "gives no times, p.4-94)")
        return [bound("SWCLK high", half, [span(n, rate) for level, _, n in found if level],
                      at_least=0.5 * 24 / 48e6, source="own"),
                bound("SWCLK low", half, [span(n, rate) for level, _, n in found if not level],
                      at_least=0.5 * 24 / 48e6, source="own"),
                count("line reset", ADI % "4.4.3, p.4-104",
                      [len(clocks) for _, clocks, _ in resets(samples)], at_least=50,
                      unit="cycles"),
                count("idle cycles", ADI % "4.4.3, p.4-104",
                      [len(idle) for _, _, idle in resets(samples)], at_least=2, unit="cycles")]

    def byte_tooth(samples, _rate, capture, decode):
        """Inverts SWDIO over one bit of the DPIDR the RP2040 answers."""
        first, last, _ = next(a for a in annotations(capture, decode, "swd")
                              if a[2] == "swd-1: 0x0bc12477")
        falls = [a for a, t in zip(*edges(samples, swclk)) if not t and first <= a <= last]
        return (changed(samples, swdio, falls[3] + 2, falls[4] + 2),
                "SWDIO inverted over a bit of the DPIDR")

    def edge_tooth(samples, _rate):
        """Moves the line reset's SWDIO rise 10 SWCLK rises later."""
        first, clocks, _ = resets(samples)[0]
        return (moved(samples, swdio, first, clocks[10] - 3),
                "the line reset's rise 10 cycles late", "line reset")

    return timing, byte_tooth, edge_tooth


@dataclass(frozen=True)
class Demo:
    # sigrok arguments from demo/outside.sh, or from demo/ledger.py
    decode: str
    analyser: str
    channels: dict
    # what the chip runs: names from python/bench_firmware.py, or test/ files
    firmware: tuple
    # what Pico A runs
    scripts: tuple
    peer: str
    protocol: tuple
    limits: tuple = ()
    # the run's file names (the demo's, unless given)
    stem: str = ""
    # what the capture, sigrok's decode and Pico A's log lack of the demo's bytes (from
    # demo/traffic.py, unless given)
    judge: object = None
    # files kept alongside KEPT's, and what is wrong with the first of them, judged from its
    # text and Pico A's log
    also: tuple = ()
    also_problems: object = None
    # what a run that passes on only part of the protocol leaves out
    partial: str = ""

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
    """Returns the sigrok arguments on python/demo_<name>.py's "# outside:" line."""
    for line in (ROOT / "python" / ("demo_%s.py" % name)).read_text().splitlines():
        if line.startswith("# outside: "):
            return line.split("decode=", 1)[1]
    raise ValueError("python/demo_%s.py has no outside: line" % name)


DRAWN = ("drawn at random and written blind from its spec (docs/flexibility.md)",)
HELD_OUT = ("sealed on the held-out list and written blind from its spec "
            "(docs/flexibility.md)",)


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
    "dali": Demo(outside("dali"), "A", {"D4": "OUT0, high when idle"}, ("DALI",),
                 ("python/demo_dali.py",), "nothing, Pico B idle on OUT0", dali(4),
                 HELD_OUT + ("the page gives the rate no tolerance, so the half bits are held "
                             "to 1200 bit/s within Dali.read's 5%",
                             "one forward frame, so forward frames 25 ms apart (line 188) has "
                             "nothing to hold")),
    "dmx512": Demo(outside("dmx512"), "A", {"D4": "OUT0"}, ("DMX512",),
                   ("python/demo_dmx512.py",), "nothing, Pico B idle on OUT0", dmx512(4),
                   HELD_OUT + ("the page gives 250 kbit/s no tolerance, which a sample either "
                               "way can't settle, so each low is also held to the firmware's "
                               "bit within half a bit over nine",
                               "the first packet reads misframed, as the line is low from "
                               "reset, so the bytes are the second's"),
                   partial="without the first packet: the line's low from reset misframes it"),
    "spdif": Demo(outside("spdif"), "A", {"D4": "OUT0"}, ("SPDIF",), ("python/demo_spdif.py",),
                  "nothing, Pico B idle on OUT0", spdif(4),
                  HELD_OUT + ("sigrok's spdif reads nothing past the line's low from reset, so "
                              "the samples are judged from its decode once the line idles high",
                              "the capture holds fewer frames than a 192-frame block, so the "
                              "block's windows hold 192 times their mean",
                              "a half slot is about four samples, so its windows can stay "
                              "unresolved"),
                  judge=spdif_problems,
                  partial="without the frames before the line first idles high: sigrok's "
                          "spdif reads nothing past the low from reset"),
    "spdif_ac3": Demo(outside("spdif_ac3"), "A", {"D4": "OUT0"}, ("SPDIF",),
                      ("python/demo_spdif_ac3.py",), "nothing, Pico B idle on OUT0",
                      spdif_ac3(4),
                      ("our own demo on the held-out S/PDIF firmware, not a drawn or sealed "
                       "protocol, sending one AC-3 frame in an IEC 61937 burst that FFmpeg made",
                       "sigrok's spdif reads nothing past the line's low from reset and "
                       "misreads the burst when started after it, so its decode is not judged",
                       "demo/ffmpeg_referee.py reads the words by run length, and FFmpeg's "
                       "spdif demuxer must find the frame sent in them",
                       "FFmpeg holds the frame's bytes, not the line code",
                       "the capture holds fewer frames than a 192-frame block, so the "
                       "block's windows hold 192 times their mean",
                       "a half slot is about four samples, so its windows can stay "
                       "unresolved"),
                      judge=spdif_ac3_problems),
    "usb_power_delivery": Demo(outside("usb_power_delivery"), "A",
                               {"D4": "OUT0, the BMC level, low when idle"},
                               ("USB_POWER_DELIVERY",), ("python/demo_usb_power_delivery.py",),
                               "nothing, Pico B idle on OUT0", usb_power_delivery(4),
                               HELD_OUT + ("OUT0 has no third state, so tStartDrive, "
                                           "tEndDriveBMC and the slew are not held",
                                           "the idle lows run to the capture's ends, so "
                                           "tInterFrameGap holds only their least")),
    "wiegand": Demo(outside("wiegand"), "A",
                    {"D4": "DATA0, OUT0", "D5": "DATA1, OUT1 through CAN board A's R"},
                    ("WIEGAND",), ("python/demo_wiegand.py",),
                    "Pico B as a CAN node holding the bus recessive, so CAN board A's R "
                    "follows OUT1", wiegand(4, 5),
                    HELD_OUT + ("the page gives no timing, so the pulse windows are the "
                                "firmware's and sigrok's, not a spec's",
                                "D5's edges carry the SN65HVD230's delay")),
    "ir_nec": Demo(outside("ir_nec"), "A", {"D4": "OUT0, high for the carrier's on third"},
                   ("IR_NEC",), ("python/demo_ir_nec.py",), "nothing, Pico B idle on OUT0",
                   ir_nec(4),
                   HELD_OUT + ("the page gives nominal times only, held as least times, as "
                               "the kernel holds them",)),
    "lin": Demo(outside("lin"), "A", {"D7": "LIN, IO5, open drain, 4k7 pull-up"}, ("LIN",),
                ("python/demo_lin.py",), "nothing: no slave answers the header", lin(7),
                HELD_OUT + ("IO5 is open drain, so at the analyser's threshold a low reads a "
                            "little long and a high as much short",
                            "THeader_Maximum adds the PID's ten nominal bits to the break's "
                            "fall to the PID's, as test/lin.ml does"),
                partial="without the response: no slave on the bench answers the header"),
    "swd_blind": Demo(outside("swd_blind"), "A",
                      {"D6": "SWCLK, OUT2", "D7": "SWDIO, IO5, 4k7 pull-up"}, ("SWD_BLIND",),
                      ("python/demo_swd_blind.py",), "Pico B's RP2040 as the SWD target",
                      swd_blind(6, 7),
                      HELD_OUT + ("sigrok misreads the dormant wake and TARGETSEL, so only the "
                                  "DPIDR read is held to the bytes",
                                  "Trn is SWDIO's direction, which the analyser can't see",
                                  "the demo's one line reset ends dormant to SWD; it has no "
                                  "JTAG-to-SWD, SWD-to-DS or JTAG-to-DS")),
    "self_timing": Demo("-P uart:rx=D4:baudrate=9600 -A uart=rx-data", "A",
                        {"D4": "OUT0, engine 1's echo of wire 20"},
                        ("test/uart_tx_host_rate.hex", "test/edge_logger_echo.hex"),
                        ("python/demo_self_timing.py",),
                        "Pico B listening on OUT0", uart(4, 9600, 48e6),
                        ("the echo's delay is the same for every edge, so only offsets from "
                         "each start bit are compared",)),
}


def pc_keys(text, log):
    """Compares the keys the pc's kernel received (as demo/keys.py grabbed them from the
    desktop) with the keys Pico A typed."""
    took, typed = keys.taken(text), traffic.typed(log)
    if not took or not re.search(r"^grab ", text, re.M):
        return ["demo/keys.py grabbed no keyboard"]
    return [] if took == typed else ["the pc took %r, Pico A typed %r" % (took, typed)]


DEMOS["keyboard"] = Demo(
    "-P uart:rx=D4:baudrate=115200 -A uart=rx-data", "A",
    {"D4": "OUT0, engine 1's byte for each key the pc took"},
    ("python/usb_device_firmware.py", "test/uart_tx_host_rate.hex"),
    ("python/demo_usb.py", "python/usb_board.py"),
    "the pc as the USB host at low speed, its input devices for the chip grabbed by "
    "demo/keys.py", uart(4, 115200, 48e6, logged=False),
    ("at 2 MS/s a bit is 17 samples, so a window over one bit is unresolved, not passed",
     "the pc's keys are the kernel's input events, as demo/keys.py read them under its grab"),
    also=("keyboard.keys",), also_problems=pc_keys)
LIMITS = (
    "one run of one board, the ECP5 build of the chip's RTL, not the ASIC",
    "the run's files are the bench's own record, tied together by SHA256SUMS, and CI "
    "derives the decode and the timing from the capture alone",
    "each edge is known to a sample either way and the analyser's crystal to 100 ppm, and a "
    "window the capture cannot settle is unresolved, not passed",
)


@dataclass(frozen=True)
class LogDemo:
    # what the chip runs (test/ files), and what Pico A runs
    firmware: tuple
    scripts: tuple
    peer: str
    # the run's tally and problems from its directory, and its teeth
    judge: object
    teeth: object
    # what a PASS line says of the tally
    says: object
    limits: tuple = ()
    # the run's files besides ledger.txt and run.txt, the first named in witness.json
    kept: tuple = ("{}.log",)
    clock: str = "48 MHz"


def text(directory, name):
    return (Path(directory) / name).read_text(errors="replace")


def recorded(text):
    """Returns a sha256sum listing the run wrote itself, by each file's base name."""
    return {Path(name.lstrip("*")).name: sha for sha, name in
            (line.split(maxsplit=1) for line in text.splitlines())}


def kvb_run(directory):
    """Returns what the kernel-vs-board judge reads of the run in directory."""
    logged = {}
    for line in text(directory, "board.log").splitlines():
        if result := kernel_vs_board.parse(line):
            logged[(result["firmware"], result["k"])] = result
    return {
        "variants": kernel_vs_board.read_verdicts(text(directory, "verdicts.tsv")),
        "rows": [json.loads(line) for line in text(directory, "results.jsonl").splitlines()],
        "logged": logged,
        "summary": text(directory, "summary.txt"),
        "runs": text(directory, "run.txt"),
        "outs": text(directory, "kvb-small.out") + text(directory, "kvb-big.out"),
        "inputs": recorded(text(directory, "SHA256SUMS.inputs")),
        "fields": ledger_fields(directory),
    }


# outcomes the run must not have, as demo/kernel_vs_board.py words them
KVB_BAD = ("UNSOUND", "BUG", "MISMATCH", "inconclusive")


def kvb_judge(run):
    """Scores every row again against the variant it ran, as demo/kernel_vs_board.py did,
    and holds the run's own records to the ledger's commit and bitstream."""
    variants = {(v["firmware"], v["k"]): v for v in run["variants"]}
    bitstream, commit = run["fields"]["bitstream_sha256"], run["fields"]["commit"]
    verdicts, problems, outcomes = [], [], {}
    for row in run["rows"]:
        key = (row["firmware"], row["k"])
        name = "%s k=%d" % key
        if key not in variants:
            problems.append("%s is not a variant" % name)
            continue
        v = variants[key]
        outcome = kernel_vs_board.chip_outcome(v, row)
        outcomes[outcome] = outcomes.get(outcome, 0) + 1
        if outcome.startswith(KVB_BAD):
            verdicts.append("%s: %s" % (name, outcome))
        model = re.match(r"refused: pc (\d+)", v["chip_model"])
        if row["board"] == "refused" and model and row["chip_pc"] != int(model[1]):
            verdicts.append("%s: the chip refused at pc %d, its model at pc %s" % (
                name, row["chip_pc"], model[1]))
        if (row["chip"], row["accepted"], row["chip_model"], row["outcome"]) != (
                True, v["accepted"], v["chip_model"], outcome):
            problems.append("%s: results.jsonl's row is not what its variant and the board "
                            "make, %r" % (name, outcome))
        logged = run["logged"].get(key)
        if not logged or any(row.get(field) != value for field, value in logged.items()):
            problems.append("%s is not board.log's last RESULT line for it" % name)
    seen = [(row["firmware"], row["k"]) for row in run["rows"]]
    missing = [key for key in variants if key not in seen]
    if missing:
        problems.append("%s k=%d has no row" % missing[0] + (
            ", nor have %d more" % (len(missing) - 1) if len(missing) > 1 else ""))
    if len(seen) != len(set(seen)):
        problems.append("%d rows run a variant again" % (len(seen) - len(set(seen))))
    if kernel_vs_board.summary(run["variants"], run["rows"]) != run["summary"]:
        problems.append("summary.txt is not what the rows make")
    started = re.findall(r" sha256 (\w+) chip check (\w+), (\d+) variants", run["runs"])
    problems += ["run.txt names bitstream %s, not the ledger's" % sha
                 for sha, _, _ in started if sha != bitstream]
    if any(check != "on" for _, check, _ in started):
        problems.append("run.txt has a run with the chip's check off")
    if sum(int(n) for _, _, n in started) != len(variants):
        problems.append("run.txt's runs cover %d variants, not %d" % (
            sum(int(n) for _, _, n in started), len(variants)))
    said = re.findall(r"^\S+ (\w+) commit (\w+) (\w+) ", run["outs"], re.M)
    problems += ["kvb.sh ran %s at %s on %s, not the ledger's" % (name, at, sha)
                 for name, at, sha in said if (at, sha) != (commit, bitstream)]
    if {name for name, _, _ in said} != {v["firmware"] for v in run["variants"]}:
        problems.append("kvb.sh's output names other firmware than the variants'")
    if [sha for name, sha in run["inputs"].items() if name.endswith(".bit")] != [bitstream]:
        problems.append("SHA256SUMS.inputs names another bitstream than the ledger's")
    tally = {"variants": len(variants), "firmware": len({v["firmware"] for v in variants.values()}),
             "variants_sha256": run["inputs"].get("variants.jsonl", "not recorded"),
             "outcomes": dict(sorted(outcomes.items()))}
    return tally, verdicts + problems


def kvb_teeth(directory):
    """Each tooth changes what the board printed for one variant, in board.log and
    results.jsonl alike, or the run's record of its bitstream."""
    def bitten(what, change):
        run = kvb_run(directory)
        change(run)
        wrong = kvb_judge(run)[1]
        return what, wrong[0] if wrong else None

    def board(board, change):
        """Changes the first row the board printed `board` for, and its board.log line."""
        def apply(run):
            row = next(r for r in run["rows"] if r["board"] == board)
            for printed in (row, run["logged"][(row["firmware"], row["k"])]):
                change(printed)
        return apply

    def ran_on_time(printed):
        for field in ("chip_pc", "chip_reason", "stays_halted"):
            del printed[field]
        printed.update(board="ran", exact=10, within=0, out=0, fault0=0, fault1=0)

    def other_bitstream(run):
        run["runs"] = re.sub(r"sha256 \w+(?=[^\n]*\n$)", "sha256 " + "0" * 64, run["runs"])

    return [
        bitten("the first variant that ran printed with an edge out of its window",
               board("ran", lambda printed: printed.update(out=1))),
        bitten("the first refused variant printed as started anyway",
               board("refused", lambda printed: printed.update(stays_halted=False))),
        bitten("the first refused variant printed as run on time", board("refused", ran_on_time)),
        bitten("the first refused variant printed as refused a pc later",
               board("refused", lambda printed: printed.update(chip_pc=printed["chip_pc"] + 1))),
        bitten("the last row dropped", lambda run: run["rows"].pop()),
        bitten("run.txt's last run on another bitstream", other_bitstream),
    ]


def kvb_says(tally):
    return "%d variants of %d firmware on the chip's own check, %s" % (
        tally["variants"], tally["firmware"],
        ", ".join("%d %s" % (n, o) for o, n in tally["outcomes"].items()))


# fault_release's side-set pin and blink's set pin on analyser A
FAULT_OUT0, FAULT_OUT2 = 4, 6
# blink's longest level, set pins 0 [2] then jmp
BLINK_LEVEL = 5 / 48e6
# the script starts engine 0 again 10 ms after the push, well inside this
FAULT_LOW = 1.0
FAULT_SCRIPT = "python/demo_fault_release.py"


def fault_run(directory):
    rate, _, samples = sigrok.read(Path(directory) / "fault.sr")
    return {"rate": rate, "samples": samples, "log": text(directory, "fault.log"),
            "sums": recorded(text(directory, "SHA256SUMS.run")),
            "kept": {name: sha256((Path(directory) / name).read_bytes())
                     for name in ("fault.sr", "fault.log")},
            "fields": ledger_fields(directory)}


def words_of(script, name):
    """Returns the (words, certificate) the script assigns to name."""
    return tuple(map(list, ast.literal_eval(re.search(r"^%s = (.*)$" % name, script, re.M)[1])))


def hex_words(path):
    return [int(line, 16) for line in in_tree(path).decode().split()]


def fault_judge(run):
    """Engine 0 underflows, so OUT0 rises and falls once and stays low past the script's
    start after it. Engine 1's blink toggles OUT2 throughout, and the log has engine 0
    halted with the underflow at one pc through that start."""
    rate, samples, problems = run["rate"], run["samples"], []
    at, to = sigrok.edges(samples, FAULT_OUT0)
    if to.tolist() != [1, 0] or samples[0] >> FAULT_OUT0 & 1:
        problems.append("OUT0 has %d edges, not one rise and one fall" % len(at))
        rise = fall = len(samples)
    else:
        rise, fall = at.tolist()
    if (len(samples) - fall) / rate < FAULT_LOW:
        problems.append("OUT0 is low only %.3f s after its fall" % ((len(samples) - fall) / rate))
    blink, _ = sigrok.edges(samples, FAULT_OUT2)
    if not len(blink) or blink[0] > fall:
        problems.append("OUT2 toggles only after OUT0's fall")
    else:
        # the level after the last edge runs to the capture's end, so a stop there shows
        held = np.diff(np.append(blink, len(samples)))
        i = int(np.argmax(held))
        if span(int(held[i]), rate)[0] > BLINK_LEVEL:
            problems.append("OUT2 holds a level %.6f s from %.3f s, longer than blink's 5 "
                            "cycles" % (span(int(held[i]), rate)[0], blink[i] / rate))
    status = dict(re.findall(r"^(before|after|after a start|engine 1) 0x(\w+)", run["log"], re.M))
    pcs = dict(re.findall(r"^(after|after a start) 0x\w+ pc (\d+)", run["log"], re.M))
    if len(status) != 4 or len(pcs) != 2:
        problems.append("fault.log lacks a status line")
    else:
        s = {k: int(v, 16) & 0x3D for k, v in status.items()}
        if s["before"] or s["engine 1"]:
            problems.append("an engine faulted or halted besides engine 0's underflow")
        if s["after"] != 0x05:
            problems.append("engine 0 did not halt with an underflow: STATUS 0x%s" % status["after"])
        if s["after a start"] != 0x05 or pcs["after"] != pcs["after a start"]:
            problems.append("a start ran engine 0 again: STATUS 0x%s pc %s" % (
                status["after a start"], pcs["after a start"]))
    if run["log"].splitlines()[-1:] != ["PASS"]:
        problems.append("fault.log does not end in PASS")
    problems += ["%s is not the one the run's SHA256SUMS.run lists" % name
                 for name, sha in run["kept"].items() if run["sums"].get(name) != sha]
    if [sha for name, sha in run["sums"].items() if name.endswith(".bit")] != [
            run["fields"]["bitstream_sha256"]]:
        problems.append("SHA256SUMS.run names another bitstream than the ledger's")
    script = in_tree(FAULT_SCRIPT)
    if run["sums"].get("fault_board.py") != sha256(script):
        problems.append("%s is not fault_board.py as the run hashed it" % FAULT_SCRIPT)
    for name, firmware in [("FAULT", "fault_release"), ("BLINK", "blink")]:
        if words_of(script.decode(), name) != (hex_words("test/%s.hex" % firmware),
                                               hex_words("test/%s.cert.hex" % firmware)):
            problems.append("%s's %s is not test/%s.hex" % (FAULT_SCRIPT, name, firmware))
    tally = {"capture": {"file": "fault.sr", "sha256": run["kept"]["fault.sr"],
                         "rate_hz": int(rate), "seconds": len(samples) / rate,
                         "analyser": "A",
                         "channels": {"D4": "OUT0, fault_release's side-set pin",
                                      "D6": "OUT2, engine 1's blink"}},
             "out0_rise_s": round(rise / rate, 6), "out0_fall_s": round(fall / rate, 6),
             "out2_edges_after_fall": int((blink > fall).sum()),
             "status": {k: "0x" + v for k, v in status.items()},
             "pc": {k: int(v) for k, v in pcs.items()}}
    return tally, problems


def fault_teeth(directory):
    run = fault_run(directory)
    rate, samples = run["rate"], run["samples"]
    fall = int(sigrok.edges(samples, FAULT_OUT0)[0][-1])

    def bitten(what, **changes):
        wrong = fault_judge(dict(run, **changes))[1]
        return what, wrong[0] if wrong else None

    later = fall + round(0.5 * rate)
    still = fall + round(1.0 * rate)
    return [
        bitten("OUT0 driven high again for 1 ms, 0.5 s after its fall",
               samples=changed(samples, FAULT_OUT0, later, later + round(1e-3 * rate), 1)),
        bitten("OUT2 held still from 1 s after OUT0's fall",
               samples=changed(samples, FAULT_OUT2, still, len(samples),
                               samples[still] >> FAULT_OUT2 & 1)),
        bitten("the log's start leaving engine 0 running",
               log=re.sub(r"(?m)^after a start 0x\w+", "after a start 0x0000", run["log"])),
    ]


def fault_says(tally):
    return ("OUT0 fell at %.3f s and stayed low, OUT2 toggled %d times after, engine 0 halted "
            "with STATUS %s at pc %d through a start" % (
                tally["out0_fall_s"], tally["out2_edges_after_fall"],
                tally["status"]["after a start"], tally["pc"]["after a start"]))


LOG_DEMOS = {
    "eth_rx": LogDemo(
        ("test/ethernet_rx.hex", "test/ethernet_rx.cert.hex"),
        ("python/demo_ethernet_rx.py", "python/ethernet.py", "python/bench.py"),
        "Pico A's PIO as the 10BASE-T sender on IO0, at 10 Mb/s off its own crystal",
        lambda directory: frames.judge(text(directory, "eth_rx.log")),
        lambda directory: frames.teeth(text(directory, "eth_rx.log")),
        lambda t: "%d of %d frames received whole, %d with a bad FCS refused" % (
            t["received_whole"], t["frames"], t["bad_fcs"]),
        ("10 Mb/s is past the analyser, so the log is the run's only record: CI judges its "
         "frames again from the bytes it says were sent",
         "the line is Pico A's 3.3 V logic, as a line receiver with squelch would give "
         "the chip, not a twisted pair through a transformer"),
        clock="40 MHz"),
    "kernel_vs_board": LogDemo(
        (), ("python/demo_kernel_vs_board.py", "python/demo_sweep.py",
             "python/demo_self_timing.py", "python/sweep_firmware.py"),
        "engine 1 stamping engine 0's output on wire 20, as the sweep does",
        lambda directory: kvb_judge(kvb_run(directory)), kvb_teeth, kvb_says,
        kept=("results.jsonl", "board.log", "summary.txt", "verdicts.tsv", "SHA256SUMS.inputs",
              "kvb.sh", "kvb-small.out", "kvb-big.out")),
    "fault_release": LogDemo(
        ("test/fault_release.hex", "test/fault_release.cert.hex", "test/blink.hex",
         "test/blink.cert.hex"), (FAULT_SCRIPT,),
        "analyser A (fx2lafw) at 24 MS/s on OUT0 and OUT2",
        lambda directory: fault_judge(fault_run(directory)), fault_teeth, fault_says,
        kept=("fault.log", "fault.sr", "SHA256SUMS.run", "fault.sh", "edges.py", "edges.txt")),
}


def firmware_hash(name, text_at):
    """Returns the sha256 of a test/ file, or of one of python/bench_firmware.py's entries as
    sorted JSON. text_at(path) reads a file as the run had it."""
    if "/" in name:
        return sha256(text_at(name))
    scope = {}
    exec(text_at("python/bench_firmware.py").decode(), scope)
    return sha256(json.dumps(scope[name], sort_keys=True, separators=(",", ":")).encode())


def in_tree(path):
    return (ROOT / path).read_bytes()


def at_commit(commit):
    """Returns a file as it is at commit. A dirty run's tree is read at the commit it was dirty on."""
    commit = commit.removesuffix("+dirty")
    return lambda path: subprocess.run(["git", "-C", str(ROOT), "show", "%s:%s" % (commit, path)],
                                       capture_output=True, check=True).stdout


def ledger_fields(directory):
    return dict(re.findall(r"^(\w+): (.*)$", (directory / "ledger.txt").read_text(), re.M))


def sums(directory):
    return {name.lstrip("*"): sha for sha, name in
            (line.split(maxsplit=1) for line in (directory / "SHA256SUMS").read_text().splitlines())}


def teeth(demo, samples, rate, capture, log, scratch):
    """Returns each tooth's description and why it was refused (None if it wasn't)."""
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
    if d.also_problems:
        text = (Path(capture).parent / d.also[0]).read_text()
        first = re.search(r"^key \S+ (.)$", text, re.M)
        toothed = text[:first.start(1)] + ("x" if first[1] != "x" else "y") + text[first.end(1):]
        wrong = d.also_problems(toothed, log)
        out.append(("%s's first key changed" % d.also[0], wrong[0] if wrong else None))
    return out


def files(demo):
    if demo in LOG_DEMOS:
        return [k.format(demo) for k in LOG_DEMOS[demo].kept + LOG_KEPT]
    name = DEMOS[demo].name(demo)
    return [k.format(name) for k in KEPT] + list(DEMOS[demo].also)


def log_witness(directory):
    """Returns the witness.json fields for a run with no capture, and its teeth."""
    fields = ledger_fields(directory)
    demo = fields["demo"]
    d = LOG_DEMOS[demo]
    log = files(demo)[0]
    tally, _ = d.judge(directory)
    bitten = d.teeth(directory)
    return {
        "demo": demo,
        "time": fields["time"],
        "result": fields["result"],
        "commit": fields["commit"],
        "bitstream_sha256": fields["bitstream_sha256"],
        "netlist_sha256": fields.get("netlist_sha256", "not recorded"),
        "sums_sha256": sha256((directory / "SHA256SUMS").read_bytes()),
        "log": {"file": log, "sha256": sums(directory)[log]},
        "tally": tally,
        "teeth": [what for what, _ in bitten],
    }, bitten


def check_log(directory, w):
    """Does check() for a demo with no capture."""
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
    return problems + d.judge(directory)[1], bitten


def proved(timing):
    """Returns how many windows were proved from each source."""
    return {source: sum(r["verdict"] == "proved" and r["source"] == source for r in timing)
            for source in SOURCES}


def says(w):
    """Returns what a PASS or PARTIAL line says of a capture's windows."""
    n = w["proved"]
    rest = "".join(", %d %s" % (n[s], s) for s in SOURCES[2:] if n[s])
    return "%s, bitstream %s, %d of %d windows proved (%d spec, %d own%s), %d unresolved" % (
        w["capture"]["sha256"][:16], w["bitstream_sha256"][:16], sum(n.values()),
        len(w["timing"]), n["spec"], n["own"], rest, len(w["timing"]) - sum(n.values()))


def witness(directory, scratch):
    """Returns the witness.json fields for the run in directory (everything except what it
    can't say), and its teeth()."""
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
        "proved": proved(timing),
        "partial": d.partial or None,
        "teeth": [what for what, _ in bitten],
    }, bitten


def check(directory):
    """Returns what is wrong with the witness in directory, and its teeth's verdicts."""
    directory = Path(directory)
    w = json.loads((directory / "witness.json").read_text())
    demo = w["demo"]
    if demo.startswith("learn_"):
        return learn_witness.check(directory)
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
    if d.also_problems:
        problems += d.also_problems((directory / d.also[0]).read_text(), log)
    problems += ["%s %s: %s, measured %s" % (r["parameter"], r["limit"], r["verdict"],
                                             r["measured"])
                 for r in made["timing"] if r["verdict"] in ("fail", "absent")]
    return problems, bitten


def write(run, directory, carrier, bitstream):
    """Writes a ledger run's witness, copying its files into directory. `bitstream` says what
    the bitstream was built from, if the run doesn't."""
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
    # a run without a netlist records it as "-"
    named = ("its sha256, and its netlist's," if fields.get("netlist_sha256", "-") != "-"
             else "its sha256,")
    built = ("the bitstream is named by %s built from %s by the bench's notes, which CI does "
             "not rebuild" % (named, bitstream) if bitstream else
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
                      d.clock if demo in LOG_DEMOS else "48 MHz", carrier, d.peer,
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


def refresh(directory):
    """Rewrites what witness.json derives from the run in directory, keeping what the run
    recorded (its bench, bitstream source, firmware and script hashes)."""
    directory = Path(directory)
    path = directory / "witness.json"
    w = json.loads(path.read_text())
    if w["demo"].startswith("learn_"):
        return
    if w["demo"] in LOG_DEMOS:
        made, _ = log_witness(directory)
    else:
        with tempfile.TemporaryDirectory() as scratch:
            made, _ = witness(directory, scratch)
    path.write_text(json.dumps({**made, **{k: v for k, v in w.items() if k not in made}},
                               indent=2) + "\n")


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
    refreshing = sub.add_parser("refresh")
    refreshing.add_argument("directories", nargs="+")
    args = parser.parse_args()
    if args.command == "write":
        sys.exit(0 if write(args.run, args.directory, args.carrier, args.bitstream) else 1)
    if args.command == "refresh":
        for directory in args.directories:
            refresh(directory)
        return
    ok = True
    for directory in args.directories:
        problems, bitten = check(directory)
        name = Path(directory).name
        for problem in problems:
            print("FAIL %s: %s" % (name, problem))
        for what, why in bitten:
            print("TOOTH %s: %s refused: %s" % (name, what, why[:200]) if why else
                  "MISSED %s: %s passed" % (name, what))
        w = json.loads((Path(directory) / "witness.json").read_text())
        if not problems and w["demo"].startswith("learn_"):
            print("PASS %s: sigrok reads the chip's message in each of the %d frames sent, the "
                  "edges are the captures'" % (name, learn_witness.sent(Path(directory))))
        elif not problems and "tally" in w:
            print("PASS %s: %s" % (name, LOG_DEMOS[w["demo"]].says(w["tally"])))
        elif not problems and w.get("partial"):
            print("PARTIAL %s: %s, %s" % (name, says(w), w["partial"]))
        elif not problems:
            print("PASS %s: %s" % (name, says(w)))
        ok = ok and not problems and all(why for _, why in bitten)
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
