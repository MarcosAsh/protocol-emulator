# SPDX-License-Identifier: Apache-2.0
# A chirp in AC-3, MP3, AAC and DTS on OUT0's S/PDIF transmitter, one codec after another
# (MicroPython, Pico A). FFmpeg made the IEC 61937 bursts in python/spdif_bursts.py, and
# demo/traffic.py has FFmpeg name each codec and find its frames in the capture. The
# firmware sends silence between bursts. sigrok's spdif misreads them, so its decode is
# not judged. demo/outside.sh spdif_codecs reads the next line.
# outside: analyser=A ms=3000 files=python/spdif_bursts.py decode=-P spdif:data=D4 -A spdif=samples

import binascii
import time

import bench
import bench_firmware
import protocol_emulator as pe
import spdif_bursts

# the transmitter takes a word every 11.34 us and the fifo holds 15, so one write feeds it
# at 11.08 us a word (19 bit times, as the Pico idles 1.5 bits between bytes)
STREAM_BAUD = 1_720_000
# a subframe at 44.1 kHz stereo
WORD_US = 1e6 / 88200
# silent before each codec's first burst
GAP_MS = 20


def frame(burst):
    """Returns the host port write that pushes the burst, padded to whole frames, as the
    firmware takes a right word whenever it had a left."""
    data = bytes([0x80 | pe.TX]) + binascii.unhexlify(burst)
    return data + bytes(len(data) // 2 % 2 * 2)


def run(transfer, set_baud, send, log=print):
    # before the load, to start sooner
    codecs = [(name, period, [frame(burst) for burst in bursts])
              for name, period, bursts in spdif_bursts.CODECS]
    host = pe.Host(transfer)
    bench.load(host, bench_firmware.SPDIF)
    # the firmware waits for the first word
    host.start()
    log("stream at %s" % set_baud(STREAM_BAUD))
    late = 0
    for name, period, frames in codecs:
        start = time.ticks_add(time.ticks_us(), GAP_MS * 1000)
        for i, data in enumerate(frames):
            due = time.ticks_add(start, round(i * period * WORD_US))
            late = max(late, time.ticks_diff(time.ticks_us(), due))
            while time.ticks_diff(time.ticks_us(), due) < 0:
                pass
            send(data)
        log("%s: %d bursts" % (name, len(frames)))
    set_baud(None)
    time.sleep_ms(5)
    host.stop()
    found = bench.faults(host)
    log("faults 0x%x" % found)
    # a burst pushed late would still decode, but off its period
    log("latest push %d us after its place" % max(late, 0))
    return not found and late <= 0


if __name__ == "__main__":
    import pico_board

    log = bench.Log()
    spi = pico_board.PicoSpi()

    def set_baud(baud):
        spi.spi.init(baudrate=baud or 6_000_000)
        return spi.spi

    def send(data):
        # PicoSpi.transfer copies the write first, which would move the burst by its length
        spi.cs_n(0)
        spi.spi.write(data)
        spi.cs_n(1)

    time.sleep_ms(bench.START_MS)
    bench.report(lambda: run(spi.transfer, set_baud, send, log), log)
