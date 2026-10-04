# SPDX-License-Identifier: Apache-2.0
# The analyser's own reading of a start hold capture: for every START, SDA's fall while
# SCL is high to SCL's next fall, to a sample. It shares nothing with pio_check's bound or
# the chip's stamps. Falls only, so the pull-ups' slow rises do not enter it.
# Usage: python3 demo/start_hold.py CAPTURE.sr

import bisect
import re
import sys

import sigrok

# UM10204 table 10, t_HD;STA in Standard-mode
LIMIT_NS = 4000
# the chip's clock, to set the reading beside its stamps
MHZ = 48


def falls(samples, bit):
    """One channel's levels, a byte a sample, and the sample of each fall."""
    levels = samples.translate(bytes((b >> bit) & 1 for b in range(256)))
    return levels, [m.start() + 1 for m in re.finditer(b"\x01\x00", levels)]


def holds(path, sda=6, scl=7):
    """Each START's hold in ns, and the ns a sample is."""
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
