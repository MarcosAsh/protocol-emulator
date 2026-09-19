# SPDX-License-Identifier: Apache-2.0
# Transport for the Tiny Tapeout demo board (MicroPython, ttboard).

from ttboard.demoboard import DemoBoard
from ttboard.mode import RPMode

from protocol_emulator import Host

SCK, MOSI, CS_N = 0, 1, 2


class DemoBoardSpi:
    def __init__(self, project="tt_um_marcosash_protocol_emulator", clock_hz=10_000_000):
        self.tt = DemoBoard.get()
        getattr(self.tt.shuttle, project).enable()
        self.tt.mode = RPMode.ASIC_RP_CONTROL
        self.tt.clock_project_PWM(clock_hz)
        self.ui = 1 << CS_N
        self.tt.ui_in.value = self.ui

    def _set(self, bit, level):
        self.ui = (self.ui | (1 << bit)) if level else (self.ui & ~(1 << bit))
        self.tt.ui_in.value = self.ui

    def _byte(self, out):
        acc = 0
        for b in range(7, -1, -1):
            self._set(MOSI, (out >> b) & 1)
            acc = (acc << 1) | (int(self.tt.uo_out.value) & 1)
            self._set(SCK, 1)
            self._set(SCK, 0)
        return acc

    def transfer(self, data):
        self._set(CS_N, 0)
        replies = [self._byte(b) for b in data]
        self._set(CS_N, 1)
        return replies


def host(**kwargs):
    return Host(DemoBoardSpi(**kwargs).transfer)
