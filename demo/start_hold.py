# SPDX-License-Identifier: Apache-2.0
# The analyser's own reading of a start hold capture: for every START, the time from SDA
# falling while SCL is high to SCL's next fall, to the nearest sample. It shares nothing with
# pio_check's bound or the chip's stamps. It only looks at falls, so the pull-ups' slow
# rises don't matter.
# Usage: python3 demo/start_hold.py CAPTURE.sr

import bisect
import re
import sys

import sigrok

# UM10204 table 11, t_HD;STA in Standard-mode
LIMIT_NS = 4000
# the chip's clock, so we can compare with its stamps
MHZ = 48


def falls(samples, bit):
    """Returns one channel's levels (a byte per sample) and the sample of each fall."""
    levels = samples.translate(bytes((b >> bit) & 1 for b in range(256)))
    return levels, [m.start() + 1 for m in re.finditer(b"\x01\x00", levels)]


def holds(path, sda=6, scl=7):
    """Returns each START's hold in ns, and how many ns a sample is."""
    rate, _, samples = sigrok.read(path)
    _, sda_falls = falls(samples, sda)
    scl_levels, scl_falls = falls(samples, scl)
    out = []
    for at in sda_falls:
        later = bisect.bisect_right(scl_falls, at)
        if scl_levels[at] and later < len(scl_falls):
            out.append((scl_falls[later] - at) * 1e9 / rate)
    return out, 1e9 / rate


def main():
    found, sample = holds(sys.argv[1])
    if not found:
        print("analyser: no START in %s" % sys.argv[1])
        sys.exit(1)
    counts = {}
    for hold in found:
        counts[round(hold)] = counts.get(round(hold), 0) + 1
    print("analyser: %d STARTs, SDA fall to SCL fall, each +-%.1f ns" % (len(found), sample))
    for hold in sorted(counts):
        print("  %6d ns %6.1f cycles at %d MHz %5d" % (hold, hold * MHZ / 1000, MHZ, counts[hold]))
    least = min(found)
    print("analyser, against t_HD;STA >= %d ns: least %.0f ns, %s" % (
        LIMIT_NS, least, "meets" if least - sample >= LIMIT_NS else
        "VIOLATES" if least + sample < LIMIT_NS else "within a sample"))


if __name__ == "__main__":
    main()
