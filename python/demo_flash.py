# SPDX-License-Identifier: Apache-2.0
# A W25Q64 on the library's SPI master (MicroPython, Pico A): MOSI on OUT0, SCK on OUT1,
# MISO on IN0, and CS from Pico A's GP8, held low across each command since the firmware
# drives none. JEDEC ID, then the last sector erased, a page programmed and read back, and
# the sector erased again. demo/outside.sh flash copies what it needs and runs it.

import bench
import bench_firmware
import protocol_emulator as pe

CS_PIN = 8
# Winbond, SPI NOR, then the capacity: the 128 Mbit part has the same commands
PARTS = {(0xEF, 0x40, 0x17): "W25Q64JV", (0xEF, 0x40, 0x18): "W25Q128JV"}
SECTOR = 0x7FF000
PAGE = 256
# W25Q64JV datasheet maxima: 3 ms a page program, 400 ms a sector erase
PROGRAM_MS = 3
ERASE_MS = 400


class Flash:
    """cs(level) drives the chip select and pause_ms(n) waits."""

    def __init__(self, host, cs, pause_ms):
        self.host = host
        self.cs = cs
        self.pause_ms = pause_ms

    def command(self, data, reply=0):
        """The bytes of data with CS low throughout, then reply bytes more, and what
        came back during those."""
        self.cs(0)
        got = bench.exchange(self.host, list(data) + [0] * reply)
        self.cs(1)
        return [b & 0xFF for b in got[len(data):]]

    def wake(self):
        """Release from power down, which a W25Q64 needs 3 us after."""
        self.command([0xAB])
        self.pause_ms(1)

    def jedec_id(self):
        return self.command([0x9F], 3)

    def status(self):
        return self.command([0x05], 1)[0]

    def wait_ready(self, limit_ms):
        """Milliseconds until BUSY clears, polling every one."""
        for ms in range(limit_ms + 2):
            if not self.status() & 1:
                return ms
            self.pause_ms(1)
        raise RuntimeError("still busy after %d ms" % limit_ms)

    def write_enable(self):
        self.command([0x06])
        if not self.status() & 2:
            raise RuntimeError("write enable latch not set")

    def read(self, address, count):
        return self.command([0x03] + address_bytes(address), count)

    def program(self, address, data):
        self.write_enable()
        self.command([0x02] + address_bytes(address) + list(data))
        return self.wait_ready(PROGRAM_MS)

    def erase(self, address):
        self.write_enable()
        self.command([0x20] + address_bytes(address))
        return self.wait_ready(ERASE_MS)


def address_bytes(address):
    return [(address >> 16) & 0xFF, (address >> 8) & 0xFF, address & 0xFF]


def pattern():
    return [(7 * i) & 0xFF for i in range(PAGE)]


def start(host):
    bench.load(host, bench_firmware.SPI_MASTER)
    host.start()


def run(transfer, cs, pause_ms, log=print):
    host = pe.Host(transfer)
    start(host)
    flash = Flash(host, cs, pause_ms)
    flash.wake()
    jedec = flash.jedec_id()
    part = PARTS.get(tuple(jedec))
    log("JEDEC ID %s: %s" % (bench.hexs(jedec), part or "not a W25Q64JV (ef 40 17)"))
    if not part:
        return False
    ms = flash.erase(SECTOR)
    blank = flash.read(SECTOR, PAGE)
    log("erase 0x%06x: %d ms, %s" % (SECTOR, ms, "blank" if blank == [0xFF] * PAGE else "NOT BLANK"))
    data = pattern()
    ms = flash.program(SECTOR, data)
    back = flash.read(SECTOR, PAGE)
    log("program %d bytes: %d ms, read back %s ..., %s" % (
        PAGE, ms, bench.hexs(back[:8]), "equal" if back == data else "DIFFERS"))
    ms = flash.erase(SECTOR)
    erased = flash.read(SECTOR, PAGE)
    log("erase again: %d ms, %s" % (ms, "blank" if erased == [0xFF] * PAGE else "NOT BLANK"))
    found = bench.faults(host)
    log("faults 0x%x" % found)
    return blank == [0xFF] * PAGE and back == data and erased == [0xFF] * PAGE and not found


if __name__ == "__main__":
    import time

    from machine import Pin

    import pico_board

    log = bench.Log()
    cs = Pin(CS_PIN, Pin.OUT, value=1)
    spi = pico_board.PicoSpi()
    time.sleep_ms(bench.START_MS)
    bench.report(lambda: run(spi.transfer, cs, time.sleep_ms, log), log)
