# SPDX-License-Identifier: Apache-2.0
# A TDM audio transmitter on OUT3 (SCLK), OUT4 (FSYNC) and OUT6 (SDATA), watched by
# analyser B's D4, D1 and D3 (MicroPython, Pico A). Sends a frame of eight 16-bit samples,
# then silence while SCLK keeps running until the core is halted. OUT1, the library's
# FSYNC, reaches no channel. OUT5, the flash's clock, stays still, so the flash ignores it.
# demo/outside.sh tdm_audio runs it and takes the analyser, capture length and sigrok
# decoders from the next line.
# outside: analyser=B ms=2000 decode=-P tdm_audio:clock=D4:frame=D1:data=D3:bps=32:channels=8 -A tdm_audio=ch0:ch1:ch2:ch3:ch4:ch5:ch6:ch7

import bench
import bench_firmware
import protocol_emulator as pe

# one sample per channel, channel 1 first, the top 16 bits of the 24-bit audio word
WORDS = [0x8000, 0x7FFF, 0x1234, 0xA5A5, 0x0001, 0xFFFF, 0x5555, 0xC3C3]
CHANNELS = 8


def channel(i, sample):
    """What sigrok's tdm_audio decoder prints for a 32-bit block: the sample, 8 zero bits,
    then the pad."""
    return "tdm_audio-1: Channel %d: %08x" % (i % CHANNELS + 1, sample << 16)


def lines(words, silent):
    """The frame of words, then silent blocks, one per channel in turn."""
    return ([channel(i, w) for i, w in enumerate(words)]
            + [channel(i, 0) for i in range(silent)])


def run(transfer, pause_ms, log=print):
    host = pe.Host(transfer)
    bench.load(host, bench_firmware.TDM_AUDIO)
    host.start()
    host.push(WORDS)
    pause_ms(1)
    host.stop()
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
