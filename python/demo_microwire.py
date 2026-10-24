# SPDX-License-Identifier: Apache-2.0
# TODO what this shows on the bench, and what is wired to which pin (MicroPython, Pico A).
# demo/outside.sh microwire runs it, reading the analyser, the capture's length and
# sigrok's decoders from the next line.
# outside: analyser=TODO ms=2000 decode=-P microwire:cs=TODO:sk=TODO:si=TODO:so=TODO
# TODO outside: OUT0 is on the other analyser; OUT1 has no analyser channel; OUT2 is on the other analyser; OUT3 is on the other analyser, see Bench_wiring

import bench
import bench_firmware
import protocol_emulator as pe

# TODO the words the firmware takes
WORDS = [0x55, 0xA3]


def run(transfer, log=print):
    host = pe.Host(transfer)
    bench.load(host, bench_firmware.MICROWIRE)
    host.start()
    host.push(WORDS)
    # TODO read back what the far end answered, and judge it
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
