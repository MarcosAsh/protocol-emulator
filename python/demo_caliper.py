# SPDX-License-Identifier: Apache-2.0
# A Chinese digital scale's output (Chinese Scales, page 1) on OUT0, the clock, which
# analyser A's D4 watches, and OUT1, the data (MicroPython, Pico A): two 24-bit positions,
# LSB first, 270 cycles a half clock period.
# demo/outside.sh caliper runs it, taking its settings from the next line.
# outside: analyser=A ms=2000 decode=-P caliper:clk=D4:data=TODO
# TODO outside: OUT1 has no analyser channel, see Bench_wiring

import bench
import bench_firmware
import protocol_emulator as pe

# the clock's half period, then each position as 16 bits and 8
WORDS = [270, 0x1234, 0x00, 0x8000, 0xFF]


def run(transfer, pause_ms, log=print):
    host = pe.Host(transfer)
    bench.load(host, bench_firmware.CALIPER)
    host.start()
    host.push(WORDS)
    pause_ms(2)
    log("sent: %s" % " ".join("%04X" % w for w in WORDS[1:]))
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
