# SPDX-License-Identifier: Apache-2.0
# Act 3: a USB keyboard and mouse that types TEXT (MicroPython). D+ is uio[0], D- uio[1],
# pulled up from D- for low speed. On the Icepi Zero a Pico is the host over pico_board's
# pins and watches the bus on header 29 (D+) -> GP6 and 31 (D-) -> GP7; the TT demo board
# reads uio_out itself. Untested on a board; test/test_demo.py runs `serve` on the RTL.

import time

import usb_board

REPORT = [
    0x05, 0x01, 0x09, 0x06, 0xA1, 0x01, 0x85, 0x01, 0x05, 0x07, 0x19, 0xE0, 0x29, 0xE7,
    0x15, 0x00, 0x25, 0x01, 0x75, 0x01, 0x95, 0x08, 0x81, 0x02, 0x95, 0x06, 0x75, 0x08,
    0x15, 0x00, 0x25, 0x65, 0x05, 0x07, 0x19, 0x00, 0x29, 0x65, 0x81, 0x00, 0xC0,
    0x05, 0x01, 0x09, 0x02, 0xA1, 0x01, 0x85, 0x02, 0x09, 0x01, 0xA1, 0x00, 0x05, 0x09,
    0x19, 0x01, 0x29, 0x03, 0x15, 0x00, 0x25, 0x01, 0x95, 0x03, 0x75, 0x01, 0x81, 0x02,
    0x95, 0x01, 0x75, 0x05, 0x81, 0x03, 0x05, 0x01, 0x09, 0x30, 0x09, 0x31, 0x15, 0x81,
    0x25, 0x7F, 0x75, 0x08, 0x95, 0x02, 0x81, 0x06, 0xC0, 0xC0,
]
DEVICE = [18, 1, 0x10, 0x01, 0, 0, 0, 8, 0x09, 0x12, 0x01, 0x00, 0x00, 0x01, 0, 0, 0, 1]
CONFIGURATION = (
    [9, 2, 34, 0, 1, 1, 0, 0xA0, 50]
    + [9, 4, 0, 0, 1, 3, 0, 0, 0]
    + [9, 0x21, 0x11, 0x01, 0, 1, 0x22, len(REPORT) & 0xFF, len(REPORT) >> 8]
    + [7, 5, 0x81, 3, 8, 0, 10]
)

DESCRIPTORS = {1: DEVICE, 2: CONFIGURATION, 0x22: REPORT}

KEYS = {c: 4 + i for i, c in enumerate("abcdefghijklmnopqrstuvwxyz")}
KEYS[" "] = 0x2C


def reports(text):
    """Each character pressed, released, and the mouse three pixels to the right."""
    queue = []
    for c in text:
        queue += [[1, 0, KEYS[c], 0, 0, 0, 0, 0], [1, 0, 0, 0, 0, 0, 0, 0], [2, 0, 3, 0]]
    return queue


def se0_reset(lines, ms, least=2):
    """A bus_reset for `serve`. lines() is D+ | D- << 1 and ms() counts milliseconds: SE0
    held past `least` of them is a reset, where an EOP's is two bits."""
    since = None

    def bus_reset():
        nonlocal since
        if lines() & 3:
            since = None
            return False
        now = ms()
        since = now if since is None else since
        return now - since > least

    return bus_reset


def serve(host, board, queue, bus_reset):
    """Forever. Typing waits for an address, and a reset puts back the report it lost."""
    while True:
        if bus_reset():
            if board.pending_report is not None:
                queue.insert(0, board.pending_report)
            board.reset()
        usb_board.service(host, board)
        if queue and board.address and board.pending_report is None and not board.chunks:
            board.report(queue.pop(0))


def run(text="hello jane street "):
    """On the Icepi Zero, from the host Pico."""
    from machine import Pin

    import pico_board

    dp, dn = Pin(6, Pin.IN), Pin(7, Pin.IN)
    bus_reset = se0_reset(lambda: dp() | dn() << 1, time.ticks_ms)
    serve(pico_board.host(), usb_board.Board(DESCRIPTORS), reports(text), bus_reset)


def run_demo_board(text="hello jane street ", clock_hz=48_000_000):
    import demo_board

    spi = demo_board.DemoBoardSpi(clock_hz=clock_hz)
    bus_reset = se0_reset(lambda: int(spi.tt.uio_out.value), time.ticks_ms)
    host = demo_board.Host(spi.transfer)
    serve(host, usb_board.Board(DESCRIPTORS), reports(text), bus_reset)


if __name__ == "__main__":
    run()
