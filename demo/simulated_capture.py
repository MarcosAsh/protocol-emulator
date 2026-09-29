# SPDX-License-Identifier: Apache-2.0
# A stand-in capture until a board runs: the frames of a Cyclesim pin trace from
# test/traces, repeated with a random idle between them, sampled the way the logic
# analyser would, at its own clock with a random phase and a crystal's error against
# the chip's.
# Usage: uv run demo/simulated_capture.py test/traces/uart_tx.trace out.sr
#
# /// script
# dependencies = ["numpy"]
# ///
import argparse

import numpy as np

import sigrok

# OUT0 is uo_out[1] on the top and D4 on the analyser
PIN = 1
CHANNEL = 4


def out_levels(path):
    levels = []
    for line in open(path):
        if line.startswith("#") or not line.strip():
            continue
        count, _ui, _uio, uo_out, _uio_out, _uio_oe = line.split()
        levels += [(int(uo_out, 16) >> PIN) & 1] * int(count)
    return np.array(levels, dtype=np.uint8)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("trace")
    parser.add_argument("output")
    parser.add_argument("--frames", type=int, default=1000, help="copies of the trace's frames")
    parser.add_argument("--clock-mhz", type=float, default=48.0)
    parser.add_argument("--rate-mhz", type=float, default=24.0, help="analyser sample rate")
    parser.add_argument("--ppm", type=float, default=30.0, help="most crystal error, either way")
    parser.add_argument("--seed", type=int, default=0)
    args = parser.parse_args()
    rng = np.random.default_rng(args.seed)

    levels = out_levels(args.trace)
    moving = np.flatnonzero(np.diff(levels))
    falling = moving[levels[moving] == 1]
    # from the first start bit, the line having only just gone idle before it, to the
    # line settled after the last frame
    segment = levels[falling[0] : moving[-1] + 64]
    idle = np.ones(1, dtype=np.uint8)
    pieces = []
    for _ in range(args.frames):
        pieces += [np.repeat(idle, rng.integers(40, 400)), segment]
    cycles = np.concatenate(pieces + [np.repeat(idle, 400)])

    clock = args.clock_mhz * 1e6 * (1 + rng.uniform(-args.ppm, args.ppm) * 1e-6)
    rate = args.rate_mhz * 1e6
    count = int(len(cycles) / clock * rate) - 1
    at = np.floor((np.arange(count) / rate + rng.uniform(0, 1 / clock)) * clock).astype(int)
    samples = (cycles[at] << CHANNEL).astype(np.uint8)
    sigrok.write(args.output, rate, samples.tobytes())
    print(
        "%s: %d samples at %g MHz, chip at %.6f MHz"
        % (args.output, count, args.rate_mhz, clock / 1e6)
    )


if __name__ == "__main__":
    main()
