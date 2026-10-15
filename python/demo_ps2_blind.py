# SPDX-License-Identifier: Apache-2.0
# The chip as a PS/2 keyboard (MicroPython, Pico A): data on IO0 and clock on IO1, each
# pulled up to 3.3 V by 4.7 k. It types the Q key, make and break, at a 12.5 kHz clock.
# Analyser B's D6 and D7 move from I2C to IO0 and IO1 for it. demo/outside.sh ps2_blind
# runs it, reading the analyser, the capture's length and sigrok's decoders from the next
# line.
# outside: analyser=B ms=2000 decode=-P ps2:clk=D7:data=D6 -A ps2=word:parity-ok:parity-err

import bench
import bench_firmware
import protocol_emulator as pe

# 20 us at 48 MHz, a quarter of the clock
UNIT = 960
# the Q key's make and break codes
CODES = [0x15, 0xF0, 0x15]
# a frame is 44 units, under a millisecond
FRAME_MS = 1
# status reads to wait for the fifo to empty, longer than the frames take
POLLS = 10_000


def word(byte):
    """The host word for a byte: the byte, with its odd parity in bit 8."""
    ones = bin(byte & 0xFF).count("1")
    return (byte & 0xFF) | ((ones % 2 == 0) << 8)


def run(transfer, sleep_ms, log=print):
    host = pe.Host(transfer)
    bench.load(host, bench_firmware.PS2_BLIND)
    host.start()
    host.push([UNIT] + [word(b) for b in CODES])
    # nothing answers on the chip's side: the frames are out once the fifo is empty and
    # the last has had its time, and sigrok's decode judges them
    for _ in range(POLLS):
        if not host.status()["tx_level"]:
            break
    sleep_ms(2 * FRAME_MS)
    found = bench.faults(host)
    log("sent %s" % bench.hexs(CODES))
    log("faults 0x%x" % found)
    return not found


if __name__ == "__main__":
    import time

    import pico_board

    log = bench.Log()
    spi = pico_board.PicoSpi()
    time.sleep_ms(bench.START_MS)
    bench.report(lambda: run(spi.transfer, time.sleep_ms, log), log)
