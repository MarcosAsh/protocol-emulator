# SPDX-License-Identifier: Apache-2.0
# Raspberry Pi's ws2812.pio, byte for byte, on the SK6812 stick (MicroPython, Pico A): OUT3,
# pulled down by 10 k, through the 74AHCT125 at 5 V to DIN. Two frames, the second the first
# turned by one, which the stick keeps showing. demo/outside.sh pio_ws2812 runs it.

import bench
import pio_firmware
import pio_upstream
import protocol_emulator as pe

FIRMWARE = pio_firmware.WS2812
# A pixel is two 12-bit host words of 720 cycles at k = 6, a word every 15 us. A frame's 16
# go in one SPI frame at 1.5 MHz, a word every 10.7 us, 12.7 with the RP2040's pause after
# each byte: always before the firmware wants one, and at most five waiting. ws2812.pio
# has no latch gap of its own, ws2812.c's caller leaves it, so LATCH_MS between frames.
SPI_HZ = 1_500_000
LATCH_MS = 1


def run(transfer, pause_ms, log=print):
    host = pe.Host(transfer)
    pio_upstream.header(FIRMWARE, log)
    bench.load(host, FIRMWARE)
    host.start()
    pause_ms(LATCH_MS)
    for words in FIRMWARE["tx"]:
        host.push(words)
        pause_ms(LATCH_MS)
    for pixels in FIRMWARE["data"]:
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
