# SPDX-License-Identifier: Apache-2.0
# A Wiegand reader's 26-bit card read (Wikipedia, oldid 1374164469) on OUT0 (DATA0) and
# OUT1 (DATA1), both idling high (MicroPython, Pico A), with 50 us pulses every 500 us.
# demo/outside.sh wiegand runs it and takes the analyser, capture length and sigrok
# decoders from the next line.
# outside: analyser=A ms=2000 decode=-P wiegand:d0=D4:d1=D5:bitwidth_ms=1 -A wiegand=state
# OUT1 reaches analyser A D5 through CAN board A, whose R follows its T on an idle bus

import bench
import bench_firmware
import protocol_emulator as pe

# pulse width in cycles and interval in pulse widths (the spec gives neither)
PULSE = 2400
INTERVAL = 10


def card(facility, card_id):
    """Words for a 26-bit read: the bit count minus one, then the bits MSB first, with even
    parity over the first 12 and odd parity over the last 12."""
    data = facility << 16 | card_id
    even = bin(data >> 12).count("1") & 1
    odd = 1 ^ bin(data & 0xFFF).count("1") & 1
    bits = even << 25 | data << 1 | odd
    return [25, bits >> 10, (bits & 0x3FF) << 6]


WORDS = card(42, 4660)


def lines(words):
    """What sigrok's wiegand decoder prints for the read: its bits, MSB first."""
    count = words[0] + 1
    bits = (words[1] << 16 | words[2]) >> (32 - count)
    return ["wiegand-1: %d bits %s" % (count, "".join(
        str((bits >> i) & 1) for i in reversed(range(count))))]


def run(transfer, log=print):
    host = pe.Host(transfer)
    bench.load(host, bench_firmware.WIEGAND)
    host.start()
    host.push([PULSE, INTERVAL] + WORDS)
    log("sent: %s" % " ".join("%04X" % w for w in WORDS))
    # the panel only listens, so the check is sigrok's decode of the capture
    found = bench.faults(host)
    log("faults 0x%x" % found)
    return not found


if __name__ == "__main__":
    import time

    import pico_board

    log = bench.Log()
    spi = pico_board.PicoSpi()
    time.sleep_ms(bench.START_MS)
    bench.report(lambda: run(spi.transfer, log), log)
