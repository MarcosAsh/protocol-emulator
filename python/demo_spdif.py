# SPDX-License-Identifier: Apache-2.0
# An S/PDIF transmitter on OUT0, watched by analyser A's D4 (MicroPython, Pico A). Sends
# three stereo frames of 16-bit samples at 44.1 kHz, biphase mark, then silent frames until
# the core is halted. sigrok starts reading at the second subframe, so it sees a right
# sample, then a left and right per frame.
# demo/outside.sh spdif runs it and takes the analyser, capture length and sigrok decoders
# from the next line.
# outside: analyser=A ms=2000 decode=-P spdif:data=D4 -A spdif=samples

import bench
import bench_firmware
import protocol_emulator as pe

# left then right; one frame per pair
WORDS = [0x1234, 0xFEDC, 0x8001, 0x7FFE, 0x00FF, 0xA5A5]


def lines(words):
    """What sigrok's spdif decoder prints for the samples with -A spdif=samples, each 16
    bits at the top of 24. It starts at the second subframe, as in
    test/traces/spdif.trace."""
    return ["spdif-1: Audio 0x%x" % (w << 8) for w in words[1:]]


def run(transfer, pause_ms, log=print):
    host = pe.Host(transfer)
    bench.load(host, bench_firmware.SPDIF)
    host.push(WORDS)
    host.start()
    pause_ms(1)
    host.stop()
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
