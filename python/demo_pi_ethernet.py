# SPDX-License-Identifier: Apache-2.0
# 10BASE-T from the Icepi into a Raspberry Pi 5 or a laptop's adapter (MicroPython, Pico A):
# a UDP broadcast a second, with the firmware's link pulses between. TD+ on IO6, TD- on
# IO7, through 47 R each to the Teensy kit's MagJack. The chip hears each frame too: its
# receiver takes TD+ back off the pad and engine 1's ethernet_rx hands the frame to the
# host, which holds it to what was sent, with the FCS engine 0's CRC unit made judged
# good. A bit is four cycles, so this needs the Icepi's 40 MHz build, and the host SPI at
# 5 MHz. Needs bench_firmware.py, ethernet.py, ethernet_rx.hex and ethernet_rx.cert.hex on
# the Pico.

import bench
import bench_firmware
import ethernet
import protocol_emulator as pe

SPI_HZ = 5_000_000
TD_PLUS = 18
# where the chip's own frames land, past the one it sends from 0
BASE = 256


def run(transfer, pause_ms, count=30, log=print):
    host = pe.Host(transfer)
    bench.load(host, bench_firmware.ETHERNET)
    ethernet.load_receiver(host, 1)
    host.select(0)
    passed = True
    for n in range(count):
        text = "hello from the chip %d" % n
        status, data, got = ethernet.heard(host, ethernet.udp(text.encode()), TD_PLUS, BASE)
        ok = status["finished"] and status["fcs_ok"] and not status["dropped"] and got == data
        passed = passed and ok
        log("sent %s, heard %d words, fcs_ok %d: %s" % (
            text, status["words"], status["fcs_ok"], "PASS" if ok else "FAIL"))
        pause_ms(1000)
    found = 0
    for engine in (0, 1):
        host.select(engine)
        found |= bench.faults(host)
    log("faults 0x%x" % found)
    return passed and not found


if __name__ == "__main__":
    import time

    import pico_board

    log = bench.Log()
    spi = pico_board.PicoSpi(baudrate=SPI_HZ)
    time.sleep_ms(bench.START_MS)
    bench.report(lambda: run(spi.transfer, time.sleep_ms, log=log), log)
