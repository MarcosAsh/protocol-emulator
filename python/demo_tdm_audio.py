# SPDX-License-Identifier: Apache-2.0
# A TDM audio transmitter on OUT0 (SCLK), OUT1 (FSYNC) and OUT2 (SDATA) (MicroPython,
# Pico A): a frame of eight 16-bit samples, then silence as SCLK runs on.
# demo/outside.sh tdm_audio runs it, reading the analyser, the capture's length and
# sigrok's decoders from the next line.
# outside: analyser=A ms=2000 decode=-P tdm_audio:clock=D4:frame=TODO:data=D6
# TODO outside: OUT1 has no analyser channel, see Bench_wiring

import bench
import bench_firmware
import protocol_emulator as pe

# a sample a channel, channel 1 first, the top 16 bits of the 24-bit audio word
WORDS = [0x8000, 0x7FFF, 0x1234, 0xA5A5, 0x0001, 0xFFFF, 0x5555, 0xC3C3]


def run(transfer, log=print):
    host = pe.Host(transfer)
    bench.load(host, bench_firmware.TDM_AUDIO)
    host.start()
    host.push(WORDS)
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
