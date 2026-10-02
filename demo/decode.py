# SPDX-License-Identifier: Apache-2.0
# Judges pin traces from test/traces, or a capture from the bench, by sigrok's protocol
# decoders. A trace's "# sigrok" lines (test/pin_trace.ml) name the decoders, every line
# they must print and the teeth, changes to the waveform they must refuse. Any error or
# warning annotation fails the check too.
# Usage: python3 demo/decode.py test/traces/*.trace test/traces/sigrok/*.trace
#        python3 demo/decode.py --rate 24 TRACE...            as a 24 MHz analyser sees it
#        python3 demo/decode.py --capture can.sr TRACE        a capture from the bench
#        python3 demo/decode.py --rate 24 --write-capture can.sr TRACE
#        python3 demo/decode.py --host-frames frames.py TRACE for demo/pico_replay.py
import argparse
import os
import random
import re
import subprocess
import sys
import tempfile

import sigrok

# What each decoder reports a fault in. One with none judges nothing but the payload.
ERRORS = {
    "uart": [
        "rx-warnings", "tx-warnings", "rx-parity-err", "tx-parity-err", "rx-break", "tx-break"
    ],
    "spi": ["warnings"],
    "i2c": ["warnings"],
    "can": ["warnings"],
    "cec": ["warnings"],
    "onewire_link": ["warnings"],
    "onewire_network": [],
    "ps2": ["parity-err"],
    "jtag": [],
    "usb_signalling": ["error"],
    "usb_packet": ["sync-err", "crc5-err", "crc16-err", "packet-err", "packet-invalid"],
    "usb_request": ["errors"],
    "rgb_led_ws281x": [],
    "swd": ["parity"],
}

# The bench's analyser, as the Demo Bench Wiring has CH1 to CH6: the host's SCK, MOSI,
# MISO and CS_N, then OUT0 and OUT1
BENCH = {"SCK": "D0", "MOSI": "D1", "MISO": "D2", "CS_N": "D3", "OUT0": "D4", "OUT1": "D5"}

PIN = re.compile(r"=((?:IN|OUT|IO)\d|SCK|MOSI|MISO|CS_N)\b")


class Refusal:
    """How the decoders misread a waveform: the first payload line that differs is line
    at, where sigrok prints a line starting with reads."""

    def __init__(self, why, at, reads):
        self.why, self.at, self.reads = why, int(at), reads

    def matches(self, mismatches):
        return bool(mismatches) and mismatches[0][1] == self.at and (
            mismatches[0][2] or "").startswith(self.reads)


class Trace:
    def __init__(self, path):
        self.name = os.path.basename(path).removesuffix(".trace")
        self.clock = self.joins_after = self.misread = self.rejected = None
        refusals = {}
        self.decoders, self.expect, self.teeth, self.lines = [], [], [], []
        for line in open(path):
            if line.startswith("# sigrok "):
                key, _, value = line[len("# sigrok "):].rstrip("\n").partition(" ")
                if key == "clock":
                    self.clock = int(value)
                elif key == "decoder":
                    self.decoders.append(value)
                elif key == "annotations":
                    self.expect.append((value, []))
                elif key == "expect":
                    self.expect[-1][1].append(value)
                elif key == "joins_after":
                    self.joins_after = int(value)
                elif key in ("misread", "rejected"):
                    field, _, text = value.partition(" ")
                    refusals.setdefault(key, {})[field] = text
                elif key == "tooth":
                    self.teeth.append(value.split())
            elif not line.startswith("#") and line.strip():
                count, *pins = line.split()
                self.lines.append((int(count), [int(p, 16) for p in pins]))
        self.misread, self.rejected = (
            Refusal(**refusals[k]) if k in refusals else None for k in ("misread", "rejected"))

    def pins(self):
        names = []
        for decoder in self.decoders:
            names += [n for n in PIN.findall(decoder) if n not in names]
        return names

    def column(self, column, bit):
        return bytearray(
            b for count, pins in self.lines for b in [(pins[column] >> bit) & 1] * count
        )

    def wire(self, name):
        """One level a cycle. A trace line holds the outputs after its edge and the inputs
        before it, so an input's level in a cycle is on the next line; a bidirectional pin
        the core does not drive is whatever its peer made of the line."""
        def later(levels):
            return levels[1:] + levels[-1:]

        host = {"SCK": 0, "MOSI": 1, "CS_N": 2}
        if name in host:
            return later(self.column(0, host[name]))
        if name == "MISO":
            return self.column(2, 0)
        kind, n = re.fullmatch(r"(IN|OUT|IO)(\d)", name).groups()
        n = int(n)
        if kind == "IN":
            return later(self.column(0, n + 3))
        if kind == "OUT":
            return self.column(2, n + 1)
        out, oe, peer = self.column(3, n), self.column(4, n), later(self.column(1, n))
        return bytearray(o if e else p for o, e, p in zip(out, oe, peer))


