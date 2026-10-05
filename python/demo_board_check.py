# SPDX-License-Identifier: Apache-2.0
# Bring-up check for the Tiny Tapeout demo board (MicroPython), nothing attached and every
# ui DIP switch off: status, register readback, the chip's clock against the RP2's, and
# uart_tx_host_rate on uo[1] read back by a PIO. Prints a line a check, then PASS or FAIL.
#   mpremote cp python/protocol_emulator.py python/demo_board.py :
#   mpremote run python/demo_board_check.py
# Untested on a board; test/test_demo_board.py runs it on the RTL.

import rp2
import time
from machine import Pin

import demo_board
import protocol_emulator as pe

# test/uart_tx_host_rate.hex: the bit period first, then a frame a word, on OUT0
UART_TX = [
    0x20E0, 0xE004, 0x80C5, 0xA001, 0x20E0, 0xE004, 0xA027, 0x80E6, 0xA000,
    0xC0CA, 0x20C0, 0x6001, 0x020A, 0x20C0, 0xA001, 0x2040, 0x0004,
]

# test/uart_tx_host_rate.cert.hex: what the chip checks UART_TX against, from a period of 4
UART_TX_CERTIFICATE = [
    0x0002, 0x0001, 0x0200, 0x0001, 0x0000, 0x0500, 0x4001, 0x0400,
    0xFF00, 0x0400, 0x0000, 0x0004, 0xFFFF, 0x0000, 0x0007,
]

BAUD = 115_200
BYTES = [0x55, 0xA3, 0x00, 0xFF]
FAULTS = 0x3C
# the 24-bit counter wraps in 349 ms at 48 MHz
WINDOW_MS = 100


@rp2.asm_pio(in_shiftdir=rp2.PIO.SHIFT_RIGHT, autopush=True, push_thresh=8)
def uart_rx():
    # eight cycles a bit, each read mid-bit; idle first, so a line low from reset is no
    # start bit
    wait(1, pin, 0)  # noqa: F821
    wait(0, pin, 0)  # noqa: F821
    set(x, 7)[10]  # noqa: F821
    label("bit")  # noqa: F821
    in_(pins, 1)  # noqa: F821
    jmp(x_dec, "bit")[6]  # noqa: F821


def report(say, name, ok, detail):
    say("%s %s: %s" % ("pass" if ok else "FAIL", name, detail))
    return ok


def status(host, say):
    """Both engines halted, as reset leaves them, with no fault and empty fifos. A chip
    that never answers reads 0, MISO's pull-down."""
    ok = True
    for engine in (0, 1):
        host.select(engine)
        s = host.read(pe.STATUS)[0]
        ok = report(say, "status %d" % engine, s == 1, "0x%04x, wants 0x0001" % s) and ok
    host.select(0)
    return ok


def readback(host, say):
    got = []
    for word in (0x1A5, 0x05A):
        host.write(pe.PROGRAM_ADDR, [word])
        got += host.read(pe.PROGRAM_ADDR)
    for engine in (1, 0):
        host.select(engine)
        got += host.read(pe.SELECT)
    detail = "program address and select read %s" % " ".join("0x%03x" % w for w in got)
    return report(say, "readback", got == [0x1A5, 0x05A, 1, 0], detail)


def clock(host, clock_hz, window_ms, say):
    """now against the RP2's microseconds, each read stamped halfway through its frames."""

    def stamp():
        before = time.ticks_us()
        now = host.now()
        return now, time.ticks_add(before, time.ticks_diff(time.ticks_us(), before) // 2)

    now0, us0 = stamp()
    time.sleep_ms(window_ms)
    now1, us1 = stamp()
    hz = ((now1 - now0) & 0xFFFFFF) * 1_000_000 // time.ticks_diff(us1, us0)
    ok = abs(hz - clock_hz) * 100 <= clock_hz
    return report(say, "clock", ok, "%d Hz, wants %d within 1%%" % (hz, clock_hz))


def uart(spi, host, clock_hz, say):
    """uart_tx_host_rate on engine 0 at 115200 baud, read on uo[1] by the PIO beside the
    host's. A 512-word load leaves the program address back at 0."""
    period = (clock_hz + BAUD // 2) // BAUD
    sm = rp2.StateMachine(
        demo_board.STATE_MACHINE + 1, uart_rx, freq=8 * clock_hz // period,
        in_base=Pin(demo_board.gpio(spi.tt, "uo_out1")),
    )
    host.stop()
    host.flush()
    host.configure(pe.DEFAULT_CONFIG)
    host.load(UART_TX)
    host.certify(UART_TX_CERTIFICATE, loaded=4)
    wrapped = host.read(pe.PROGRAM_ADDR)[0]
    ok = report(say, "load", wrapped == 0, "program address 0x%03x after 512 words" % wrapped)
    sm.active(1)
    host.start()
    host.push([period] + BYTES)
    got = []
    start = time.ticks_ms()
    while len(got) < len(BYTES) and time.ticks_diff(time.ticks_ms(), start) < 50:
        if sm.rx_fifo():
            got.append(sm.get() >> 24)
    sm.active(0)
    faults = host.read(pe.STATUS)[0] & FAULTS
    detail = "%s at %d cycles a bit, faults 0x%02x" % (
        " ".join("0x%02x" % b for b in got), period, faults)
    return report(say, "uart", got == BYTES and not faults, detail) and ok


def run(clock_hz=48_000_000, window_ms=WINDOW_MS, say=print):
    try:
        spi = demo_board.DemoBoardSpi(clock_hz=clock_hz, programs=(uart_rx,))
    except (RuntimeError, ValueError) as e:
        say("FAIL setup: %s" % e)
        say("FAIL")
        return False
    host = pe.Host(spi.transfer)
    ok = status(host, say)
    ok = readback(host, say) and ok
    ok = clock(host, clock_hz, window_ms, say) and ok
    ok = uart(spi, host, clock_hz, say) and ok
    say("PASS" if ok else "FAIL")
    return ok


if __name__ == "__main__":
    run()
