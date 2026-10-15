# SPDX-License-Identifier: Apache-2.0
# The on-chip kernel from Pico A (MicroPython): an uncertified start is refused, the
# certified uart runs a frame without a fault, and the same uart with its bit loop a cycle
# longer than the period is refused at the loop's jump and stays halted. PASS or FAIL.
#   mpremote cp python/protocol_emulator.py python/pico_board.py :
#   mpremote run python/onchip_smoke.py

import pico_board
import protocol_emulator as pe

# test/uart_tx_host_rate.hex: the bit period from the fifo first, then a frame a word
UART_TX = [
    0x20E0, 0xE004, 0x80C5, 0xA001, 0x20E0, 0xE004, 0xA027, 0x80E6, 0xA000,
    0xC0CA, 0x20C0, 0x6001, 0x020A, 0x20C0, 0xA001, 0x2040, 0x0004,
]

# test/uart_tx_host_rate.cert.hex, made for a loaded period of at least 4
UART_TX_CERTIFICATE = [
    0x0002, 0x0001, 0x0200, 0x0001, 0x0000, 0x0500, 0x4001, 0x0400,
    0xFF00, 0x0400, 0x0000, 0x0004, 0xFFFF, 0x0000, 0x0007,
]

# out pins, 1 [1]: the loop at pc 10-12 takes 5 cycles a bit, so at a period of 4 its
# wait t+ comes late. The kernel refuses at the jmp (pc 12) on conjunct 13, target phase.
SLOW_PC = 11
SLOW_WORD = 0x6101
REFUSED_AT = (12, 13)

FAULTS = 0x3C
REFUSED = 0x8


def report(name, ok, detail):
    print("%s %s: %s" % ("pass" if ok else "FAIL", name, detail))
    return ok


def load(h, words):
    """The reset configuration wraps at pc 0, so without DEFAULT_CONFIG the chip checks
    and runs the first word alone."""
    h.stop()
    h.flush()
    h.configure(pe.DEFAULT_CONFIG)
    h.load(words)


def certify(h, words):
    """None if the chip certifies words, else (pc, reason)."""
    load(h, words)
    try:
        h.certify(UART_TX_CERTIFICATE, loaded=4)
    except pe.Refused as e:
        return tuple(e.args)
    return None


def stays_halted(h):
    h.start()
    return h.status()["halted"] == 1 and h.read(pe.CHECK_STATUS)[0] & REFUSED != 0


def run():
    h = pico_board.host()
    ok = True

    load(h, UART_TX)
    ok = report("uncertified", stays_halted(h), "start refused") and ok

    got = certify(h, UART_TX)
    detail = "refused at %s" % (got,) if got else "accepted"
    ok = report("certify", got is None, detail) and ok
    h.start()
    h.push([16, 0x55])
    level = h.status()["tx_level"]
    for _ in range(100):
        if level == 0:
            break
        level = h.status()["tx_level"]
    s = h.read(pe.STATUS)[0]
    ok = report(
        "run", s & 1 == 0 and s & FAULTS == 0 and level == 0,
        "status 0x%04x, tx level %d" % (s, level),
    ) and ok

    slow = list(UART_TX)
    slow[SLOW_PC] = SLOW_WORD
    got = certify(h, slow)
    detail = "refused at %s, wants %s" % (got, REFUSED_AT)
    ok = report("slow loop", got == REFUSED_AT, detail) and ok
    ok = report("slow start", stays_halted(h), "stays halted") and ok

    h.stop()
    print("PASS" if ok else "FAIL")
    return ok


run()
