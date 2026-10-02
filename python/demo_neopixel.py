# SPDX-License-Identifier: Apache-2.0
# An Adafruit NeoPixel Stick 8 (SK6812) on the library's WS2812 firmware (MicroPython,
# Pico A): OUT0 through a 74AHCT125 at 5 V to DIN. Two frames: PIXELS, then the same turned
# by one, which the stick keeps showing. Needs protocol_emulator.py, pico_board.py,
# bench.py and bench_firmware.py on the Pico, which demo/outside.sh neopixel copies.

import bench
import bench_firmware
import protocol_emulator as pe

# red, green, blue, low enough that USB powers the stick
PIXELS = [
    (0x20, 0x00, 0x00), (0x00, 0x20, 0x00), (0x00, 0x00, 0x20), (0x20, 0x20, 0x00),
    (0x00, 0x20, 0x20), (0x20, 0x00, 0x20), (0x12, 0x34, 0x56), (0x01, 0x02, 0x04),
]
# A pixel takes 24 bits of 55 cycles, so the firmware takes a word every 13.75 us on
# average. Every word of a frame goes in one SPI frame, at a clock that brings a word every
# 10.7 us: never later than the firmware wants it, and never more than the fifo holds.
SPI_HZ = 1_500_000
# The SK6812 latches after 80 us low, and the firmware's own gap is 53 us
LATCH_MS = 1


def words(pixels):
    """Ws2812.Pixel.words: green and red, then blue, each sent from the top bit."""
    out = []
    for red, green, blue in pixels:
        out += [(green << 8) | red, blue << 8]
    return out


def run(transfer, pause_ms, log=print):
    host = pe.Host(transfer)
    bench.load(host, bench_firmware.SK6812)
    host.start()
    frames = [PIXELS, PIXELS[1:] + PIXELS[:1]]
    for pixels in frames:
        host.push(words(pixels))
        pause_ms(LATCH_MS)
        log("frame: %s" % " ".join("#%02x%02x%02x" % p for p in pixels))
    found = bench.faults(host)
    log("faults 0x%x" % found)
    return not found


if __name__ == "__main__":
    import time

    import pico_board

    log = bench.Log()
    spi = pico_board.PicoSpi(baudrate=SPI_HZ)
    time.sleep_ms(bench.START_MS)
    bench.report(lambda: run(spi.transfer, time.sleep_ms, log), log)
