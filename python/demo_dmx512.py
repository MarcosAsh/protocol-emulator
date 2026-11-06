# SPDX-License-Identifier: Apache-2.0
# A DMX512 controller on OUT0, watched by analyser A's D4 (MicroPython, Pico A). Sends a
# packet of start code 0x00 and 512 channels at 250 kbit/s twice, then the next packet's
# break. demo/outside.sh dmx512 runs it and takes the analyser, capture length and sigrok
# decoders from the next line.
# outside: analyser=A ms=2000 decode=-P dmx512:dmx=D4 -A dmx512=break:mab:startcode:channel:data

import bench
import bench_firmware
import protocol_emulator as pe

# channel n is (37 n + 11) mod 256, as in test/dmx512.ml's scenario
CHANNELS = [(37 * n + 11) & 0xFF for n in range(512)]

# the bit period (192 cycles at 48 MHz for 250 kbit/s), then the packet twice: its start
# code, the channels two per word (low byte first), and the next start code. A line that's
# low from reset reads as a break, which frames the first packet on the wrong edges.
PERIOD = 192
PACKET = [0x00] + [lo | hi << 8 for lo, hi in zip(CHANNELS[::2], CHANNELS[1::2])]
WORDS = [PERIOD] + PACKET * 2 + [0x00]


def lines(channels):
    """What sigrok's dmx512 decoder prints for one packet with start code 0, using the -A
    fields from the outside: line."""
    out = ["dmx512-1: Break", "dmx512-1: MAB", "dmx512-1: Start code", "dmx512-1: 0 / 0x0"]
    for n, value in enumerate(channels):
        out += ["dmx512-1: Channel %d" % (n + 1), "dmx512-1: %d / 0x%x" % (value, value)]
    return out


def run(transfer, log=print, polls=100_000):
    host = pe.Host(transfer)
    bench.load(host, bench_firmware.DMX512)
    host.start()
    waiting = list(WORDS)
    for _ in range(polls):
        if not waiting:
            break
        room = bench.DEPTH - host.status()["tx_level"]
        if room:
            host.push(waiting[:room])
            waiting = waiting[room:]
    found = bench.faults(host)
    log("%d words left, faults 0x%x" % (len(waiting), found))
    return not found and not waiting


if __name__ == "__main__":
    import time

    import pico_board

    log = bench.Log()
    spi = pico_board.PicoSpi()
    time.sleep_ms(bench.START_MS)
    bench.report(lambda: run(spi.transfer, log), log)
