# SPDX-License-Identifier: Apache-2.0
# A UDP broadcast from the chip every second on 10BASE-T, on the Tiny Tapeout demo board
# (MicroPython, ttboard). The project clock is 40 MHz; TD+ is uio[0] and TD- uio[1],
# through a 10BASE-T transformer to the RJ45. Untested until the board is here;
# test/test_ethernet.py sends the same frames through the RTL, the gates and the FPGA
# netlist.

import time

import demo_board
import ethernet
import ethernet_firmware


def run(count=10, clock_hz=40_000_000):
    spi = demo_board.DemoBoardSpi(clock_hz=clock_hz)
    host = demo_board.Host(spi.transfer)
    host.stop()
    host.configure(ethernet.CONFIG)
    host.load(ethernet_firmware.WORDS)
    for n in range(count):
        ethernet.send(host, ethernet.udp(("hello from the chip %d" % n).encode()))
        time.sleep(1)
