# SPDX-License-Identifier: Apache-2.0
# SWD host at 1 MHz: SWCLK on OUT2, SWDIO on IO5, the carrier's SWD pins to the RP2040.
# Wakes it from dormant, selects core 0 and reads its DPIDR; the RP2040 should answer
# OK and 0x0bc12477. demo/outside.sh swd_blind runs it and takes the analyser, capture
# length and sigrok decoders from the next line.
# outside: analyser=A ms=2000 decode=-P swd:swclk=D6:swdio=D7 -A swd=reset:read:ack:data

import bench
import bench_firmware
import protocol_emulator as pe

HALF = 24  # cycles, 1 MHz at 48 MHz


def clocks_of(bits):
    """One driven clock per bit."""
    return [(b, 1) for b in bits]


def lsb(value, n):
    return [(value >> i) & 1 for i in range(n)]


def msb(value, n):
    return lsb(value, n)[::-1]


def request(ap, read, addr):
    fields = [ap, read, (addr >> 2) & 1, (addr >> 3) & 1]
    return clocks_of([1] + fields + [sum(fields) % 2, 0, 1])


RELEASE = (1, 0)
ALERT = [0x49CF9046, 0xA9B4A161, 0x97F5BBC7, 0x45703D98]
TARGETSEL = 0x01002927  # RP2040 core 0

# dormant to SWD (ADIv5 p.5-117), line reset and idle (p.4-104), TARGETSEL (Figure 4-9),
# then a DPIDR read (Figure 4-2): ACK at clocks 8 to 10, data at 11 to 42
SETUP = (
    clocks_of([1] * 8)
    + clocks_of([b for w in ALERT for b in msb(w, 32)])
    + clocks_of([0] * 4)
    + clocks_of(msb(0x58, 8))
    + clocks_of([1] * 56 + [0] * 8)
    + request(0, 0, 0xC)
    + [RELEASE] * 5
    + clocks_of(lsb(TARGETSEL, 32) + [bin(TARGETSEL).count("1") % 2])
    + clocks_of([0] * 8)
)
READ = request(0, 1, 0) + [RELEASE] * 37 + clocks_of([0] * 3)


def words(clocks):
    clocks = clocks + [(0, 1)] * (-len(clocks) % 8)
    out = []
    for i in range(0, len(clocks), 8):
        word = 0
        for j, (level, drive) in enumerate(clocks[i:i + 8]):
            word |= (level << (2 * j)) | (drive << (2 * j + 1))
        out.append(word)
    return out


def lines(dpidr):
    """What sigrok's swd decoder must print for the DPIDR read, in order, with the -A fields
    from the outside: line."""
    return ["swd-1: LINERESET", "swd-1: IDCODE", "swd-1: OK", "swd-1: 0x%08x" % dpidr]


def run(transfer, log=print):
    host = pe.Host(transfer)
    bench.load(host, bench_firmware.SWD_BLIND)
    host.start()
    # the half period goes first and gets no reply
    host.push([HALF])
    setup = words(SETUP)
    pushed = bench.exchange(host, setup + words(READ))[len(setup):]
    bits = [(pushed[i // 8] >> (8 + i % 8)) & 1 for i in range(48)]
    ack = bits[8] | bits[9] << 1 | bits[10] << 2
    dpidr = sum(b << i for i, b in enumerate(bits[11:43]))
    log("ack %d dpidr 0x%08x" % (ack, dpidr))
    found = bench.faults(host)
    log("faults 0x%x" % found)
    return not found and ack == 1 and dpidr == 0x0BC12477


if __name__ == "__main__":
    import time

    import pico_board

    log = bench.Log()
    spi = pico_board.PicoSpi()
    time.sleep_ms(bench.START_MS)
    bench.report(lambda: run(spi.transfer, log), log)
