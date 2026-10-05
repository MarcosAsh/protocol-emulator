# SPDX-License-Identifier: Apache-2.0
# A 10BASE-T UDP broadcast every second from the demo board (MicroPython, ttboard), at
# 40 MHz; TD+ is uio[0], TD- uio[1], through a transformer to the RJ45. Untested on the
# board; test/test_ethernet.py sends the same frames through RTL, gates and FPGA netlist.

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
    host.certify(ethernet_firmware.CERTIFICATE, loaded=ethernet_firmware.LOADED)
    for n in range(count):
        ethernet.send(host, ethernet.udp(("hello from the chip %d" % n).encode()))
        time.sleep(1)
