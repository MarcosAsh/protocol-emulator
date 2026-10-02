# SPDX-License-Identifier: Apache-2.0
# Act 3: engine 0 is a USB keyboard and mouse that types TEXT (MicroPython). D+ is uio[0],
# D- uio[1], pulled up from D- for low speed. On the Icepi Zero a Pico is the host over
# pico_board's pins and watches the bus on header 29 (D+) -> GP6 and 31 (D-) -> GP7; the
# TT demo board reads uio_out itself. Meanwhile engine 1 sends each key the laptop took
# out of OUT0 at 115200 baud, for pico_listener. Needs uart_tx_host_rate.hex on the Pico.
# Untested on a board; test/test_demo.py runs `start_log` and `serve` on the RTL.

import time

import protocol_emulator as pe
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
CHARS = {code: ord(c) for c, code in KEYS.items()}

BAUD = 115_200
# uart_tx_host_rate on OUT0, the default set and out pin
LOGGER = pe.DEFAULT_CONFIG


def reports(text):
    """Each character pressed, released, and the mouse three pixels to the right."""
    queue = []
    for c in text:
        queue += [[1, 0, KEYS[c], 0, 0, 0, 0, 0], [1, 0, 0, 0, 0, 0, 0, 0], [2, 0, 3, 0]]
    return queue


def se0_reset(lines, ms, least=2):
    """A bus_reset for `serve`. lines() is D+ | D- << 1 and ms() counts milliseconds: SE0
    held past `least` of them is a reset, where an EOP's is two bits. True once a reset.
    SE0 counts only when a second read finds it too, as two reads that each land on an
    EOP, milliseconds apart, would otherwise make one."""
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


def words(name):
    with open(name + ".hex") as f:
        return pe.hex_words(f.read())


def start_log(host, program, clock_hz=48_000_000):
    """Engine 1 runs `program`, uart_tx_host_rate, which the kernel accepts at any period
    from 4. Returns the `log` for `serve`, which sends the key of each report taken."""
    host.select(1)
    host.stop()
    host.flush()
    host.configure(LOGGER)
    host.load(program)
    host.push([(clock_hz + BAUD // 2) // BAUD])
    host.start()
    host.select(0)

    # a key takes three reports at the 10 ms poll, so its byte has long left the fifo
    def log(report):
        if report[0] == 1 and report[2]:
            host.select(1)
            host.push([CHARS[report[2]]])
            host.select(0)

    return log


def serve(host, board, queue, bus_reset, log=lambda report: None, say=lambda line: None):
    """Forever. Typing waits for a configuration and a HID driver, so no report sits in the
    fifo while the laptop enumerates: an IN on endpoint 0 would drop it, a word more for the
    rx fifo on a SETUP's heels. A reset puts back the report it lost, `log` gets each report
    once the laptop has taken it, and `say` each step of the enumeration and each key."""
    serving, address, configured = False, 0, False
    while True:
        if bus_reset():
            if board.pending_report is not None:
                queue.insert(0, board.pending_report)
            board.reset()
            address, configured = 0, False
            say("bus reset")
        sent = board.pending_report
        usb_board.service(host, board)
        if not serving:
            serving = True
            # the board pulled D- up at its bitstream, when nothing answered the laptop
            say("engine 0 is serving: plug the Icepi's first USB port in again")
        if board.address != address:
            address = board.address
            say("address %d" % address)
        if board.configured != configured:
            configured = board.configured
            say("configured" if configured else "unconfigured")
        if sent is not None and board.pending_report is None:
            log(sent)
            if sent[0] == 1 and sent[2]:
                say("typed %s" % chr(CHARS[sent[2]]))
        if queue and board.configured and board.described and board.pending_report is None and not board.chunks:
            board.report(queue.pop(0))


def run(text="hello jane street ", say=print):
    """On the Icepi Zero, from the host Pico."""
    from machine import Pin

    import pico_board

    dp, dn = Pin(6, Pin.IN), Pin(7, Pin.IN)
    bus_reset = se0_reset(lambda: dp() | dn() << 1, time.ticks_ms)
    host = pico_board.host()
    log = start_log(host, words("uart_tx_host_rate"))
    serve(host, usb_board.Board(DESCRIPTORS), reports(text), bus_reset, log, say)


def run_demo_board(text="hello jane street ", clock_hz=48_000_000):
    import demo_board

    spi = demo_board.DemoBoardSpi(clock_hz=clock_hz)
    bus_reset = se0_reset(lambda: int(spi.tt.uio_out.value), time.ticks_ms)
    host = demo_board.Host(spi.transfer)
    log = start_log(host, words("uart_tx_host_rate"), clock_hz)
    serve(host, usb_board.Board(DESCRIPTORS), reports(text), bus_reset, log, print)


if __name__ == "__main__":
    run()
