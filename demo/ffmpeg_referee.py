#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# Has FFmpeg read the frames back from a capture of python/demo_spdif_ac3.py or
# demo_spdif_codecs.py. Reads OUT0's samples by run length, packs the words into
# DIR/DEMO.spdif (a file per codec for spdif_codecs), compares the MD5 of the frames
# FFmpeg finds there with that of the bursts sent, and decodes each to a .wav.
# Usage: python3 demo/ffmpeg_referee.py DIR [DEMO], after demo/outside.sh DEMO with
#        CAPTURES=DIR. DEMO is spdif_ac3 unless given.

import struct
import subprocess
import sys
import tempfile
from pathlib import Path

import sigrok

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "python"))
import demo_spdif_ac3  # noqa: E402
import spdif_bursts  # noqa: E402

# analyser A's channel on OUT0
LINE = 4
# 8 32991/65536 cycles at 48 MHz, as test/spdif.ml
HALF = (8 + 32991 / 65536) / 48e6
# Pa and Pb, which open an IEC 61937 burst
SYNC = (0xF872, 0x4E1F)
# IEC 61937's data types, as FFmpeg's demuxer names their codecs
TYPES = {0x01: "ac3", 0x05: "mp3", 0x07: "aac", 0x0B: "dts"}
# words a burst may start off its period, as the firmware starts one on a frame and the
# Pico's push is tens of microseconds off
SLACK = 8


def pack(words):
    return struct.pack("<%dH" % len(words), *words)


def subframes(samples, rate):
    """Returns each subframe's first sample and 16-bit word, read from the line's runs in
    half slots. A preamble opens with three half slots low and takes eight; then a slot with
    an edge in its middle is a 1, and the word is slots 12 to 27, LSB first."""
    levels = samples.translate(bytes((b >> LINE) & 1 for b in range(256)))
    halves, at = [], 0
    while at < len(levels):
        end = levels.find(bytes([levels[at] ^ 1]), at)
        end = len(levels) if end < 0 else end
        halves.append((levels[at], max(1, round((end - at) / (HALF * rate))), at))
        at = end
    found, i = [], 0
    while i < len(halves):
        level, n, start = halves[i]
        i += 1
        if level or n != 3:
            continue
        seen = 3
        while seen < 8 and i < len(halves):
            seen += halves[i][1]
            i += 1
        bits = []
        while len(bits) < 28 and i < len(halves) and halves[i][1] < 3:
            one = halves[i][1] == 1
            bits.append(one)
            i += 2 if one else 1
        if len(bits) == 28:
            found.append((start, sum(bit << k for k, bit in enumerate(bits[8:24]))))
    return found


def captured(samples, rate):
    return [word for _, word in subframes(samples, rate)]


def lines(words):
    """Returns the words one a line, as demo/traffic.py compares them."""
    return ["%04x" % word for word in words]


def ffmpeg(*args):
    try:
        return subprocess.run(["ffmpeg", "-v", "error", "-y", *args], capture_output=True,
                              text=True)
    except FileNotFoundError:
        return subprocess.CompletedProcess(args, 1, "", "no ffmpeg on the PATH")


def frame_md5(path):
    """Returns the MD5 of the frames FFmpeg's spdif demuxer finds in path, or its error."""
    done = ffmpeg("-f", "spdif", "-i", str(path), "-c", "copy", "-f", "md5", "-")
    return done.stdout.strip() or done.stderr.strip() or "no frame"


def problems(words):
    """Returns how the frame FFmpeg finds in words differs from the one in the burst sent."""
    with tempfile.TemporaryDirectory() as scratch:
        got, sent = Path(scratch) / "got.spdif", Path(scratch) / "sent.spdif"
        got.write_bytes(pack(words))
        sent.write_bytes(pack(demo_spdif_ac3.WORDS))
        want, found = frame_md5(sent), frame_md5(got)
    if not want.startswith("MD5="):
        return ["FFmpeg reads no frame in the burst sent: %s" % want]
    return [] if want == found else [
        "FFmpeg's frame in the capture is %s, in the burst sent %s" % (found, want)]


def bursts(words):
    """Returns each burst's place and words (Pa Pb Pc Pd, then Pd bits of payload). Raises
    if anything but zeros lies between two bursts."""
    found, at = [], 0
    while at < len(words):
        if tuple(words[at:at + 2]) != SYNC:
            if words[at]:
                raise ValueError("word %d is 0x%04x, neither a burst nor silence"
                                 % (at, words[at]))
            at += 1
            continue
        end = at + 4 + (words[at + 3] + 15) // 16
        found.append((at, list(words[at:end])))
        at = end
    return found


