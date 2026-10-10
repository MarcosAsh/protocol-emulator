# SPDX-License-Identifier: Apache-2.0
# The standard settings on the bench's parts (MicroPython, Pico A), each firmware held to
# its sheet's limits in its protocol's file. i2c: the EEPROM demo in Standard-mode and in
# Fast-mode, on the master that holds START and STOP the quarters each mode needs. spi: the
# flash's JEDEC ID in modes 0 and 3, which a W25Q64 takes, and the same frame in modes 1 and
# 2, which it does not, for the analyser alone. uart: four bytes on OUT0 at a rate, for Pico
# B and the analyser. demo/rates.sh runs each.

import bench
import bench_firmware
import both_roles_firmware
import demo_eeprom
import demo_flash
import protocol_emulator as pe

UART_BYTES = [0x55, 0xA3, 0x00, 0xFF]
JEDEC = [0x9F, 0, 0, 0]


def i2c(transfer, clock, pause_ms, log=print):
    """The EEPROM demo once in each mode, at the quarter its rate's host sends."""
    passed = True
    for name in ("i2c_standard", "i2c_fast"):
        # the EEPROM demo sends demo_eeprom.QUARTER first; here each mode's own
        demo_eeprom.QUARTER = both_roles_firmware.LOADS[name]
        log("%s: quarter %d" % (name, demo_eeprom.QUARTER))
        firmware = getattr(bench_firmware, name.upper())
        passed = demo_eeprom.run(transfer, clock, pause_ms, log, firmware) and passed
        pause_ms(1)
    return passed


def spi(transfer, pause_ms, log=print):
    """Modes 0 and 3 have to read the flash's ID; 1 and 2 only send it, as the flash
    samples on the other edge."""
    host = pe.Host(transfer)
    passed = True
    for mode in range(4):
        demo_flash.start(host, getattr(bench_firmware, "SPI_CS_MODE%d" % mode))
        flash = demo_flash.Flash(host, pause_ms)
        if mode in (0, 3):
            flash.wake()
            jedec = flash.jedec_id()
            part = demo_flash.PARTS.get(tuple(jedec))
            log("mode %d: JEDEC ID %s, %s" % (mode, bench.hexs(jedec), part or "NOT A W25Q64"))
            passed = bool(part) and passed
        else:
            words = JEDEC[:-1] + [JEDEC[-1] | demo_flash.LAST]
            bench.exchange(host, words)
            log("mode %d: sent %s for the analyser" % (mode, bench.hexs(JEDEC)))
        found = bench.faults(host)
        if found:
            log("mode %d: faults 0x%x" % (mode, found))
            return False
        pause_ms(20)
    return passed


def uart(transfer, pause_ms, baud, log=print):
    """UART_BYTES at baud on OUT0, the bit period from both_roles_firmware.LOADS, and long
    enough a pause after for the last stop bit."""
    host = pe.Host(transfer)
    period = both_roles_firmware.LOADS["uart_tx_%d" % baud]
    bench.load(host, getattr(bench_firmware, "UART_TX_%d" % baud))
    host.start()
    host.push([period] + UART_BYTES)
    pause_ms(1 + (len(UART_BYTES) + 1) * 10 * period // 48_000)
    found = bench.faults(host)
    log("uart %d baud, %d cycles a bit: sent %s, faults 0x%x" % (
        baud, period, bench.hexs(UART_BYTES), found))
    return not found


def main(demo, baud=None):
    """One of demo/rates.sh's demos: i2c, spi, or uart at baud."""
    import time

    import pico_board

    log = bench.Log()
    port = pico_board.PicoSpi()
    time.sleep_ms(bench.START_MS)
    start = time.ticks_ms()
    demos = {
        "i2c": lambda: i2c(
            port.transfer, lambda: time.ticks_diff(time.ticks_ms(), start), time.sleep_ms,
            log),
        "spi": lambda: spi(port.transfer, time.sleep_ms, log),
        "uart": lambda: uart(port.transfer, time.sleep_ms, baud, log),
    }
    bench.report(demos[demo], log)
