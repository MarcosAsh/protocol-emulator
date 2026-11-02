# SPDX-License-Identifier: Apache-2.0
# A 10BASE-T UDP broadcast every second from the demo board (MicroPython, ttboard), at
# 40 MHz; TD+ is uio[0], TD- uio[1], through a transformer to the RJ45. The chip hears each
# one off uio[0] and engine 1's ethernet_rx hands it to the host, as demo_pi_ethernet.py
# has it on the Icepi. Untested on the board; test/test_ethernet.py sends and hears the
# same frames through RTL, gates and FPGA netlist. Needs ethernet_rx.hex and
# ethernet_rx.cert.hex on the board.

import time

import demo_board
import ethernet
import ethernet_firmware

TD_PLUS = 12
BASE = 256


def run(count=10, clock_hz=40_000_000):
    spi = demo_board.DemoBoardSpi(clock_hz=clock_hz)
    host = demo_board.Host(spi.transfer)
    for engine in (1, 0):
        host.select(engine)
        host.stop()
    host.configure(ethernet.CONFIG)
    host.load(ethernet_firmware.WORDS)
    host.certify(ethernet_firmware.CERTIFICATE, loaded=ethernet_firmware.LOADED)
    ethernet.load_receiver(host, 1)
    passed = True
    for n in range(count):
        status, data, got = ethernet.heard(
            host, ethernet.udp(("hello from the chip %d" % n).encode()), TD_PLUS, BASE)
        ok = status["finished"] and status["fcs_ok"] and got == data
        passed = passed and ok
        print("frame %d heard, fcs_ok %d: %s" % (n, status["fcs_ok"], "PASS" if ok else "FAIL"))
        time.sleep(1)
    print("PASS" if passed else "FAIL")
    return passed
