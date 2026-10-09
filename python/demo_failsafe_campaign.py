# SPDX-License-Identifier: Apache-2.0
# One fault injection for demo/failsafe_campaign.py (MicroPython): engine 0 runs the case's
# firmware on wire 20 and OUT0, engine 1 the edge logger echoing on OUT2 or a square wave
# there. The line goes to result.txt, as mpremote run --no-follow leaves prints unread.

import time

import protocol_emulator as pe
from pico_board import PicoSpi

# test/edge_logger_echo.asm
LOGGER = [
    0x080B, 0xA000, 0x2094, 0x8026, 0xA001, 0x4030, 0x2014, 0x8026, 0xA000, 0x4030,
    0x0002, 0xA001, 0x0006,
]
# demo/failsafe_campaign/square.asm
SQUARE = [0x20E0, 0xE004, 0x80C5, 0x80E6, 0xC0CA, 0x20C0, 0xA001, 0x20C0, 0xA000, 0x0005]
OUT2 = 7
WIRE = 20
FAULTS = 0x3C


def config(changes):
    c = dict(pe.DEFAULT_CONFIG)
    c.update(changes)
    return c


def snapshot(host, engine):
    host.select(engine)
    return host.read(pe.STATUS)[0], host.read(pe.PC)[0]


def drain(spi, host, stamps, polls):
    host.select(1)
    for _ in range(polls):
        spi.drain(stamps, ())


def run(case, start_ms=1000, settle_ms=20, after_ms=300, out="result.txt"):
    """case: words, push and side_set for engine 0, neighbour "logger" or "square", and
    period for the square."""
    spi = PicoSpi()
    host = pe.Host(spi.transfer)
    held = [snapshot(host, e)[0] & FAULTS for e in (0, 1)]
    for e in (1, 0):
        host.select(e)
        host.stop()
        host.flush()
    host.select(1)
    if case["neighbour"] == "logger":
        host.configure(config({"jmp_pin": WIRE, "autopush": 1, "set_base": OUT2}))
        host.load(LOGGER)
    else:
        host.configure(config({"set_base": OUT2}))
        host.load(SQUARE)
    host.select(0)
    host.configure(config({
        "set_base": WIRE, "set_count": 1, "side_set_count": 1, "side_set_base": 5}))
    host.load(case["words"])
    time.sleep_ms(start_ms)
    host.select(1)
    host.start()
    if case["neighbour"] == "square":
        host.push([case["period"]])
    host.select(0)
    host.start()
    host.push(case["push"])
    time.sleep_ms(settle_ms)
    stamps = []
    if case["neighbour"] == "logger":
        drain(spi, host, stamps, 20)
    first = [snapshot(host, 0), snapshot(host, 1)]
    # a faulted engine stays halted through a start, its pc held
    host.select(0)
    host.start()
    time.sleep_ms(after_ms)
    later = []
    if case["neighbour"] == "logger":
        drain(spi, host, later, 20)
    second = [snapshot(host, 0), snapshot(host, 1)]
    line = "%s held %x %x first %x %d %x %d second %x %d %x %d stamps %s later %s" % (
        case["name"], held[0], held[1],
        first[0][0], first[0][1], first[1][0], first[1][1],
        second[0][0], second[0][1], second[1][0], second[1][1],
        ",".join("%d" % s for s in stamps) or "-", ",".join("%d" % s for s in later) or "-")
    with open(out, "w") as f:
        f.write(line + "\n")
