# SPDX-License-Identifier: Apache-2.0
# LFAST frames from the library's transmitter (MicroPython, Pico A): OUT0 idles low, 4.8 Mb/s.
# demo/outside.sh lfast runs it, taking its settings from the next line.
# outside: analyser=A ms=2000 decode=-P lfast:data=D4

import bench
import bench_firmware
import protocol_emulator as pe

# payload bytes, one frame each; not 0x00
WORDS = [0x55, 0xA3]


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
