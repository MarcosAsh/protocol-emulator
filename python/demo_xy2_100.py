# SPDX-License-Identifier: Apache-2.0
# A galvanometer controller's XY2-100 on OUT0 (SENDCK), OUT1 (SYNC) and OUT2 (DATA)
# (MicroPython, Pico A): a sweep of setpoints, one word each, SENDCK running on after.
# demo/outside.sh xy2_100 runs it, taking its settings from the next line.
# outside: analyser=A ms=2000 decode=-P xy2-100:clk=D4:sync=TODO:data=D6
# TODO outside: OUT1 has no analyser channel, see Bench_wiring

import bench
import bench_firmware
import protocol_emulator as pe

# the 16-bit setpoints, offset binary: mid-scale is the centre
WORDS = [0x8000, 0x0000, 0xFFFF, 0x1234]


def run(transfer, log=print):
    host = pe.Host(transfer)
    bench.load(host, bench_firmware.XY2_100)
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
