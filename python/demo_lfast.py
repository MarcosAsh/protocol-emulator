# SPDX-License-Identifier: Apache-2.0
# LFAST frames from the library's transmitter (MicroPython, Pico A): OUT0 idles low, 4.8 Mb/s.
# demo/outside.sh lfast runs it, taking its settings from the next line.
# outside: analyser=A ms=2000 decode=-P lfast:data=D4 -A lfast=sync:header_pl_size:header_ch_type:header_cts:payload:sleep

import bench
import bench_firmware
import protocol_emulator as pe

# payload bytes, one frame each; not 0x00
WORDS = [0x55, 0xA3]


def lines(words):
    """What sigrok's lfast prints of the frames with outside:'s -A, in order: it labels the
    stop bit a sleep request."""
    return ["lfast-1: " + text for word in words
            for text in ["Sync OK", "8 bit", "Data Channel A", "1", "%02X" % word,
                         "LVDS sleep mode request"]]


def run(transfer, log=print):
    host = pe.Host(transfer)
    bench.load(host, bench_firmware.LFAST)
    host.start()
    host.push(WORDS)
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
