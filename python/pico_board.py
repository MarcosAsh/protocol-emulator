# SPDX-License-Identifier: Apache-2.0
# Transport for a bare Pico wired to the chip's host port (MicroPython). SPI0 in mode 0:
# GP2 SCK -> ui[0], GP3 MOSI -> ui[1], GP4 MISO <- uo[0], GP5 CS_N -> ui[2]. SCK must stay
# at most an eighth of the chip's clock.

from machine import Pin, SPI

from protocol_emulator import Host


class PicoSpi:
    def __init__(self, baudrate=1_000_000):
        self.spi = SPI(
            0, baudrate=baudrate, polarity=0, phase=0, bits=8, firstbit=SPI.MSB,
            sck=Pin(2), mosi=Pin(3), miso=Pin(4),
        )
        self.cs_n = Pin(5, Pin.OUT, value=1)

    def transfer(self, data):
        out = bytes(data)
        reply = bytearray(len(out))
        self.cs_n(0)
        self.spi.write_readinto(out, reply)
        self.cs_n(1)
        return list(reply)


def host(**kwargs):
    return Host(PicoSpi(**kwargs).transfer)
