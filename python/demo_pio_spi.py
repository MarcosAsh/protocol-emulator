# SPDX-License-Identifier: Apache-2.0
# Raspberry Pi's spi.pio, byte for byte, its spi_cpha0_cs reading a W25Q64's JEDEC ID
# (MicroPython, Pico A): MOSI on OUT4, SCK and CSn on OUT5 and OUT6, MISO on IN0. Only with
# U4 fitted. demo/outside.sh pio_spi runs it.

import bench
import pio_firmware
import pio_upstream
import protocol_emulator as pe

FIRMWARE = pio_firmware.SPI
PARTS = {(0xEF, 0x40, 0x17): "W25Q64JV"}
# A byte is 384 cycles at k = 12, 8 us, and Pico A's 6 MHz pushes a command's words in
# well under that each, so CSn stays low through the command and rises when the fifo
# empties, as spi_cpha0_cs does. W25Q64JV: 3 us from Release Power-down to the next.
WAKE_MS = 1


def command(host, words, polls=10_000):
    """What came back during words, a byte for each."""
    host.push(words)
    for _ in range(polls):
        if bench.rx_level(host) >= len(words):
            return [w & 0xFF for w in host.pop(len(words))]
    raise RuntimeError("%d of %d bytes back" % (bench.rx_level(host), len(words)))


def run(transfer, pause_ms, log=print):
    host = pe.Host(transfer)
    pio_upstream.header(FIRMWARE, log)
    bench.load(host, FIRMWARE)
    host.start()
    wake, jedec = FIRMWARE["tx"]
    command(host, wake)
    pause_ms(WAKE_MS)
    ident = command(host, jedec)[1:]
    part = PARTS.get(tuple(ident))
    log("JEDEC ID %s: %s" % (bench.hexs(ident), part or "not a W25Q64JV (ef 40 17)"))
    found = bench.faults(host)
    log("faults 0x%x" % found)
    return bool(part) and not found


if __name__ == "__main__":
    import time

    import pico_board

    log = bench.Log()
    spi = pico_board.PicoSpi()
    time.sleep_ms(bench.START_MS)
    bench.report(lambda: run(spi.transfer, time.sleep_ms, log), log)
