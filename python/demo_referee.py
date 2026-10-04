# SPDX-License-Identifier: Apache-2.0
# Cheat the referee (MicroPython, Pico A): demo_self_check's frames on wire 20, and a press
# of BOOTSEL makes the next restart's bit period a cycle long or short. Engine 1 catches it
# and halts, is reloaded as the SK6812 driver to light the score on the stick on OUT0, so
# after the catch and not with it, then is the referee again. demo/referee.sh runs it.

import bench
import demo_neopixel
import demo_self_check as check
import protocol_emulator as pe

# pico_board.PicoSpi's rate, which the self-check runs at
HOST_HZ = 6_000_000
MHZ = 48
RED = (0x20, 0x00, 0x00)
GREEN = (0x00, 0x20, 0x00)
OFF = (0x00, 0x00, 0x00)
PIXELS = 8
# a green sweep each time this many honest frames have passed, each step held this long
SWEEP_EVERY = 256
SWEEP_MS = 40
# a press's cheat, in turn
PRESSES = (1, -1)
# BOOTSEL is read every POLL_MS and seven honest frames go out every RESTART_EVERY reads,
# so a sweep comes about every 4 s
POLL_MS = 10
RESTART_EVERY = 10
FRAMES = 7
# the auto mode's cheats, in turn, the honest frames before each, so one sweep comes in
# the run, and how long each catch's score shows
AUTO = (1, -1, 2, -2)
AUTO_CHEATS = 8
AUTO_FRAMES = 35
LINGER_MS = 150


def score(caught):
    """A red pixel a catch, from the first, starting over after a full stick."""
    lit = (caught - 1) % PIXELS + 1 if caught else 0
    return [RED] * lit + [OFF] * (PIXELS - lit)


def sweep():
    return [[GREEN] * (n + 1) + [OFF] * (PIXELS - 1 - n) for n in range(PIXELS)]


class Referee:
    """The self-check set up, and the score: rate(hz) sets Pico A's SPI clock."""

    def __init__(self, transfer, rate, pause_ms, log=print, sweep_every=SWEEP_EVERY,
                 sweep_ms=SWEEP_MS):
        self.host = pe.Host(transfer)
        self.rate = rate
        self.pause_ms = pause_ms
        self.log = log
        self.sweep_every = sweep_every
        self.sweep_ms = sweep_ms
        self.you = 0
        self.caught = 0
        self.honest = 0
        self.cleaner = check.words("scrub")
        self.rows, self.program, self.track, self.edges = check.begin(self.host, log)

    def frames(self, count=FRAMES):
        """count honest frames: whether engine 1 checked them all with no alarm."""
        sent, s, pc = check.send(self.host, count, self.track, first=self.honest)
        before = self.honest
        self.honest += sent
        if s & 3 or pc != self.track:
            self.log("ALARM on honest frames: engine 1 status 0x%04x pc %d" % (s, pc))
            return False
        if self.honest // self.sweep_every > before // self.sweep_every:
            self.log("%d honest frames, no alarm: green sweep" % self.honest)
            self.show(sweep() + [score(self.caught)], self.sweep_ms)
        return True

    def cheat(self, slip):
        """One frame with the bit period slip cycles off: whether engine 1 caught it."""
        period = check.PERIOD + slip
        due = check.moves(check.GLITCH_BYTE, check.PERIOD)[0]
        moved, at = check.caught_by(self.edges, check.GLITCH_BYTE, period)
        s, pc = check.glitch(self.host, period)
        caught = s & 3 == 3
        if caught:
            self.caught += 1
            self.log("caught: 0x%02x's start bit ended at cycle %d, rows say %d (%d ns %s), "
                     "the rows put the catch at cycle %d" % (
                         check.GLITCH_BYTE, moved, due, (abs(slip) * 1000 + MHZ // 2) // MHZ,
                         "late" if slip > 0 else "early", at))
            self.show([score(self.caught)])
        else:
            self.you += 1
            self.log("slipped past at %d cycles a bit: engine 1 status 0x%04x pc %d" % (
                period, s, pc))
            check.setup(self.host, self.rows, self.program)
        self.log("you %d, referee %d" % (self.you, self.caught))
        return caught

    def show(self, frames, hold_ms=demo_neopixel.LATCH_MS):
        """Engine 1, halted, drives the stick at its SPI rate, then is scrubbed, and setup
        reloads the rows and the checker while both are halted, as the theorem assumes."""
        self.rate(demo_neopixel.SPI_HZ)
        demo_neopixel.show(self.host, frames, self.pause_ms, engine=1, hold_ms=hold_ms)
        self.rate(HOST_HZ)
        scrub(self.host, self.cleaner)
        check.setup(self.host, self.rows, self.program)

    def faults(self):
        found = check.faults(self.host)
        self.log("faults %s" % found)
        return any(found)


def scrub(host, program, polls=100):
    """The selected engine runs program, scrub.hex, under the config it has, which must
    not autopull: the SK6812 firmware leaves osr's count at 8, and the checker would shift
    its first row from what is left. A start clears neither."""
    host.stop()
    host.load(program)
    host.start()
    for _ in range(polls):
        if host.read(pe.STATUS)[0] & 1:
            return
    raise RuntimeError("scrub never halted")


def button(read):
    """True once for each press of read's button."""
    held = [False]

    def pressed():
        now = bool(read())
        new = now and not held[0]
        held[0] = now
        return new

    return pressed


def play(referee, pressed, poll, restart_every=RESTART_EVERY, rounds=None):
    """Honest frames, and a cheat for each press, until an honest frame raises an alarm or
    rounds polls are done: whether none did. BOOTSEL is never read while the stick is lit."""
    cheats = 0
    tick = 0
    while rounds is None or tick < rounds:
        if pressed():
            referee.cheat(PRESSES[cheats % len(PRESSES)])
            cheats += 1
        elif tick % restart_every == 0 and not referee.frames():
            return False
        poll()
        tick += 1
    return True


def auto(referee, cheats=AUTO_CHEATS, frames=AUTO_FRAMES, linger_ms=LINGER_MS):
    """frames honest frames around each of AUTO's cheats in turn: whether all were caught,
    the honest frames raised no alarm and nothing faulted."""
    ok = True
    for n in range(cheats):
        ok = referee.frames(frames) and ok
        ok = referee.cheat(AUTO[n % len(AUTO)]) and ok
        if linger_ms:
            referee.pause_ms(linger_ms)
    ok = referee.frames(frames) and ok
    referee.log("slipped past: %d of %d" % (referee.you, cheats))
    return not referee.faults() and ok


def on_pico(log):
    import time

    import pico_board

    spi = pico_board.PicoSpi(baudrate=HOST_HZ)

    def rate(hz):
        spi.spi.init(baudrate=hz)

    return Referee(spi.transfer, rate, time.sleep_ms, log)


def main():
    """The game: a press of BOOTSEL cheats, Ctrl-C ends it."""
    import rp2
    import time

    referee = on_pico(print)
    print("press BOOTSEL to cheat")
    try:
        ok = play(referee, button(rp2.bootsel_button), lambda: time.sleep_ms(POLL_MS))
    except KeyboardInterrupt:
        ok = True
    print("you %d, referee %d, %d honest frames" % (referee.you, referee.caught, referee.honest))
    print("PASS" if not referee.faults() and ok else "FAIL")


if __name__ == "__main__":
    import time

    log = bench.Log()
    time.sleep_ms(bench.START_MS)
    bench.report(lambda: auto(on_pico(log)), log)
