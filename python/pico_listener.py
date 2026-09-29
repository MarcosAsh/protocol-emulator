# SPDX-License-Identifier: Apache-2.0
# Prints what the chip's UARTs send (MicroPython, second Pico). OUT0 -> GP1 (UART0 RX),
# OUT1 -> GP5 (UART1 RX). The baud rate is the chip's clock over the firmware's period.

import time

from machine import Pin, UART


def listen(baudrate=115_200):
    ports = [
        ("OUT0", UART(0, baudrate=baudrate, tx=Pin(0), rx=Pin(1))),
        ("OUT1", UART(1, baudrate=baudrate, tx=Pin(4), rx=Pin(5))),
    ]
    while True:
        for name, port in ports:
            data = port.read()
            if data:
                print(name, " ".join("%02x" % b for b in data))
        time.sleep_ms(5)
