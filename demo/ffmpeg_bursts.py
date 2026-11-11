#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# Writes python/spdif_bursts.py, a chirp encoded by FFmpeg as AC-3, MP3, AAC and DTS, each
# muxed to IEC 61937 bursts by its spdif muxer, without the zero padding between bursts.
# The encoders' output can change with FFmpeg's version, so the file names the one used.
# Usage: python3 demo/ffmpeg_bursts.py [--check]

import struct
import subprocess
import sys
import tempfile
from pathlib import Path

import ffmpeg_referee

OUT = Path(__file__).resolve().parent.parent / "python/spdif_bursts.py"
CHIRP = "aevalsrc=sin(2*PI*t*(440+1760*t)):s=44100:d=1"
# name, encoder arguments, frames asked for, and a muxer and its demuxer to go through first
CODECS = (
    ("ac3", ("-c:a", "ac3", "-b:a", "32k"), 4, None),
    ("mp3", ("-c:a", "libmp3lame", "-b:a", "32k"), 5, None),
    # the spdif muxer wants ADTS headers
    ("aac", ("-c:a", "aac", "-b:a", "32k"), 6, ("adts", "aac")),
    ("dts", ("-c:a", "dca", "-strict", "-2", "-b:a", "192k"), 12, None),
)


def ffmpeg(*args):
    return subprocess.run(["ffmpeg", "-v", "error", "-y", *args], check=True,
                          capture_output=True)


def version():
    return subprocess.run(["ffmpeg", "-version"], check=True, capture_output=True,
                          text=True).stdout.split()[2]


def period(places):
    """Returns the words from one burst's start to the next."""
    gaps = {b - a for a, b in zip(places, places[1:])}
    if len(gaps) != 1:
        raise ValueError("bursts %s words apart" % sorted(gaps))
    return gaps.pop()


def encode(args, frames, container, scratch):
    source = ("-f", "lavfi", "-i", CHIRP, "-ac", "1", *args, "-frames:a", str(frames),
              "-bitexact")
    out = scratch / "out.spdif"
    if container:
        muxer, demuxer = container
        ffmpeg(*source, "-f", muxer, str(scratch / "frames"))
        ffmpeg("-f", demuxer, "-i", str(scratch / "frames"), "-c", "copy", "-bitexact",
               "-f", "spdif", str(out))
    else:
        ffmpeg(*source, "-f", "spdif", str(out))
    data = out.read_bytes()
    return struct.unpack("<%dH" % (len(data) // 2), data)


def module():
    lines = [
        "# SPDX-License-Identifier: Apache-2.0",
        "# IEC 61937 bursts of a chirp in four codecs, for python/demo_spdif_codecs.py.",
        "# Written by demo/ffmpeg_bursts.py with FFmpeg %s, do not edit." % version(),
        "",
        "# the codec's name, the words from one burst's start to the next, and each burst's",
        "# words in hex, most significant byte first",
        "CODECS = (",
    ]
    with tempfile.TemporaryDirectory() as scratch:
        for name, args, frames, container in CODECS:
            found = ffmpeg_referee.bursts(encode(args, frames, container, Path(scratch)))
            lines.append('    ("%s", %d, (' % (name, period([place for place, _ in found])))
            for _, burst in found:
                text = "".join("%04x" % word for word in burst)
                rows = [text[i:i + 88] for i in range(0, len(text), 88)]
                lines += ['        "%s"' % row for row in rows[:-1]]
                lines.append('        "%s",' % rows[-1])
            lines.append("    )),")
    return "\n".join(lines + [")", ""])


def main():
    text = module()
    if sys.argv[1:] == ["--check"]:
        sys.exit(0 if OUT.read_text() == text else "%s differs from FFmpeg %s's bursts"
                 % (OUT, version()))
    OUT.write_text(text)


if __name__ == "__main__":
    main()
