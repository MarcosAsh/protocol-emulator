# SPDX-License-Identifier: Apache-2.0
# NEC infrared into the library's receiver (MicroPython, Pico A): the chip reads IO3, where
# Pico B's pico_nec_sender.py sends demo_nec's keys, and pushes two words a frame and 0xffff
# a repeat code. demo/nec_rx.sh starts Pico B once this is listening.

import time

import bench
import bench_firmware
import demo_nec
import protocol_emulator as pe

# Nec.standard_half: 281.25 us at 48 MHz
HALF = 13500
REPEAT = 0xFFFF
# Pico B's keys take 540 ms from its first leader; it starts within a few seconds
LISTEN_MS = 8000


def expected(keys=demo_nec.KEYS):
    """Nec.rx's words for the keys: address and command, each with its inverse above it,
    then a word a repeat code."""
    out = []
    for address, command, repeats in keys:
        out += demo_nec.words(address, command, 0)[1:] + [REPEAT] * repeats
    return out


def run(transfer, pause_ms, log=print):
    host = pe.Host(transfer)
    bench.load(host, bench_firmware.NEC_RX)
    host.start()
    host.push([HALF])
    want = expected()
    got = []
    start = time.ticks_ms()
    while len(got) < len(want) and time.ticks_diff(time.ticks_ms(), start) < LISTEN_MS:
        level = bench.rx_level(host)
        if level:
            got += host.pop(level)
        pause_ms(5)
    log("read %s" % " ".join("%04x" % w for w in got))
    log("want %s" % " ".join("%04x" % w for w in want))
    found = bench.faults(host)
    log("faults 0x%x" % found)
    return got == want and not found


if __name__ == "__main__":
    import pico_board

    log = bench.Log()
    spi = pico_board.PicoSpi()
    time.sleep_ms(bench.START_MS)
    bench.report(lambda: run(spi.transfer, time.sleep_ms, log), log)
