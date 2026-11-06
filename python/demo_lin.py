# SPDX-License-Identifier: Apache-2.0
# Lin.firmware as a LIN master on IO5, open drain, sending the header of frame 0x16 at
# 19200 baud (MicroPython, Pico A). IO5 is analyser A's D7. Nothing on the bench answers,
# so the firmware waits for a response, and the run passes on a clean header.
# demo/outside.sh lin runs it and takes the analyser, capture length and sigrok decoders
# from the next line.
# outside: analyser=A ms=2000 decode=-P uart:rx=D7:baudrate=19200,lin -A lin=data:control

import bench
import bench_firmware
import protocol_emulator as pe

# Lin.half: 1250 cycles at 48 MHz, half a bit at 19200 baud
HALF = 1250
# Lin.words: response bytes minus one, then the PID of frame 0x16
WORDS = [3, 0xD6]


def lines(pid):
    """What sigrok's lin decoder prints for a header, with the -A fields from the outside:
    line."""
    return ["lin-1: Break condition", "lin-1: Sync",
            "lin-1: ID: %02X Parity: %d (ok)" % (pid & 0x3F, pid >> 6)]


def run(transfer, log=print):
    host = pe.Host(transfer)
    bench.load(host, bench_firmware.LIN)
    host.start()
    host.push([HALF] + WORDS)
    # no slave answers, so there's nothing to read back
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
