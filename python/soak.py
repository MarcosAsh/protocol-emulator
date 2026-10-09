# SPDX-License-Identifier: Apache-2.0
# The self-check unattended as Pico A's main.py, the chip booting from flash: quiet frames
# for ever, and every GLITCH_S the restart a cycle long and a cycle short, each of which must
# raise the alarm. A line a LOG_S to soak.log, rolled to soak.1.log past LOG_BYTES. The LED
# blinks slowly while every check holds, fast once one has not.

import time

import machine

import demo_self_check as sc
import protocol_emulator as pe
from pico_board import PicoSpi

LOG = "soak.log"
OLD_LOG = "soak.1.log"
LOG_BYTES = 32_768
GLITCH_S = 3600
LOG_S = 3600
# restarts between looks at the clock
BATCH = 70
# the chip's flash load and PLL lock, with margin
BOOT_MS = 3000
# errors logged an hour at most, so a stuck chip cannot fill the flash
ERRORS_PER_LOG = 8


def edges_per_frame(byte):
    """The start bit's fall and each move after it."""
    return 1 + len(sc.moves(byte, sc.PERIOD))


class Soak:
    def __init__(self, glitch_s=GLITCH_S, log_s=LOG_S, log_bytes=LOG_BYTES):
        self.glitch_s, self.log_s, self.log_bytes = glitch_s, log_s, log_bytes
        self.frames = self.edges = self.false_alarms = self.not_checking = 0
        self.injected = self.caught = self.errors = self.logged_errors = 0
        self.start = time.time()
        self.edge_table = [edges_per_frame(b) for b in range(256)]
        self.led = machine.Pin("LED", machine.Pin.OUT)
        self.ok = True

    def write(self, line):
        try:
            import os

            if os.stat(LOG)[6] > self.log_bytes:
                try:
                    os.remove(OLD_LOG)
                except OSError:
                    pass
                os.rename(LOG, OLD_LOG)
        except OSError:
            pass
        with open(LOG, "a") as f:
            f.write(line + "\n")

    def elapsed_s(self):
        return time.time() - self.start

    def counts(self):
        return "frames %d edges %d false_alarms %d not_checking %d injected %d caught %d errors %d" % (
            self.frames, self.edges, self.false_alarms, self.not_checking, self.injected,
            self.caught, self.errors)

    def error(self, what):
        self.errors += 1
        self.ok = False
        if self.logged_errors < ERRORS_PER_LOG:
            self.logged_errors += 1
            self.write("%7d s error %s" % (self.elapsed_s(), what))

    def setup(self, host):
        _, _, self.track, self.edge_rows = sc.begin(host, log=lambda _: None)

    def quiet(self, host, first):
        """BATCH restarts of seven frames; a restart that ends in an alarm or with the
        checker off its wait counts, and the checker is armed again."""
        sent, s, pc = sc.send(host, 7 * BATCH, self.track, first=first)
        for i in range(sent):
            self.edges += self.edge_table[(first + i) & 0xFF]
        self.frames += sent
        if s & 3:
            self.false_alarms += 1
            self.ok = False
            self.write("%7d s FALSE ALARM engine 1 status 0x%04x pc %d" % (self.elapsed_s(), s, pc))
            sc.arm(host)
        elif pc != self.track:
            self.not_checking += 1
            self.ok = False
            self.write("%7d s NOT CHECKING engine 1 at pc %d" % (self.elapsed_s(), pc))
            sc.arm(host)
        return (first + sent) & 0xFF

    def inject(self, host):
        """The restart a cycle long, then a cycle short: each must halt the checker with its
        irq up. Then armed again on the high line."""
        got = []
        for period in sc.GLITCHES:
            s, pc = sc.glitch(host, period)
            self.injected += 1
            caught = s & 3 == 3
            self.caught += caught
            got.append("%d:%s" % (period, "caught" if caught else "MISSED 0x%04x pc %d" % (s, pc)))
            if not caught:
                self.ok = False
        sc.arm(host)
        self.write("%7d s injected %s" % (self.elapsed_s(), " ".join(got)))

    def run(self, until_s=None):
        time.sleep_ms(BOOT_MS)
        spi = PicoSpi()
        host = pe.Host(spi.transfer)
        self.write("%7d s boot reset_cause %d" % (0, machine.reset_cause()))
        try:
            self.setup(host)
        except Exception as e:
            self.write("%7d s setup failed: %s" % (self.elapsed_s(), e))
            return self.blink_forever()
        self.inject(host)
        next_glitch = self.glitch_s
        next_log = self.log_s
        first = 0
        blink = 0
        while until_s is None or self.elapsed_s() < until_s:
            try:
                first = self.quiet(host, first)
                now = self.elapsed_s()
                if now >= next_glitch:
                    self.inject(host)
                    next_glitch += self.glitch_s
                if now >= next_log:
                    found = sc.faults(host)
                    self.write("%7d s %s faults %x %x" % ((now, self.counts()) + tuple(found)))
                    if any(found):
                        self.ok = False
                    self.logged_errors = 0
                    next_log += self.log_s
            except Exception as e:
                self.error(repr(e))
                try:
                    host.select(0)
                    host.stop()
                    self.setup(host)
                except Exception as again:
                    self.error("setup again: %r" % again)
                    time.sleep_ms(1000)
            blink += 1
            self.led.value((blink & 1) if not self.ok else (blink // 8) & 1)
        self.write("%7d s end %s" % (self.elapsed_s(), self.counts()))

    def blink_forever(self):
        while True:
            self.led.toggle()
            time.sleep_ms(100)


if __name__ == "__main__":
    Soak().run()
