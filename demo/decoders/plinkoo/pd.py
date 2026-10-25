# SPDX-License-Identifier: Apache-2.0
# PLK-2 Plinkoo Two-Wire Packet Bus revision 1.3, sections 4 and 5 and notes 1 and 3. A
# low of STB past 1 us is a sync; DAT is taken at each rise after it. A bit period off
# tSYN/16 by more than 6 %, or DAT moving inside tDS or tDH of a rise, is a warning.

import sigrokdecode as srd

SYNC = (4.8e-6, 5.2e-6)
TDS = 120e-9
TDH = 80e-9


class SamplerateError(Exception):
    pass


class Decoder(srd.Decoder):
    api_version = 3
    id = "plinkoo"
    name = "Plinkoo"
    longname = "Plinkoo two-wire packet bus (PLK-2)"
    desc = "Strobe and open-drain data: sync, length, payload, checksum, ack."
    license = "apache2"
    inputs = ["logic"]
    outputs = []
    tags = ["Embedded/industrial"]
    channels = (
        {"id": "stb", "name": "STB", "desc": "Strobe, idles high"},
        {"id": "dat", "name": "DAT", "desc": "Data, open-drain, idles high"},
    )
    annotations = (
        ("sync", "Sync"),
        ("bit", "Bit"),
        ("length", "Length"),
        ("byte", "Byte"),
        ("checksum-ok", "Checksum OK"),
        ("checksum-err", "Checksum error"),
        ("ack", "ACK"),
        ("nack", "NACK"),
        ("timing-warn", "Timing out of spec"),
    )
    annotation_rows = (
        ("bits", "Bits", (0, 1)),
        ("bytes", "Bytes", (2, 3, 4, 5, 6, 7)),
        ("warnings", "Warnings", (8,)),
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

    def warn(self, ss, es, text):
        self.put(ss, es, self.out_ann, [8, [text]])

    def decode(self):
        if not self.rate:
            raise SamplerateError("Cannot decode without samplerate.")
        sample = 1 / self.rate
        bit = None
        bits, starts, length = [], [], None
        last_rise, dat_moved = None, None
        dat = 1
        self.wait({0: "h"})
        while True:
            # an edge of either pin
            stb, now_dat = self.wait([{0: "e"}, {1: "e"}])
            if now_dat != dat:
                dat = now_dat
                if last_rise is not None and bit is not None:
                    held = (self.samplenum - last_rise) / self.rate
                    if held < TDH - sample:
                        self.warn(last_rise, self.samplenum, "tDH %.0f ns" % (held * 1e9))
                dat_moved = self.samplenum
            if not self.matched[0]:
                continue
            if stb == 0:
                fall = self.samplenum
                continue
            rise = self.samplenum
            low = (rise - fall) / self.rate
            if low >= 1e-6:
                if not SYNC[0] - sample <= low <= SYNC[1] + sample:
                    self.warn(fall, rise, "tSYN %.3f us" % (low * 1e6))
                self.put(fall, rise, self.out_ann, [0, ["Sync", "S"]])
                bit = low / 16
                bits, starts, length, last_rise = [], [], None, None
                continue
            if bit is None:
                continue
            if last_rise is not None:
                period = (rise - last_rise) / self.rate
                if abs(period - bit) > 0.06 * bit + sample:
                    self.warn(last_rise, rise, "tB %.1f ns" % (period * 1e9))
            if dat_moved is not None and (rise - dat_moved) / self.rate < TDS - sample:
                self.warn(dat_moved, rise, "tDS %.0f ns" % ((rise - dat_moved) / self.rate * 1e9))
            last_rise = rise
            if length is not None and len(bits) == 8 * (length + 2):
                if dat == 0:
                    self.put(fall, rise, self.out_ann, [6, ["ACK", "A"]])
                else:
                    self.put(fall, rise, self.out_ann, [7, ["NACK", "N"]])
                bit = None
                continue
            self.put(fall, rise, self.out_ann, [1, ["%d" % dat]])
            bits.append(dat)
            starts.append(fall)
            if len(bits) % 8:
                continue
            byte = 0
            for b in bits[-8:]:
                byte = (byte << 1) | b
            ss = starts[-8]
            if length is None:
                if not 1 <= byte <= 8:
                    self.warn(ss, rise, "Length %d" % byte)
                    bit = None
                    continue
                length = byte
                self.put(ss, rise, self.out_ann, [2, ["Length %d" % byte, "L"]])
            elif len(bits) < 8 * (length + 2):
                self.put(ss, rise, self.out_ann, [3, ["%02X" % byte]])
            else:
                total = 0
                for i in range(0, len(bits), 8):
                    v = 0
                    for b in bits[i:i + 8]:
                        v = (v << 1) | b
                    total += v
                if total % 256 == 0:
                    self.put(ss, rise, self.out_ann, [4, ["Checksum OK", "C"]])
                else:
                    self.put(ss, rise, self.out_ann, [5, ["Checksum error", "CE"]])