def corrupt(levels, corruption):
    """shift:PIN:EDGE:CYCLES moves an edge, counted from 0, later, or earlier if negative;
    flip:PIN:EDGE:AFTER:CYCLES inverts the pin for CYCLES from AFTER past the edge."""
    kind, _, edge, *numbers = corruption.split(":")
    at = [i for i in range(1, len(levels)) if levels[i] != levels[i - 1]][int(edge)]
    if kind == "shift":
        by = int(numbers[0])
        if by > 0:
            levels[at:at + by] = bytes([levels[at - 1]]) * by
        else:
            levels[at + by:at] = bytes([levels[at]]) * -by
    else:
        after, cycles = map(int, numbers)
        for i in range(at + after, min(at + after + cycles, len(levels))):
            levels[i] ^= 1


def pack(channels):
    """One byte a cycle from one level list a channel, None for a channel left low."""
    length = max(len(c) for c in channels if c is not None)
    samples = bytearray(length)
    for bit, levels in enumerate(channels):
        if levels is not None:
            for i in range(length):
                if levels[i]:
                    samples[i] |= 1 << bit
    return samples


def sample(cycles, clock, args):
    """The cycles as an analyser at --rate sees them, its crystal off the chip's by up to
    --ppm either way and at a random phase; at the chip's clock without --rate."""
    if not args.rate:
        return clock, bytes(cycles)
    rng = random.Random(args.seed)
    rate = args.rate * 1e6
    clock *= 1 + rng.uniform(-args.ppm, args.ppm) * 1e-6
    phase = rng.uniform(0, 1 / clock)
    count = int((len(cycles) / clock - phase) * rate)
    return rate, bytes(cycles[int((k / rate + phase) * clock)] for k in range(count))


def joined(samples, bit, count):
    """The first sample after the channel has been high for count samples in a row."""
    levels = bytes(samples).translate(bytes((b >> bit) & 1 for b in range(256)))
    at = levels.find(b"\x01" * count)
    if at < 0:
        raise SystemExit("the line never idles for %d samples" % count)
    return at + count


def sigrok_cli(capture, decoders, annotations):
    command = ["sigrok-cli", "-i", capture]
    for decoder in decoders:
        command += ["-P", decoder]
    result = subprocess.run(command + ["-A", annotations], capture_output=True, text=True)
    if result.returncode or result.stderr.strip():
        raise RuntimeError("%s: %s" % (" ".join(command), result.stderr.strip()))
    return result.stdout.splitlines()


def faults(decoders):
    stacked = [d.split(":")[0] for stack in decoders for d in stack.split(",")]
    unknown = [d for d in stacked if d not in ERRORS]
    if unknown:
        raise SystemExit("decode.py lists no error classes for %s" % ", ".join(unknown))
    return ",".join("%s=%s" % (d, ":".join(ERRORS[d])) for d in stacked if ERRORS[d])


def judge(capture, decoders, expect):
    """Every fault sigrok reports, and for each payload it reads otherwise, the classes,
    the first line that differs, what sigrok prints there and what was expected."""
    reported = sigrok_cli(capture, decoders, faults(decoders)) if faults(decoders) else []
    mismatches = []
    for annotations, lines in expect:
        got = sigrok_cli(capture, decoders, annotations)
        if got != lines:
            at = next((i for i, (g, w) in enumerate(zip(got, lines)) if g != w),
                      min(len(got), len(lines)))
            mismatches.append((annotations, at, got[at] if at < len(got) else None,
                               lines[at] if at < len(lines) else None, len(got), len(lines)))
    return reported, mismatches


def describe(reported, mismatches):
    return reported + ["%s: line %d is %r, expected %r (%d lines, %d expected)" % m
                       for m in mismatches]


def captures(trace, args, scratch, tooth=()):
    """The waveforms to judge, each with why it is refused if it is: the one from reset
    and, for a line the decoders join once it idles, the one from there."""
    if args.capture:
        mapping = dict(BENCH, **dict(args.probe))
        missing = [n for n in trace.pins() if n not in mapping]
        if missing:
            raise SystemExit("%s: %s is not on the analyser, give --probe %s=Dn" % (
                trace.name, missing[0], missing[0]))
        decoders = [PIN.sub(lambda m: "=" + mapping[m.group(1)], d) for d in trace.decoders]
        rate, channels, samples = sigrok.read(args.capture)
        names = [channels.get(i, "D%d" % i) for i in range(8)]
        first = names.index(mapping[trace.pins()[0]])
    else:
        def wire(name):
            levels = trace.wire(name)
            for corruption in tooth:
                if corruption.split(":")[1] == name:
                    corrupt(levels, corruption)
            return levels

        decoders, names, first = trace.decoders, trace.pins(), 0
        rate, samples = sample(pack([wire(n) for n in names]), trace.clock, args)
    path = os.path.join(scratch, trace.name + ".sr")
    sigrok.write(path, rate, samples, names=names)
    if not trace.joins_after:
        return [("", path, decoders, trace.rejected)]
    start = joined(samples, first, round(trace.joins_after * rate / trace.clock))
    later = os.path.join(scratch, trace.name + "_joined.sr")
    sigrok.write(later, rate, samples[start:], names=names)
    return [("from reset, ", path, decoders, "info" if args.capture else trace.misread),
            ("joined, ", later, decoders, trace.rejected)]


