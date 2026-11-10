#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# Has FFmpeg read the AC-3 frame back from a capture of python/demo_spdif_ac3.py. Reads
# OUT0's samples by run length, packs them into DIR/spdif_ac3.spdif, and compares the MD5 of
# the frame FFmpeg's spdif demuxer finds there with that of the burst sent. Also decodes it
# to DIR/spdif_ac3.wav.
# Usage: python3 demo/ffmpeg_referee.py DIR, after demo/outside.sh spdif_ac3 with CAPTURES=DIR

import struct
import subprocess
import sys
from pathlib import Path

import sigrok

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "python"))
import demo_spdif_ac3  # noqa: E402

# analyser A's channel on OUT0
LINE = 4
# 8 32991/65536 cycles at 48 MHz, as test/spdif.ml
HALF = (8 + 32991 / 65536) / 48e6


def pack(words):
    return struct.pack("<%dH" % len(words), *words)


def captured(samples, rate):
    """Returns each subframe's 16-bit sample, read from the line's runs in half slots. A
    preamble opens with three half slots low and takes eight; then a slot with an edge in
    its middle is a 1, and the sample is slots 12 to 27, LSB first."""
    levels = samples.translate(bytes((b >> LINE) & 1 for b in range(256)))
    halves, at = [], 0
    while at < len(levels):
        end = levels.find(bytes([levels[at] ^ 1]), at)
        end = len(levels) if end < 0 else end
        halves.append((levels[at], max(1, round((end - at) / (HALF * rate)))))
        at = end
    words, i = [], 0
    while i < len(halves):
        level, n = halves[i]
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
            words.append(sum(bit << k for k, bit in enumerate(bits[8:24])))
    return words


def ffmpeg(*args):
    return subprocess.run(["ffmpeg", "-v", "error", "-y", *args], capture_output=True, text=True)


def frame_md5(path):
    """Returns the MD5 of the frames FFmpeg's spdif demuxer finds in path, or its error."""
    done = ffmpeg("-f", "spdif", "-i", str(path), "-c", "copy", "-f", "md5", "-")
    return done.stdout.strip() or done.stderr.strip() or "no frame"


def main():
    if len(sys.argv) != 2:
        sys.exit("usage: %s DIR" % sys.argv[0])
    d = Path(sys.argv[1])
    rate, _, samples = sigrok.read(d / "spdif_ac3.sr")
    words = captured(samples, rate)
    got, sent = d / "spdif_ac3.spdif", d / "spdif_ac3.sent.spdif"
    got.write_bytes(pack(words))
    sent.write_bytes(pack(demo_spdif_ac3.WORDS))
    want, found = frame_md5(sent), frame_md5(got)
    print("%d words captured" % len(words))
    print("sent     %s" % want)
    print("captured %s" % found)
    wav = ffmpeg("-f", "spdif", "-i", str(got), str(d / "spdif_ac3.wav"))
    print("decode to wav: %s" % (wav.stderr.strip() or "ok"))
    ok = want.startswith("MD5=") and want == found and wav.returncode == 0
    print("PASS" if ok else "FAIL")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
