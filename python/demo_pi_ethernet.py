# SPDX-License-Identifier: Apache-2.0
# 10BASE-T from the Icepi into a Raspberry Pi 5 (MicroPython, Pico A): a UDP broadcast a
# second, with the firmware's link pulses between. TD+ on IO6, TD- on IO7, through 47 R
# each to the Teensy kit's MagJack. A bit is four cycles, so this needs the Icepi's 40 MHz
# build, and the host SPI at 5 MHz. Needs bench_firmware.py and ethernet.py on the Pico.

import bench
import bench_firmware
import ethernet
import protocol_emulator as pe

SPI_HZ = 5_000_000


def run(transfer, pause_ms, count=30, log=print):
    host = pe.Host(transfer)
    bench.load(host, bench_firmware.ETHERNET)
    for n in range(count):
        text = "hello from the chip %d" % n
        ethernet.send(host, ethernet.udp(text.encode()))
        log("sent %s" % text)
        pause_ms(1000)
    found = host.faults()
    log("faults 0x%x" % found)
    return not found


if __name__ == "__main__":
    import time

    import pico_board

    log = bench.Log()
    spi = pico_board.PicoSpi(baudrate=SPI_HZ)
    time.sleep_ms(bench.START_MS)
    bench.report(lambda: run(spi.transfer, time.sleep_ms, log=log), log)
