# SPDX-License-Identifier: Apache-2.0
# TODO what this shows on the bench, and what is wired to which pin (MicroPython, Pico A).
# demo/outside.sh frumbleglide runs it, taking its settings from the next line.
# outside: analyser=A ms=2000 decode=-P TODO:TODO=D4

import bench
import bench_firmware
import protocol_emulator as pe

# TODO the words the firmware takes
WORDS = [0x55, 0xA3]


def run(transfer, log=print):
    host = pe.Host(transfer)
    bench.load(host, bench_firmware.FRUMBLEGLIDE)
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
