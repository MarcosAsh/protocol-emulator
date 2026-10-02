# SPDX-License-Identifier: Apache-2.0
# 10BASE-T from the Icepi into a Raspberry Pi 5 (MicroPython, Pico A): a UDP broadcast
# a second from 10.0.0.2 port 1234, and between frames the link pulses every 16 ms that let
# the Pi bring the link up. TD+ on IO6, TD- on IO7, through 47 R each to the Teensy kit's
# MagJack. A bit is four cycles, so the Icepi runs the 40 MHz build (make -C icepi MHZ=40)
# and the host SPI is at most 5 MHz. Needs protocol_emulator.py, pico_board.py, bench.py,
# ethernet.py and ethernet_firmware.py on the Pico.

import bench
import ethernet
import ethernet_firmware
import protocol_emulator as pe

# the Manchester pair on IO6 and IO7, header 38 and 40
FIRMWARE = {"config": dict(ethernet.CONFIG, out_base=18, set_base=18), "words": ethernet_firmware.WORDS}
SPI_HZ = 5_000_000


def run(transfer, pause_ms, count=30, log=print):
    host = pe.Host(transfer)
    bench.load(host, FIRMWARE)
    for n in range(count):
        text = "hello from the chip %d" % n
        ethernet.send(host, ethernet.udp(text.encode()))
        log("sent %s" % text)
        pause_ms(1000)
    found = bench.faults(host)
    log("faults 0x%x" % found)
    return not found


if __name__ == "__main__":
    import time

    import pico_board

    log = bench.Log()
    spi = pico_board.PicoSpi(baudrate=SPI_HZ)
    time.sleep_ms(bench.START_MS)
    bench.report(lambda: run(spi.transfer, time.sleep_ms, log=log), log)
