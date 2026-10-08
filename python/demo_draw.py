# SPDX-License-Identifier: Apache-2.0
# Act 3's mouse draws the die (MicroPython). demo/draw.py writes draw.bin, a byte of seconds
# to wait once the laptop has configured the chip, then three bytes a report: buttons, dx,
# dy. This serves them through demo_usb.serve on Pico A while engine 1 sends each report's
# three bytes, once taken, to pico_listener. Ctrl-C on the console releases the button, and
# how that went is left in `ended` for demo/draw.py to read back.

import time

import demo_usb
import usb_board

MOUSE = 2
LIMIT = 127
# how long the laptop has after a Ctrl-C to take the reports already handed out
RELEASE_MS = 1000
# how often the console is checked for a Ctrl-C
POLL_MS = 20

ticks_diff = getattr(time, "ticks_diff", lambda a, b: a - b)


def line(dx, dy, buttons):
    """(buttons, dx, dy) steps along a move, each within LIMIT and each point the nearest
    to the line, the deltas as bytes."""
    n = max(1, (max(abs(dx), abs(dy)) + LIMIT - 1) // LIMIT)
    steps, x, y = [], 0, 0
    for i in range(1, n + 1):
        # the nearest integer, halves up
        nx, ny = (2 * dx * i + n) // (2 * n), (2 * dy * i + n) // (2 * n)
        steps.append((buttons, (nx - x) & 0xFF, (ny - y) & 0xFF))
        x, y = nx, ny
    return steps


def encode(strokes, wait_s):
    """draw.bin for strokes, polylines in pixels from where the pointer starts: a move to
    each with the button up, a press, its segments with it held, a release, and a move
    back to the start at the end."""
    steps, pen = [], (0, 0)
    for stroke in strokes:
        if stroke[0] != pen:
            steps += line(stroke[0][0] - pen[0], stroke[0][1] - pen[1], 0)
        steps.append((1, 0, 0))
        for a, b in zip(stroke, stroke[1:]):
            steps += line(b[0] - a[0], b[1] - a[1], 1)
        steps.append((0, 0, 0))
        pen = stroke[-1]
    if pen != (0, 0):
        steps += line(-pen[0], -pen[1], 0)
    return bytes([wait_s] + [b for step in steps for b in step])


def signed(byte):
    return byte - 256 if byte > 127 else byte


class Reports:
    """demo_usb.serve's queue over draw.bin's reports. Empty until `start`, and the reports
    serve puts back come out first. `stop` drops the rest, but for a release if the last
    report handed out held a button."""

    def __init__(self, data, ms):
        self.data, self.ms = data, ms
        self.at, self.back, self.start_ms, self.held, self.stopped = 1, [], None, 0, False

    def __len__(self):
        if self.start_ms is None or ticks_diff(self.ms(), self.start_ms) < 0:
            return 0
        return len(self.back) + (len(self.data) - self.at) // 3

    def __bool__(self):
        return len(self) > 0

    def start(self, wait_ms):
        if self.start_ms is None:
            self.start_ms = self.ms() + wait_ms

    def pop(self, index=0):
        if self.back:
            report = self.back.pop(0)
        else:
            report = [MOUSE] + list(self.data[self.at:self.at + 3])
            self.at += 3
        self.held = report[1]
        return report

    def insert(self, index, report):
        self.back.insert(0, report)

    def stop(self):
        self.at, self.stopped = len(self.data), True
        if self.held:
            self.back = [[MOUSE, 0, 0, 0]]
        self.start_ms = self.ms()


class Stopped(Exception):
    """Ends `serve` at the top of a round; args[0] is whether the laptop took everything."""


def stopping(bus_reset, board, queue, interrupted, ms):
    """bus_reset for serve that also ends it once interrupted(): when the laptop has taken
    every report handed out, the release included, or after RELEASE_MS."""
    since, polled = None, None

    def check():
        nonlocal since, polled
        now = ms()
        if since is None and (polled is None or ticks_diff(now, polled) >= POLL_MS):
            polled = now
            if interrupted():
                since = now
                queue.stop()
        if since is not None:
            taken = not queue and board.pending_report is None
            if taken or ticks_diff(now, since) > RELEASE_MS:
                raise Stopped(taken)
        return bus_reset()

    return check


def console_ctrl_c():
    """True once a Ctrl-C has come in on the console, which kbd_intr(-1) leaves to stdin."""
    import select
    import sys

    poll = select.poll()
    poll.register(sys.stdin, select.POLLIN)
    seen = [False]

    def interrupted():
        while not seen[0] and poll.poll(0):
            c = sys.stdin.read(1)
            if not c:
                break
            seen[0] = c == "\x03"
        return seen[0]

    return interrupted


def logger(host, queue, total, ms, say):
    """Engine 1 sends each report's three bytes once the laptop has taken it, and the
    console hears when drawing starts and ends."""
    taken, first = [0], [None]

    def log(report):
        host.select(1)
        host.push(report[1:])
        host.select(0)
        taken[0] += 1
        if taken[0] == 1:
            first[0] = ms()
            say("drawing %d reports" % total)
        if taken[0] == total and not queue.stopped:
            say("drew %d reports in %d ms; Ctrl-C to stop"
                % (total, ticks_diff(ms(), first[0])))

    return log


def run(path="draw.bin", say=print):
    """On the Icepi Zero, from the host Pico, with draw.bin beside this. Returns what it
    said on stopping."""
    import micropython

    with open(path, "rb") as f:
        data = f.read()
    ms = time.ticks_ms
    queue = Reports(data, ms)
    host, bus_reset, attach, replug = demo_usb.pico_a()
    demo_usb.start_log(
        host, demo_usb.words("uart_tx_host_rate"), demo_usb.words("uart_tx_host_rate.cert"))
    board = usb_board.Board(demo_usb.DESCRIPTORS)

    def said(text):
        if text == "configured":
            queue.start(data[0] * 1000)
            text += ": drawing in %d s, the pointer on the canvas's top left" % data[0]
        say(text)

    log = logger(host, queue, (len(data) - 1) // 3, ms, say)
    check = stopping(bus_reset, board, queue, console_ctrl_c(), ms)
    micropython.kbd_intr(-1)
    try:
        demo_usb.serve(host, board, queue, check, log, said, attach, replug)
    except Stopped as stopped:
        ended = ("stopped, button up" if stopped.args[0] else
                 "stopped before the laptop took the last report: if the button is still"
                 " down, unplug the Icepi's first USB port")
        say(ended)
        return ended
    finally:
        micropython.kbd_intr(3)


if __name__ == "__main__":
    ended = run()
