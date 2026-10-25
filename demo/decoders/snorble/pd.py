# SPDX-License-Identifier: Apache-2.0
# SNB-1 Snorble Sensor Beacon Rev. C, section 4 (p.1) and notes 1 and 3 (p.2). A low past
# 5 us is a sync, between tL1's max and tSYN's min; a bit is a one past 2.1 us, between
# tL0's max and tL1's min. A width outside its limit by more than a sample is a warning.

import sigrokdecode as srd

# seconds, min and max
SYNC = (7.5e-6, 8.5e-6)
ZERO = (1.10e-6, 1.30e-6)
ONE = (2.90e-6, 3.10e-6)
GAP = (1.8e-6, 4.0e-6)
IDLE = 20e-6


class SamplerateError(Exception):
    pass


class Decoder(srd.Decoder):
    api_version = 3
    id = "snorble"
    name = "Snorble"
    longname = "Snorble sensor beacon (SNB-1)"
    desc = "Single-wire pulse-width link: sync, eight bits MSB first, odd parity."
    license = "apache2"
    inputs = ["logic"]
    outputs = []
    tags = ["Embedded/industrial"]
    channels = ({"id": "sig", "name": "SIG", "desc": "Signal wire, idles high"},)
    annotations = (
        ("sync", "Sync"),
        ("bit", "Bit"),
        ("byte", "Byte"),
        ("parity-ok", "Parity OK"),
        ("parity-err", "Parity error"),
        ("timing-warn", "Timing out of spec"),
    )
    annotation_rows = (
        ("bits", "Bits", (0, 1)),
        ("bytes", "Bytes", (2, 3, 4)),
        ("warnings", "Warnings", (5,)),
    )

    def __init__(self):
        self.reset()

    def reset(self):
        self.rate = None

    def metadata(self, key, value):
        if key == srd.SRD_CONF_SAMPLERATE:
            self.rate = value

    def start(self):
        self.out_ann = self.register(srd.OUTPUT_ANN)

    def check(self, ss, es, name, width, bounds):
        low, high = bounds
        sample = 1 / self.rate
        if width < low - sample or (high is not None and width > high + sample):
            self.put(ss, es, self.out_ann, [5, ["%s %.3f us" % (name, width * 1e6)]])

    def decode(self):
        if not self.rate:
            raise SamplerateError("Cannot decode without samplerate.")
        bits, starts, rise, frame_end = [], [], None, None
        self.wait({0: "h"})
        while True:
            self.wait({0: "f"})
            fall = self.samplenum
            if rise is not None and bits and len(bits) < 9:
                self.check(rise, fall, "tH", (fall - rise) / self.rate, GAP)
            if frame_end is not None and not bits:
                self.check(frame_end, fall, "tIFG", (fall - frame_end) / self.rate, (IDLE, None))
            self.wait({0: "r"})
            rise = self.samplenum
            width = (rise - fall) / self.rate
            if width >= 5e-6:
                self.check(fall, rise, "tSYN", width, SYNC)
                self.put(fall, rise, self.out_ann, [0, ["Sync", "S"]])
                bits, starts = [], []
                continue
            one = width >= 2.1e-6
            self.check(fall, rise, "tL1" if one else "tL0", width, ONE if one else ZERO)
            self.put(fall, rise, self.out_ann, [1, ["%d" % one]])
            bits.append(int(one))
            starts.append(fall)
            if len(bits) == 8:
                byte = 0
                for b in bits:
                    byte = (byte << 1) | b
                self.put(starts[0], rise, self.out_ann, [2, ["%02X" % byte]])
            elif len(bits) == 9:
                if sum(bits) % 2 == 1:
                    self.put(fall, rise, self.out_ann, [3, ["Parity OK", "P"]])
                else:
                    self.put(fall, rise, self.out_ann, [4, ["Parity error", "PE"]])
                bits, starts, frame_end = [], [], rise
