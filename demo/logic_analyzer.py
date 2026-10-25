# SPDX-License-Identifier: Apache-2.0
# Reads and writes the CSV gusmanb's LogicAnalyzer firmware saves through TerminalCapture: a
# header of channel names, then a row a sample of 0 or 1 a channel. It holds no sample
# rate, so the capture's settings give it. The main turns one into a sigrok session file,
# so edges.py, decode.py and the rest read it too.
# Usage: python3 demo/logic_analyzer.py CAPTURE.csv 100M OUT.sr

import sys

import sigrok


def read(path, rate_hz):
    """As sigrok.read: the rate, the channel names by bit, the samples a byte each. Up to
    eight channels, as the 8-channel capture mode takes."""
    with open(path) as f:
        names = [name.strip() for name in f.readline().split(",")]
        if len(names) > 8:
            raise ValueError("%s: %d channels, only up to 8 are read" % (path, len(names)))
        samples = bytearray()
        for line in f:
            if line.strip():
                bits = line.split(",")
                samples.append(sum(int(b) << i for i, b in enumerate(bits)))
    return rate_hz, dict(enumerate(names)), bytes(samples)


def write(path, names, samples):
    """samples: a byte a sample, bit i the channel names[i]."""
    with open(path, "w") as f:
        f.write(",".join(names) + "\n")
        for s in samples:
            f.write(",".join(str((s >> i) & 1) for i in range(len(names))) + "\n")


def read_any(path, rate_hz=None):
    """A sigrok session file, or a LogicAnalyzer CSV at rate_hz."""
    if path.endswith(".csv"):
        if not rate_hz:
            raise SystemExit("%s holds no sample rate: give it" % path)
        return read(path, rate_hz)
    return sigrok.read(path)


if __name__ == "__main__":
    capture, rate, out = sys.argv[1:]
    rate_hz, names, samples = read(capture, sigrok.hz(rate))
    sigrok.write(out, rate_hz, samples, names=[names[i] for i in range(len(names))])
