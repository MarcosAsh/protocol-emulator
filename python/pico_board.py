# SPDX-License-Identifier: Apache-2.0
# Transport for a bare Pico wired to the chip's host port (MicroPython). SPI0 in mode 0:
# GP2 SCK -> ui[0], GP3 MOSI -> ui[1], GP4 MISO <- uo[0], GP5 CS_N -> ui[2]. SCK must stay
# at most an eighth of the chip's clock: 6 MHz at 48 MHz.

import machine
import micropython
from machine import Pin, SPI

from protocol_emulator import Host


class PicoSpi:
    def __init__(self, baudrate=6_000_000):
        # at the stock 125 MHz the demos poll slower than 9600 baud's edges arrive
        machine.freq(200_000_000)
        self.spi = SPI(
            0, baudrate=baudrate, polarity=0, phase=0, bits=8, firstbit=SPI.MSB,
            sck=Pin(2), mosi=Pin(3), miso=Pin(4),
        )
        self.cs_n = Pin(5, Pin.OUT, value=1)
        self.buffers = {}

    @micropython.native
    def transfer(self, data):
        n = len(data)
        pair = self.buffers.get(n)
        if pair is None:
            pair = (bytearray(n), bytearray(n))
            self.buffers[n] = pair
        out, reply = pair
        for i in range(n):
            out[i] = data[i]
        self.cs_n(0)
        self.spi.write_readinto(out, reply)
        self.cs_n(1)
        return bytes(reply)


def host(**kwargs):
    return Host(PicoSpi(**kwargs).transfer)
