# SPDX-License-Identifier: Apache-2.0
# USB PD Source_Capabilities from the library's BMC transmitter (MicroPython, Pico A). OUT0
# carries the BMC level, low when idle, at 300 kbps. demo/outside.sh usb_power_delivery runs
# it and takes its settings from the next line.
# outside: analyser=A ms=2000 decode=-P usb_power_delivery:cc1=D4 -A usb_power_delivery=header:data:crc:warnings:src:payload

import bench
import bench_firmware
import protocol_emulator as pe

# USB PD r3.2 v1.2 table 5.2 (p.89): the 5b symbol for each nibble, b0 first on the line
SYMBOLS = [0b11110, 0b01001, 0b10100, 0b10101, 0b01010, 0b01011, 0b01110, 0b01111,
           0b10010, 0b10011, 0b10110, 0b10111, 0b11010, 0b11011, 0b11100, 0b11101]
SOP = [0b11000, 0b11000, 0b11000, 0b10001]
EOP = 0b01101

# a Revision 3.x Source and DFP, MessageID 0, with one Fixed 5 V 3 A PDO
HEADER = 0x11A1
PDOS = [0x0001912C]


def crc32(data):
    crc = 0xFFFFFFFF
    for byte in data:
        crc ^= byte
        for _ in range(8):
            crc = (crc >> 1) ^ 0xEDB88320 if crc & 1 else crc >> 1
    return crc ^ 0xFFFFFFFF


def words(header, pdos):
    """The number of bits after the preamble minus one, then the bits, 16 per word, LSB
    first."""
    payload = [header & 0xFF, header >> 8]
    for pdo in pdos:
        payload += [(pdo >> (8 * i)) & 0xFF for i in range(4)]
    crc = crc32(payload)
    data = payload + [(crc >> (8 * i)) & 0xFF for i in range(4)]
    symbols = SOP + [SYMBOLS[n] for byte in data for n in (byte & 0xF, byte >> 4)] + [EOP]
    bits = [(s >> i) & 1 for s in symbols for i in range(5)]
    packed = [sum(bit << i for i, bit in enumerate(bits[k:k + 16]))
              for k in range(0, len(bits), 16)]
    return [len(bits) - 1] + packed


def lines(header, pdos):
    """What sigrok's usb_power_delivery decoder prints for a Source_Capabilities message
    from a Revision 3.x source (each PDO a Fixed one), with the -A fields from the
    outside: line."""
    payload = [header & 0xFF, header >> 8]
    for pdo in pdos:
        payload += [(pdo >> (8 * i)) & 0xFF for i in range(4)]
    out = ["H:%04x" % header, "(r3) SRC[%d]: SOURCE CAP" % ((header >> 9) & 7)]
    for n, pdo in enumerate(pdos):
        volts, amps = ((pdo >> 10) & 0x3FF) / 20, (pdo & 0x3FF) / 100
        out += ["[%d]%08x" % (n, pdo),
                "[%d] [Fixed] %gV %gA (%gW)" % (n + 1, volts, amps, volts * amps)]
    out += ["CRC:%08x" % crc32(payload)]
    return ["usb_power_delivery-1: " + line for line in out]


def run(transfer, log=print):
    host = pe.Host(transfer)
    bench.load(host, bench_firmware.USB_POWER_DELIVERY)
    host.start()
    host.push(words(HEADER, PDOS))
    found = bench.faults(host)
    log("faults 0x%x" % found)
    return not found


if __name__ == "__main__":
    import time

    import pico_board

    log = bench.Log()
    spi = pico_board.PicoSpi()
    time.sleep_ms(bench.START_MS)
    bench.report(lambda: run(spi.transfer, log), log)
