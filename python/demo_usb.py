# SPDX-License-Identifier: Apache-2.0
# A USB keyboard and mouse on the Tiny Tapeout demo board (MicroPython, ttboard).
# D+ is uio[0], D- is uio[1], with a 1.5 k pull-up from D- to 3.3 V as low speed asks.
# Untested until the board is here; test/test_usb_board.py runs the same Board and the
# same firmware through the RTL, the gates and the FPGA netlist.

import time

import demo_board
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

KEYS = {c: 4 + i for i, c in enumerate("abcdefghijklmnopqrstuvwxyz")}
KEYS[" "] = 0x2C


def run(text="hello jane street ", clock_hz=48_000_000):
    spi = demo_board.DemoBoardSpi(clock_hz=clock_hz)
    host = demo_board.Host(spi.transfer)
    board = usb_board.Board({1: DEVICE, 2: CONFIGURATION, 0x22: REPORT})
    queue, se0_since = [], None
    for c in text:
        queue += [[1, 0, KEYS[c], 0, 0, 0, 0, 0], [1, 0, 0, 0, 0, 0, 0, 0], [2, 0, 3, 0]]
    while True:
        # the board sits on the same two pins: 2.5 ms of SE0 is a bus reset
        if int(spi.tt.uio_out.value) & 3 == 0:
            se0_since = se0_since or time.ticks_ms()
            if time.ticks_diff(time.ticks_ms(), se0_since) > 2:
                board.reset()
        else:
            se0_since = None
        usb_board.service(host, board)
        if queue and board.pending_report is None and not board.chunks:
            board.report(queue.pop(0))
