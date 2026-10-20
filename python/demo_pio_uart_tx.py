# SPDX-License-Identifier: Apache-2.0
# Raspberry Pi's uart_tx.pio, byte for byte, sending uart_tx.c's own string at 115200 baud
# on OUT0, Pico B's GP1 through 1 k (MicroPython, Pico A). demo/outside.sh pio_uart_tx runs
# it and sigrok decodes OUT0.

import bench
import pio_firmware
import pio_upstream
import protocol_emulator as pe

FIRMWARE = pio_firmware.UART_TX
# a character is 10 bits of 8.7 us: the last has gone well within this once the fifo is empty
LAST_MS = 1


def run(transfer, pause_ms, log=print):
    host = pe.Host(transfer)
    pio_upstream.header(FIRMWARE, log)
    bench.load(host, FIRMWARE)
    host.start()
    for words in FIRMWARE["tx"]:
        pio_upstream.feed(host, words)
    pio_upstream.drain(host)
    pause_ms(LAST_MS)
    log("sent %r" % FIRMWARE["data"])
    found = bench.faults(host)
    log("faults 0x%x" % found)
    return not found


if __name__ == "__main__":
    import time

    import pico_board

    log = bench.Log()
    spi = pico_board.PicoSpi()
    time.sleep_ms(bench.START_MS)
    bench.report(lambda: run(spi.transfer, time.sleep_ms, log), log)
