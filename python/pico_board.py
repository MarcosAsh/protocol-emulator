# SPDX-License-Identifier: Apache-2.0
# Transport for a bare Pico wired to the chip's host port (MicroPython). SPI0 in mode 0:
# GP2 SCK -> ui[0], GP3 MOSI -> ui[1], GP4 MISO <- uo[0], GP5 CS_N -> ui[2]. SCK must stay
# at most an eighth of the chip's clock: 6 MHz at 48 MHz.

import machine
import micropython
from machine import Pin, SPI

from protocol_emulator import RX, STATUS, Host

# the longest rx read, a full level field's worth of words
RX_WORDS = 15


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
        self.reads = [bytes((reg, 0, 0)) for reg in range(16)]
        self.status = bytearray(3)
        rx_out = bytearray(1 + 2 * RX_WORDS)
        rx_out[0] = RX
        self.rx_in = bytearray(len(rx_out))
        out, into = memoryview(rx_out), memoryview(self.rx_in)
        self.rx_frames = [(out[:1 + 2 * n], into[:1 + 2 * n]) for n in range(RX_WORDS + 1)]

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

    @micropython.native
    def drain(self, stamps, reads):
        """Host's rx poll without its lists: append the selected engine's waiting words to
        stamps, then read each register in reads. Returns the frames sent."""
        spi, cs_n, status = self.spi, self.cs_n, self.status
        cs_n(0)
        spi.write_readinto(self.reads[STATUS], status)
        cs_n(1)
        level = (status[1] >> 2) & 15
        frames = 1 + len(reads)
        if level:
            out, into = self.rx_frames[level]
            cs_n(0)
            spi.write_readinto(out, into)
            cs_n(1)
            rx_in = self.rx_in
            for i in range(1, 1 + 2 * level, 2):
                stamps.append(rx_in[i] << 8 | rx_in[i + 1])
            frames += 1
        for reg in reads:
            cs_n(0)
            spi.write(self.reads[reg])
            cs_n(1)
        return frames


def host(**kwargs):
    return Host(PicoSpi(**kwargs).transfer)
