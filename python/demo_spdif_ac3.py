# SPDX-License-Identifier: Apache-2.0
# One AC-3 frame in an IEC 61937 burst on OUT0's S/PDIF transmitter (MicroPython, Pico A).
# FFmpeg made the burst, and demo/traffic.py has FFmpeg find the frame in the capture.
# demo/outside.sh spdif_ac3 takes the analyser and capture length from the next line. Its
# sigrok decode is not judged, as spdif misreads the burst.
# outside: analyser=A ms=2000 decode=-P spdif:data=D4 -A spdif=samples

import bench
import bench_firmware
import protocol_emulator as pe

# ffmpeg 8.0.1: -f lavfi -i sine=f=1000:r=44100 -ac 1 -c:a ac3 -b:a 32k -frames:a 1
# -bitexact -f spdif, read as little-endian words up to the frame's end
BURST = [
    0xF872, 0x4E1F, 0x0001, 0x0450, 0x0B77, 0xC4CD, 0x4040, 0x2F84, 0x2B02, 0x1BE2,
    0xB90D, 0xF573, 0x2FE7, 0xD415, 0x6AAD, 0x9AC1, 0xCE33, 0x22E7, 0x7C12, 0x95E9,
    0xD4E7, 0x6DBA, 0x46F3, 0x6B10, 0xF622, 0xE265, 0x5711, 0x7113, 0x232A, 0x32A3,
    0x841C, 0xD288, 0x1FE0, 0x0060, 0x7DFE, 0x71B8, 0xA5F2, 0xB4CF, 0x9757, 0x7349,
    0xED84, 0xCA5E, 0xC776, 0x0320, 0x02BF, 0x2492, 0x38BF, 0xD7C4, 0x2040, 0x2580,
    0x2862, 0x48AB, 0x8865, 0x7096, 0x4A00, 0xC800, 0x5283, 0x5F05, 0x527C, 0x9564,
    0x9003, 0x20F8, 0x4D80, 0x7F3A, 0x4A90, 0x5612, 0x8019, 0x07CD, 0x0C7A, 0xFA8D,
    0x041D, 0x9A00, 0xE1FF,
]
# two silent frames first, and a pad to whole frames
WORDS = [0] * 4 + BURST + [0]
# the transmitter takes a word every 11.34 us and the fifo holds 15, so one write feeds it
# at 11.08 us a word (19 bit times, as the Pico idles 1.5 bits between bytes)
STREAM_BAUD = 1_720_000


def run(transfer, set_baud, pause_ms, log=print):
    host = pe.Host(transfer)
    bench.load(host, bench_firmware.SPDIF)
    # the firmware waits for the first word
    host.start()
    log("stream at %s" % set_baud(STREAM_BAUD))
    host.push(WORDS)
    set_baud(None)
    pause_ms(5)
    host.stop()
    found = bench.faults(host)
    log("faults 0x%x" % found)
    return not found


if __name__ == "__main__":
    import time

    import pico_board

    log = bench.Log()
    spi = pico_board.PicoSpi()

    def set_baud(baud):
        spi.spi.init(baudrate=baud or 6_000_000)
        return spi.spi

    time.sleep_ms(bench.START_MS)
    bench.report(lambda: run(spi.transfer, set_baud, time.sleep_ms, log), log)