def check(path, args):
    trace = Trace(path)
    if not trace.decoders:
        return True
    if args.host_frames:
        return host_frames(trace, args.host_frames, args.clock_mhz)
    if args.write_capture:
        return write_capture(trace, args)
    lines = sum(len(lines) for _, lines in trace.expect)
    results = []
    with tempfile.TemporaryDirectory() as scratch:
        for what, capture, decoders, rejected in captures(trace, args, scratch):
            reported, mismatches = judge(capture, decoders, trace.expect)
            wrong = describe(reported, mismatches)
            if rejected == "info":
                # on the bench an earlier run may have left the line idle
                results.append(("INFO", what + (wrong[0] if wrong else "read as expected")))
            elif rejected and rejected.matches(mismatches):
                results.append(("XFAIL", what + "%s (%s)" % (
                    rejected.why, describe([], mismatches)[0])))
            elif rejected:
                results.append(("FAIL", what + "refused otherwise than as recorded, %s: %s"
                                % (rejected.why, "\n  ".join(wrong) or "read as expected")))
            else:
                results.append(("FAIL", what + "\n  ".join(wrong)) if wrong else (
                    "PASS", what + "%d lines, %s" % (lines, " ".join(decoders))))
        for tooth in [] if args.capture else trace.teeth:
            what, capture, decoders, _ = captures(trace, args, scratch, tooth)[-1]
            wrong = describe(*judge(capture, decoders, trace.expect))
            tooth = " ".join(tooth)
            results.append(("TOOTH", "%s refused: %s" % (tooth, wrong[0])) if wrong else (
                "MISSED", "sigrok read it as expected after " + tooth))
    for verdict, text in results:
        print("%s %s: %s" % (verdict, trace.name, text))
    return all(verdict in ("PASS", "XFAIL", "TOOTH", "INFO") for verdict, _ in results)


def write_capture(trace, args):
    """The trace as the bench's analyser would capture it, on its channels."""
    pins = {channel: pin for pin, channel in dict(BENCH, **dict(args.probe)).items()}
    channels = [pins.get("D%d" % i) for i in range(8)]
    rate, samples = sample(pack([trace.wire(p) if p else None for p in channels]),
                           trace.clock, args)
    sigrok.write(args.write_capture, rate, samples)
    print("%s: %s, %d samples at %g MHz" % (trace.name, args.write_capture, len(samples),
                                            rate / 1e6))
    return True


def host_frames(trace, path, clock_mhz):
    """The host's SPI frames, each with the gap before it, for demo/pico_replay.py."""
    if trace.clock != clock_mhz * 1e6:
        raise SystemExit("%s runs at %g MHz and the bench at %g: its host words would be off"
                         % (trace.name, trace.clock / 1e6, clock_mhz))
    sck, mosi, cs_n = (trace.column(0, bit) for bit in range(3))
    frames, frame, byte, bits, end, start = [], None, 0, 0, 0, 0
    for i in range(1, len(sck)):
        if cs_n[i - 1] and not cs_n[i]:
            frame, byte, bits, start = bytearray(), 0, 0, i
        elif frame is not None and not cs_n[i - 1] and cs_n[i]:
            frames.append((round((start - end) / clock_mhz), bytes(frame)))
            frame, end = None, i
        elif frame is not None and not sck[i - 1] and sck[i]:
            byte, bits = (byte << 1) | mosi[i], bits + 1
            if bits == 8:
                frame.append(byte)
                byte, bits = 0, 0
    with open(path, "w") as f:
        f.write("# The host's frames of %s.trace, from demo/decode.py: the gap before each\n"
                "# in us at %g MHz, and its bytes.\nFRAMES = [\n" % (trace.name, clock_mhz))
        for gap, data in frames:
            f.write("    (%d, %r),\n" % (gap, data))
        f.write("]\n")
    print("%s: %d frames in %s" % (trace.name, len(frames), path))
    return True


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("traces", nargs="+")
    parser.add_argument("--rate", type=float, help="sample as an analyser at this rate, MHz")
    parser.add_argument("--ppm", type=float, default=30.0, help="most crystal error, either way")
    parser.add_argument("--seed", type=int, default=0)
    parser.add_argument("--capture", help="judge this capture from the bench instead")
    parser.add_argument("--probe", type=lambda s: tuple(s.split("=")), action="append",
                        default=[], help="PIN=Dn, a pin on another channel of the analyser")
    parser.add_argument("--write-capture", help="write the trace as the bench's analyser sees it")
    parser.add_argument("--host-frames", help="write the trace's host frames for the Pico")
    parser.add_argument("--clock-mhz", type=float, default=48.0, help="the bench's chip clock")
    args = parser.parse_args()
    results = [check(path, args) for path in args.traces]
    sys.exit(0 if all(results) else 1)


if __name__ == "__main__":
    main()
