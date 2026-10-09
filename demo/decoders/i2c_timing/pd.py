# SPDX-License-Identifier: Apache-2.0
# libsigrokdecode's face on timing.py. It reads SCL and SDA itself, not the i2c decoder's
# output, since the timing is between raw edges. Run beside -P i2c to see the bytes.

import sigrokdecode as srd

from .timing import MODES, SHEET, UNMEASURED, VERDICTS, Checker, limit


class SamplerateError(Exception):
    pass


class Decoder(srd.Decoder):
    api_version = 3
    id = "i2c_timing"
    name = "I²C timing"
    longname = "I²C timing against UM10204"
    desc = "Bus timing checked against the I²C specification's limits."
    license = "apache2"
    inputs = ["logic"]
    outputs = []
    tags = ["Embedded/industrial"]
    channels = (
        {"id": "scl", "name": "SCL", "desc": "Serial clock line"},
        {"id": "sda", "name": "SDA", "desc": "Serial data line"},
    )
    options = (
        {"id": "mode", "desc": "Speed mode", "default": "standard", "values": MODES},
    )
    annotations = (
        ("pass", "Pass"),
        ("fail", "Violation"),
        ("unsure", "Within a sample of the limit"),
        ("note", "Note"),
    )
    annotation_rows = (
        ("fails", "Violations", (1,)),
        ("unsures", "Can't tell", (2,)),
        ("passes", "Passes", (0,)),
        ("notes", "Notes", (3,)),
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

    def decode(self):
        if not self.rate:
            raise SamplerateError("Cannot decode without samplerate.")
        mode = self.options["mode"]
        checker = Checker(self.rate, mode)
        unmeasured = ", ".join(
            "%s at most %d ns" % (p, limit(p, mode)[1]) for p in UNMEASURED)
        self.put(0, 0, self.out_ann, [3, [
            "%s, %s: %s not measured, one logic threshold" % (SHEET, mode, unmeasured),
            "tr, tf not measured"]])
        scl, sda = self.wait()
        checker.edge(self.samplenum, scl, sda)
        while True:
            scl, sda = self.wait([{0: "e"}, {1: "e"}])
            for r in checker.edge(self.samplenum, scl, sda):
                cls = VERDICTS.index(r.verdict)
                self.put(r.ss, r.es, self.out_ann, [cls, [r.text, r.parameter]])
