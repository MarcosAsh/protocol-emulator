# SPDX-License-Identifier: Apache-2.0
# A DS18B20 on the library's 1-Wire master (MicroPython, Pico A): DQ on IO4 pulled up by
# 4.7 k, VDD at 3.3 V. Reset and presence, READ ROM with its CRC, CONVERT T polled to its
# end, then READ SCRATCHPAD with its CRC and the temperature. demo/outside.sh ds18b20
# copies what it needs and runs it.

import bench
import bench_firmware
import protocol_emulator as pe

# 6 us at 48 MHz, the One_wire.firmware unit
UNIT = 288
RESET = 1
READ_ROM = 0x33
SKIP_ROM = 0xCC
CONVERT_T = 0x44
READ_SCRATCHPAD = 0xBE
FAMILY = 0x28
# 750 ms at 12 bits, and a poll is eight read slots and the Pico's overhead, about a millisecond
POLLS = 3000
# the power-on value of the temperature register, which a conversion replaces
POWER_ON = 0x0550
# the configuration register's fixed bits, which a line held low would not read as
CONFIG_MASK = 0x9F
CONFIG_FIXED = 0x1F


def crc8(data):
    """Dallas CRC-8, x^8 + x^5 + x^4 + 1 over bytes LSB first: zero over a whole ROM or
    scratchpad."""
    crc = 0
    for byte in data:
        for _ in range(8):
            mix = (crc ^ byte) & 1
            crc >>= 1
            if mix:
                crc ^= 0x8C
            byte >>= 1
    return crc


class Wire:
    def __init__(self, host):
        self.host = host

    def reset(self):
        """Whether a device answered the reset with a presence pulse."""
        return bench.exchange(self.host, [RESET]) == [0]

    def write(self, data):
        """Each byte as it was seen on the line: itself unless a device held it low."""
        return bench.exchange(self.host, [(b & 0xFF) << 1 for b in data])

    def read(self, count):
        return self.write([0xFF] * count)


def temperature(scratchpad):
    raw = scratchpad[0] | (scratchpad[1] << 8)
    return raw - 0x10000 if raw & 0x8000 else raw


def run(transfer, log=print):
    host = pe.Host(transfer)
    bench.load(host, bench_firmware.ONE_WIRE)
    host.start()
    # the unit comes first and is not answered
    host.push([UNIT])
    wire = Wire(host)
    if not wire.reset():
        log("no presence pulse: check DQ, the 4.7 k pull-up and 3.3 V on VDD")
        return False
    log("presence")

    wire.write([READ_ROM])
    rom = wire.read(8)
    rom_ok = crc8(rom) == 0 and rom[0] == FAMILY
    log("ROM %s: family %02x, CRC %s" % (
        bench.hexs(rom), rom[0], "good" if crc8(rom) == 0 else "BAD"))

    wire.reset()
    wire.write([SKIP_ROM, CONVERT_T])
    for polls in range(POLLS):
        # a converting DS18B20 holds read slots low, and lets them go once it is done
        if wire.read(1)[0]:
            break
    else:
        log("CONVERT T: still converting after %d polls" % POLLS)
        return False
    log("CONVERT T: %d polls busy, then done" % polls)

    wire.reset()
    wire.write([SKIP_ROM, READ_SCRATCHPAD])
    pad = wire.read(9)
    raw = temperature(pad)
    pad_ok = crc8(pad) == 0 and pad[4] & CONFIG_MASK == CONFIG_FIXED
    log("scratchpad %s: CRC %s, configuration %02x, %d/16 = %.4f C" % (
        bench.hexs(pad), "good" if crc8(pad) == 0 else "BAD", pad[4], raw, raw / 16))
    found = bench.faults(host)
    log("faults 0x%x" % found)
    return rom_ok and pad_ok and raw != POWER_ON and -55 * 16 <= raw <= 125 * 16 and not found


if __name__ == "__main__":
    import time

    import pico_board

    log = bench.Log()
    spi = pico_board.PicoSpi()
    time.sleep_ms(bench.START_MS)
    bench.report(lambda: run(spi.transfer, log), log)
