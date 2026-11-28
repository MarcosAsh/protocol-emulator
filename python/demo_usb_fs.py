# SPDX-License-Identifier: Apache-2.0
# The chip as a full speed USB device (MicroPython, Pico A). Engine 0 answers every packet
# itself from the data memory, with D+ on uio[0] and D- on uio[1], pulled up from D+ on the
# Icepi Zero built with FS=1. It is a vendor-defined HID device, so a host binds a driver
# but nothing types. Pico A is the host over pico_board's pins. It keeps the board detached
# from GP8 -> header 15 until engine 0 serves, and watches header 29 (D+) -> GP6 and
# 31 (D-) -> GP7 for a bus reset.

import time

import usb_fs_board

PRODUCT = "Protocol Emulator"
# usage page 0xFF00, eight bytes in
REPORT = [
    0x06, 0x00, 0xFF, 0x09, 0x01, 0xA1, 0x01, 0x15, 0x00, 0x26, 0xFF, 0x00, 0x75, 0x08,
    0x95, 0x08, 0x09, 0x01, 0x81, 0x02, 0xC0,
]
# USB 1.1, so nobody asks for a device qualifier; pid.codes' test VID and PID 2
DEVICE = [18, 1, 0x10, 0x01, 0, 0, 0, 8, 0x09, 0x12, 0x02, 0x00, 0x00, 0x02, 0, 1, 0, 1]
CONFIGURATION = (
    [9, 2, 34, 0, 1, 1, 0, 0x80, 50]
    + [9, 4, 0, 0, 1, 3, 0, 0, 0]
    + [9, 0x21, 0x11, 0x01, 0, 1, 0x22, len(REPORT), 0]
    + [7, 5, 0x81, 3, 8, 0, 1]
)


def string(text):
    return [2 + 2 * len(text), 3] + [b for c in text for b in (ord(c), 0)]


DESCRIPTORS = {
    (1, 0): DEVICE,
    (2, 0): CONFIGURATION,
    (3, 0): [4, 3, 0x09, 0x04],
    (3, 1): string(PRODUCT),
    (0x22, 0): REPORT,
}

# Pico A's pin to usb_detach (high releases D+'s pull-up), and how long the host sees no
# device before the attach
DETACH_PIN = 8
DETACH_MS = 200


def se0_reset(lines, ms, least=2):
    """A bus_reset for `serve`: SE0 held past `least` milliseconds (an EOP's SE0 lasts two
    bits). lines() returns D+ | D- << 1. SE0 only counts if a second read also sees it."""
    since, fired = None, False

    def bus_reset():
        nonlocal since, fired
        if lines() & 3 or lines() & 3:
            since, fired = None, False
            return False
        now = ms()
        since = now if since is None else since
        if fired or now - since <= least:
            return False
        fired = True
        return True

    return bus_reset


def serve(host, board, bus_reset, say=print, done=lambda: False):
    """Run until done(): restart engine 0 after each bus reset and feed it the board's words.
    `say` gets each request and each change of address or configuration."""
    address, configured, seen = 0, False, 0
    while not done():
        if bus_reset():
            usb_fs_board.restart(host, board)
            address, configured, seen = 0, False, 0
            say("bus reset")
        usb_fs_board.service(host, board)
        while seen < len(board.log):
            request_type, request, value, index, length = board.log[seen]
            say(f"request {request_type:02x} {request:02x} {value:04x} {index:04x} {length}")
            seen += 1
        if board.address != address:
            address = board.address
            say(f"address {address}")
        if board.configured != configured:
            configured = board.configured
            say("configured" if configured else "unconfigured")


def run(seconds=20, say=print):
    """Run on the Icepi Zero from Pico A: stay attached for `seconds`, then detach."""
    import pico_board
    from machine import Pin

    detach = Pin(DETACH_PIN, Pin.OUT, value=1)
    dp, dn = Pin(6, Pin.IN), Pin(7, Pin.IN)
    host = pico_board.host()
    board = usb_fs_board.Board(DESCRIPTORS)
    usb_fs_board.load(host, board)
    say(f"engine 0 is serving, {len(board.memory)} data memory words")
    time.sleep_ms(DETACH_MS)
    detach(0)
    start = time.ticks_ms()
    serve(
        host,
        board,
        se0_reset(lambda: dp() | dn() << 1, time.ticks_ms),
        say,
        lambda: time.ticks_diff(time.ticks_ms(), start) > 1000 * seconds,
    )
    detach(1)
    say("detached")


if __name__ == "__main__":
    run()
