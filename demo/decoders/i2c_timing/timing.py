# SPDX-License-Identifier: Apache-2.0
# I2C bus timing against UM10204, from the edges of a logic capture. Times are taken where
# the analyser's one threshold is crossed, not at 0.3 and 0.7 VDD, so tr and tf cannot be
# measured. Each edge is late by under a sample, so a time is good to +-1 sample: it fails
# only if it fails with that slack, and passes only if it passes with it.

import collections
from fractions import Fraction

SHEET = "UM10204 Rev. 7.0, 1 October 2021, Table 11, p. 44"
MODES = ("standard", "fast", "fastplus")

# (parameter, kind, Standard-mode, Fast-mode, Fast-mode Plus), in kHz for fSCL and ns for
# the rest. tHD;DAT's least is the I2C-bus devices' row, not CBUS's.
LIMITS = [
    ("fSCL", "at_most", 100, 400, 1_000),
    ("tHD;STA", "at_least", 4_000, 600, 260),
    ("tLOW", "at_least", 4_700, 1_300, 500),
    ("tHIGH", "at_least", 4_000, 600, 260),
    ("tSU;STA", "at_least", 4_700, 600, 260),
    ("tHD;DAT", "at_least", 0, 0, 0),
    ("tSU;DAT", "at_least", 250, 100, 50),
    ("tr", "at_most", 1_000, 300, 120),
    ("tf", "at_most", 300, 300, 120),
    ("tSU;STO", "at_least", 4_000, 600, 260),
    ("tBUF", "at_least", 4_700, 1_300, 500),
]

# What one threshold cannot measure: both cross it once, wherever it sits between 0.3 and
# 0.7 VDD.
UNMEASURED = ("tr", "tf")

VERDICTS = ("pass", "fail", "unsure")

# value: fSCL's in kHz, the rest in ns
Result = collections.namedtuple("Result", "parameter ss es verdict value text")


def limit(parameter, mode):
    """The limit's kind and its value in [mode], in the table's unit."""
    for name, kind, *ns in LIMITS:
        if name == parameter:
            return kind, ns[MODES.index(mode)]
    raise KeyError(parameter)


class Checker:
    """Fed every change of SCL and SDA in order, it returns the parameters each completes.
    Nothing is judged outside START to STOP, so a capture may begin mid-transaction; [stray]
    counts the SCL edges there, which a stuck SDA leaves."""

    def __init__(self, rate_hz, mode):
        self.ns = Fraction(10**9) / Fraction(rate_hz)
        self.mode = mode
        self.scl = self.sda = None
        self.busy = False
        self.start = self.stop = self.rise = self.fall = None
        self.clean = False
        self.changes = []
        self.falls = []
        self.stray = 0

    def time(self, samples):
        return float(samples * self.ns)

    def judge(self, parameter, ss, es):
        _, least = limit(parameter, self.mode)
        d = es - ss
        if (d + 1) * self.ns < least:
            verdict = "fail"
        elif (d - 1) * self.ns >= least:
            verdict = "pass"
        else:
            verdict = "unsure"
        sign = {"fail": "<", "pass": ">=", "unsure": "~"}[verdict]
        ns = self.time(d)
        text = "%s %.0f ns %s %d ns" % (parameter, ns, sign, least)
        return Result(parameter, ss, es, verdict, ns, text)

    def clock(self):
        """fSCL on the transaction's SCL falls: a fail on the run of periods that is most
        provably fast, else a pass if their mean is provably slow enough."""
        falls, self.falls = self.falls, []
        if len(falls) < 2:
            return []
        _, khz = limit("fSCL", self.mode)
        period = Fraction(10**6, khz)
        worst, here, first, run = 0, 0, 0, None
        for i in range(1, len(falls)):
            if here > 0:
                here, first = 0, i - 1
            here += (falls[i] - falls[i - 1]) * self.ns - period
            if here < worst:
                worst, run = here, (first, i)
        if run is not None and worst + self.ns < 0:
            verdict = "fail"
        else:
            run = (0, len(falls) - 1)
            span = (falls[-1] - falls[0] - 1) * self.ns
            verdict = "pass" if span >= run[1] * period else "unsure"
        a, b = falls[run[0]], falls[run[1]]
        k = run[1] - run[0]
        sign = {"fail": ">", "pass": "<=", "unsure": "~"}[verdict]
        mean = k * 1e6 / self.time(b - a)
        shortest = min(falls[i] - falls[i - 1] for i in range(run[0] + 1, run[1] + 1))
        text = "fSCL %.3f kHz over %d periods %s %d kHz, shortest %.0f ns" % (
            mean, k, sign, khz, self.time(shortest))
        return [Result("fSCL", a, b, verdict, mean, text)]

    def edge(self, at, scl, sda):
        """The levels from sample [at] on. When both change in one sample, the SDA change
        is taken as data, not as a START or STOP."""
        if self.scl is None:
            self.scl, self.sda = scl, sda
            return []
        out = []
        if scl < self.scl:
            out += self._scl(at, scl)
        if sda != self.sda:
            out += self._sda(at, sda)
        if scl > self.scl:
            out += self._scl(at, scl)
        return out

    def finish(self):
        """What the end of the capture leaves: fSCL of a transaction with no STOP."""
        return self.clock()

    def _sda(self, at, sda):
        self.sda = sda
        out = []
        if not self.scl:
            if self.busy:
                self.changes.append(at)
        elif not sda:
            if self.busy and self.rise is not None:
                out.append(self.judge("tSU;STA", self.rise, at))
            elif not self.busy and self.stop is not None:
                out.append(self.judge("tBUF", self.stop, at))
            self.busy, self.start, self.clean = True, at, False
        else:
            if self.busy:
                if self.rise is not None:
                    out.append(self.judge("tSU;STO", self.rise, at))
                out += self.clock()
            self.busy, self.start, self.stop, self.clean = False, None, at, False
        return out

    def _scl(self, at, scl):
        self.scl = scl
        self.stray += not self.busy
        out = []
        if not scl:
            if self.busy:
                if self.start is not None:
                    out.append(self.judge("tHD;STA", self.start, at))
                elif self.clean and self.rise is not None:
                    out.append(self.judge("tHIGH", self.rise, at))
                self.falls.append(at)
            self.start, self.fall, self.changes = None, at, []
        else:
            if self.busy and self.fall is not None:
                out.append(self.judge("tLOW", self.fall, at))
                if self.changes:
                    out.append(self.judge("tHD;DAT", self.fall, self.changes[0]))
                    out.append(self.judge("tSU;DAT", self.changes[-1], at))
            self.rise, self.clean = at, True
        return out
