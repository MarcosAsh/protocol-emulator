# SPDX-License-Identifier: Apache-2.0
# DALI at 1200 bit/s from the library's transmitter (MicroPython, Pico A): OUT0 idles high,
# which analyser A's D4 and Pico B's GP1 see. A query to short address 1, then its answer
# as a backward frame.
# outside: analyser=A ms=2000 decode=-P dali:dali=D4 -A dali=address:command:reply

import bench
import bench_firmware
import protocol_emulator as pe

# Dali.half_bit: 416.7 us at 48 MHz
HALF_BIT = 20000
# Dali.query and Dali.answer: (data bits, value)
FRAMES = [(16, (0x03 << 8) | 0xA0), (8, 254)]
# a frame and its 27 half bits of idle take at most 61 half bits, 25.4 ms
FRAME_MS = 26


def words(bits, value):
    """Dali.words: the data bits less one, then the value msb first from bit 15."""
    return [bits - 1, value << (16 - bits)]


def lines(frames):
    """What sigrok's dali prints of the frames with outside:'s -A, in order."""
    out = []
    for bits, value in frames:
        if bits == 16:
            out += [
                "dali-1: Short address: %d" % (value >> 9),
                "dali-1: Command: %d (Query Level)" % (value & 0xFF),
            ]
        else:
            out += ["dali-1: Reply: %d" % value]
    return out


def run(transfer, pause_ms, log=print):
    host = pe.Host(transfer)
    bench.load(host, bench_firmware.DALI)
    host.start()
    host.push([HALF_BIT])
    for bits, value in FRAMES:
        host.push(words(bits, value))
        pause_ms(FRAME_MS)
        log("sent %d bits 0x%x" % (bits, value))
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
