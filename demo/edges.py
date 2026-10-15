# SPDX-License-Identifier: Apache-2.0
# A bench capture's edges on some of the engine's pins, for test/measure, which holds them
# to the bench copy's datasheet limits: the sample rate, the length, then each pin's level
# at the first sample and every sample it changes at. A pin is a number or a name, IO0.
# Usage: python3 demo/edges.py CAPTURE.sr IO0=D6 IO1=D7 \
#          | dune exec --root . test/measure/measure.exe -- ps2

import argparse
import re

import sigrok

FIRST = {"IN": 0, "OUT": 5, "IO": 12}


def pin(name):
    """The engine's number for a pin: IN0 to IN4 are 0 to 4, OUT0 to OUT6 5 to 11, and IO0
    to IO7 12 to 19."""
    named = re.fullmatch(r"(IN|OUT|IO)(\d)", name)
    return FIRST[named.group(1)] + int(named.group(2)) if named else int(name)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("capture")
    parser.add_argument("probes", nargs="+", help="PIN=Dn, a pin on an analyser channel")
    args = parser.parse_args()
    rate, channels, samples = sigrok.read(args.capture)
    bits = {name: bit for bit, name in channels.items()}
    print("rate %d" % rate)
    print("length %d" % len(samples))
    for probe in args.probes:
        name, channel = probe.split("=")
        bit = bits[channel]
        at, _ = sigrok.edges(samples, bit)
        first = (samples[0] >> bit) & 1 if samples else 0
        print("pin %d %d %s" % (pin(name), first, " ".join(str(a) for a in at)))


if __name__ == "__main__":
    main()
