# SPDX-License-Identifier: Apache-2.0
# A galvanometer controller's XY2-100 on OUT3 (SENDCK), OUT4 (SYNC) and OUT6 (DATA), which
# analyser B's D4, D1 and D3 watch (MicroPython, Pico A): a sweep of setpoints, one word
# each, then the core halted, which stops SENDCK. OUT1, the library's SYNC, reaches no
# channel. OUT5, the flash's clock, stays still, so the flash takes none of it.
# demo/outside.sh xy2_100 runs it, taking its settings from the next line.
# outside: analyser=B ms=2000 decode=-P xy2-100:clk=D4:sync=D1:data=D3 -A xy2-100=type:parity:position

import bench
import bench_firmware
import protocol_emulator as pe

# the 16-bit setpoints, offset binary: mid-scale is the centre
WORDS = [0x8000, 0x0000, 0xFFFF, 0x1234]


def frame(word):
    """What sigrok's xy2-100 prints of a setpoint's frame, the position signed."""
    position = word - 0x10000 if word & 0x8000 else word
    return ["xy2-100-1: 16 bit Position Frame", "xy2-100-1: OK", "xy2-100-1: %d" % position]


def lines(words):
    """The frames of the setpoints in order. The decoder reads a frame once the next begins,
    and the last setpoint goes out again until the halt, so the last of these comes again."""
    return [line for word in words for line in frame(word)]


def run(transfer, log=print):
    host = pe.Host(transfer)
    bench.load(host, bench_firmware.XY2_100)
    host.start()
    host.push(WORDS)
    found = bench.faults(host)
    host.stop()
    log("faults 0x%x" % found)
    return not found


if __name__ == "__main__":
    import time

    import pico_board

    log = bench.Log()
    spi = pico_board.PicoSpi()
    time.sleep_ms(bench.START_MS)
    bench.report(lambda: run(spi.transfer, log), log)
