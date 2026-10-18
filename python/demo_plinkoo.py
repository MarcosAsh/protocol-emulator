# SPDX-License-Identifier: Apache-2.0
# Plinkoo (PLK-2 rev. 1.3), the controller's end (MicroPython, Pico A): STB on OUT5, the
# flash's CLK with its CS high, analyser B's D0; DAT on IO3, SDA with its 2k2 pull-up, B's
# D6. Section 6's frame, then one of eight bytes, and the ack bit of each: no bench part
# answers Plinkoo, so both read NACK there. demo/outside.sh plinkoo runs it.
# outside: analyser=B ms=2000 decode=-P plinkoo:stb=D0:dat=D6 -A plinkoo=length:byte:checksum-ok:checksum-err:ack:nack

import bench
import bench_firmware
import protocol_emulator as pe

FRAMES = [[0x12, 0x34, 0x56], [0x00, 0xFF, 0x80, 0x01, 0xA5, 0x5A, 0x7E, 0xC3]]


def words(payload):
    """L then each byte, each in a word's high byte."""
    return [b << 8 for b in [len(payload)] + payload]


def run(transfer, pause_ms, log=print):
    host = pe.Host(transfer)
    bench.load(host, bench_firmware.PLINKOO)
    host.start()
    for payload in FRAMES:
        host.push(words(payload))
        pause_ms(1)
    acks = host.pop(len(FRAMES))
    for payload, ack in zip(FRAMES, acks):
        log("frame %s: %s" % (" ".join("%02X" % b for b in payload), "NACK" if ack else "ACK"))
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
