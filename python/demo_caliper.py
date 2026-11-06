# SPDX-License-Identifier: Apache-2.0
# A Chinese digital scale's output (Chinese Scales, page 1) on OUT0 (clock) and OUT2 (data),
# watched by analyser A's D4 and D6 (MicroPython, Pico A). Sends two frames of two 24-bit
# positions, LSB first, with a half clock period of 270 cycles. OUT1, the library's data
# pin, reaches no channel.
# demo/outside.sh caliper runs it and takes its settings from the next line.
# outside: analyser=A ms=2000 decode=-P caliper:clk=D4:data=D6 -A caliper=measurement

import bench
import bench_firmware
import protocol_emulator as pe

HALF = 270
# two frames; each position is 16 bits plus 8 (the high byte holds the flags). One frame
# in mm and one in inches, each with a sign
FRAMES = [[0x1234, 0x00, 0x8000, 0xFF], [0x0010, 0x10, 0x0FA0, 0x80]]
# sigrok's caliper drops what it has after 10 ms without a clock rise. The clock rises as
# the firmware starts, so the first frame waits past that; the second follows right behind,
# like a scale's fast update
SETTLE_MS = 20


def reading(number, flags):
    """What sigrok's caliper decoder makes of a position: bit 4 of the flags is the sign,
    bit 7 means inches in 2000ths, otherwise mm in 100ths."""
    value = -number if flags >> 4 & 1 else number
    if flags >> 7 & 1:
        return "%sin" % (value / 2000)
    return "%smm" % (value / 100)


def lines(frames):
    """What sigrok's caliper decoder prints for the frames' positions, in order, using the
    -A fields from the outside: line."""
    return ["caliper-1: " + reading(f[i], f[i + 1]) for f in frames for i in (0, 2)]


def run(transfer, pause_ms, log=print):
    host = pe.Host(transfer)
    bench.load(host, bench_firmware.CALIPER)
    host.start()
    host.push([HALF])
    for words in FRAMES:
        pause_ms(SETTLE_MS)
        host.push(words)
        log("sent: %s" % " ".join("%04X" % w for w in words))
    pause_ms(2)
    found = bench.faults(host)
    log("faults 0x%x" % found)
    return not found


if __name__ == "__main__":
    import time

    import pico_board

    log = bench.Log()
    spi = pico_board.PicoSpi()
    time.sleep_ms(bench.START_MS)
    bench.report(lambda: run(spi.transfer, time.sleep_ms, log), log)
