# SPDX-License-Identifier: Apache-2.0
# Snorble (SNB-1 Rev. C) on SIG, OUT0, which analyser A's D4 watches (MicroPython, Pico A):
# four bytes, each a frame of sync, eight bits and odd parity, frames 214 us apart.
# demo/outside.sh snorble runs it, reading the analyser, the capture's length and
# sigrok's decoders from the next line.
# outside: analyser=A ms=2000 decode=-P snorble:sig=D4 -A snorble=byte:parity-ok

import bench
import bench_firmware
import protocol_emulator as pe

BYTES = [0xA5, 0x00, 0xFF, 0x3C]


def run(transfer, pause_ms, log=print):
    host = pe.Host(transfer)
    bench.load(host, bench_firmware.SNORBLE)
    host.start()
    host.push(BYTES)
    pause_ms(2)
    log("sent: %s" % " ".join("%02X" % b for b in BYTES))
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