def sent():
    """Returns demo_spdif_codecs' codecs: name, burst period and each burst's words."""
    return [(name, period, [[int(burst[i:i + 4], 16) for i in range(0, len(burst), 4)]
                            for burst in hexes])
            for name, period, hexes in spdif_bursts.CODECS]


def codec_name(path):
    """Returns the codec FFmpeg's spdif demuxer finds in path, or its error."""
    try:
        done = subprocess.run(
            ["ffprobe", "-v", "error", "-f", "spdif", "-show_entries", "stream=codec_name",
             "-of", "csv=p=0", str(path)], capture_output=True, text=True)
    except FileNotFoundError:
        return "no ffprobe on the PATH"
    return done.stdout.strip() or done.stderr.strip() or "no stream"


def by_codec(found):
    """Returns the bursts' words joined per codec, by data type."""
    joined = {}
    for _, burst in found:
        joined.setdefault(TYPES.get(burst[2] & 0x7F, "type 0x%02x" % (burst[2] & 0x7F)),
                          []).extend(burst)
    return joined


def codecs_problems(words):
    """Returns how the bursts in words differ from those sent, by their words, their places
    in each codec's burst period, the codec FFmpeg names and the frames it finds."""
    try:
        found = bursts(words[words.index(SYNC[0]):] if SYNC[0] in words else [])
    except ValueError as e:
        return [str(e)]
    want = sent()
    flat = [burst for _, _, each in want for burst in each]
    if [burst for _, burst in found] != flat:
        return ["%d bursts in the capture, not the %d sent or not their words"
                % (len(found), len(flat))]
    problems, at = [], 0
    for name, period, each in want:
        places = [place for place, _ in found[at:at + len(each)]]
        at += len(each)
        off = [b - a - period for a, b in zip(places, places[1:])]
        if any(abs(o) > SLACK for o in off):
            problems.append("%s: bursts %s words off their period of %d" % (name, off, period))
    captured = by_codec(found)
    with tempfile.TemporaryDirectory() as scratch:
        for name, _, each in want:
            got, original = Path(scratch) / "got.spdif", Path(scratch) / "sent.spdif"
            got.write_bytes(pack(captured[name]))
            original.write_bytes(pack(sum(each, [])))
            named = codec_name(got)
            if named != name:
                problems.append("%s: FFmpeg names the captured bursts %s" % (name, named))
            md5, found_md5 = frame_md5(original), frame_md5(got)
            if not md5.startswith("MD5=") or md5 != found_md5:
                problems.append("%s: FFmpeg's frames in the capture are %s, in the bursts "
                                "sent %s" % (name, found_md5, md5))
    return problems


def codecs(d, words):
    """Saves each codec's captured bursts and FFmpeg's decode of them in d. Returns
    whether all of it passed."""
    problems = codecs_problems(words)
    found = bursts(words[words.index(SYNC[0]):]) if SYNC[0] in words else []
    for name, joined in sorted(by_codec(found).items()):
        got = d / ("spdif_codecs.%s.spdif" % name)
        got.write_bytes(pack(joined))
        wav = ffmpeg("-f", "spdif", "-i", str(got), str(got.with_suffix(".wav")))
        print("%s: FFmpeg names it %s, frames %s, decode to wav: %s"
              % (name, codec_name(got), frame_md5(got), wav.stderr.strip() or "ok"))
        if wav.returncode:
            problems.append("%s: no decode" % name)
    for problem in problems:
        print(problem)
    return not problems


def main():
    if len(sys.argv) not in (2, 3):
        sys.exit("usage: %s DIR [spdif_ac3|spdif_codecs]" % sys.argv[0])
    d, demo = Path(sys.argv[1]), (sys.argv[2:] or ["spdif_ac3"])[0]
    rate, _, samples = sigrok.read(d / (demo + ".sr"))
    words = captured(samples, rate)
    print("%d words captured" % len(words))
    if demo == "spdif_codecs":
        ok = codecs(d, words)
    else:
        got, sent = d / "spdif_ac3.spdif", d / "spdif_ac3.sent.spdif"
        got.write_bytes(pack(words))
        sent.write_bytes(pack(demo_spdif_ac3.WORDS))
        want, found = frame_md5(sent), frame_md5(got)
        print("sent     %s" % want)
        print("captured %s" % found)
        wav = ffmpeg("-f", "spdif", "-i", str(got), str(d / "spdif_ac3.wav"))
        print("decode to wav: %s" % (wav.stderr.strip() or "ok"))
        ok = want.startswith("MD5=") and want == found and wav.returncode == 0
    print("PASS" if ok else "FAIL")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
