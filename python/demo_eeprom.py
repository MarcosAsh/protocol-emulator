# SPDX-License-Identifier: Apache-2.0
# A 24LC256 on the library's I2C master (MicroPython, Pico A): SDA on IO2, SCL on IO3, each
# pulled up to 3.3 V. Finds the chip, then a byte write and a page write, each ACK polled to
# the end of its write cycle and read back. The old contents seed what is written, so a run
# that writes nothing cannot pass. Pico B shares the bus for the start hold act, so the run
# first listens and refuses if Pico B is mastering it. demo/outside.sh eeprom copies what it
# needs and runs it.

import bench
import bench_firmware
import protocol_emulator as pe

# A repeated START's setup is a quarter less SCL's rise, and Fast-mode wants 600 ns. A
# quarter of 31 cycles, the most `set` makes, leaves about 400 ns behind 4.7 k and 45 pF,
# so the host sends 48, 1 us: SCL at 250 kHz.
QUARTER = 48
PAGE = 64
# the last page, and the byte before it
PAGE_ADDRESS = 0x7FC0
BYTE_ADDRESS = 0x7FBF
# twice the 5 ms a write cycle takes at most
WRITE_LIMIT_MS = 10
# demo/start_hold_master starts a read, two STARTs, every 20 ms
GUARD_MS = 25


def word(data=0, start=False, read=False, stop=False):
    """A host word of Firmware.i2c_master: start[15] read[14] data[13:6] stop[5]."""
    return (start << 15) | (read << 14) | ((data & 0xFF) << 6) | (stop << 5)


class Eeprom:
    """clock() is milliseconds from any start."""

    def __init__(self, host, device, clock=None):
        self.host = host
        self.device = device
        self.clock = clock

    def acked(self):
        """START, the address for a write and STOP: whether the chip answered."""
        return bench.exchange(self.host, [word(self.device << 1, start=True, stop=True)]) == [0]

    def poll(self):
        """NACKs before the chip answers again, which it does once its write cycle ends,
        and the milliseconds that took."""
        start = self.clock()
        nacks = 0
        while not self.acked():
            nacks += 1
            if self.clock() - start > WRITE_LIMIT_MS:
                raise RuntimeError("no ACK %d ms after the write" % WRITE_LIMIT_MS)
        return nacks, self.clock() - start

    def write(self, address, data):
        words = [word(self.device << 1, start=True), word(address >> 8), word(address)]
        words += [word(b) for b in data[:-1]] + [word(data[-1], stop=True)]
        acks = bench.exchange(self.host, words)
        if any(acks):
            raise RuntimeError("write at 0x%04x: NACK in %s" % (address, acks))
        return self.poll()

    def read(self, address, count):
        """A random read, sequential past the first byte: a dummy write sets the address,
        then a repeated START reads, ACKing every byte but the last."""
        words = [word(self.device << 1, start=True), word(address >> 8), word(address)]
        words += [word((self.device << 1) | 1, start=True)]
        words += [word(read=True)] * (count - 1) + [word(read=True, stop=True)]
        replies = bench.exchange(self.host, words)
        if any(replies[:4]):
            raise RuntimeError("read at 0x%04x: NACK in %s" % (address, replies[:4]))
        return replies[4:]


def bus_free(host, pause_ms):
    """Whether engine 1's START_HOLD, which drives neither line, heard no START in
    GUARD_MS. Its fifo outlasts the STARTs Pico B makes in that time."""
    bench.load(host, bench_firmware.START_HOLD, engine=1)
    host.start()
    pause_ms(GUARD_MS)
    return not bench.rx_level(host)


def find(host):
    for device in range(0x50, 0x58):
        if Eeprom(host, device).acked():
            return device
    return None


def run(transfer, clock, pause_ms, log=print, firmware=bench_firmware.I2C_MASTER):
    """firmware is I2C_MASTER or I2C_MASTER_STRETCH, which take the same words."""
    host = pe.Host(transfer)
    if not bus_free(host, pause_ms):
        log("Pico B is mastering the bus: load MicroPython or can_node")
        return False
    bench.load(host, firmware)
    host.start()
    # the quarter comes first and is not answered
    host.push([QUARTER])
    device = find(host)
    if device is None:
        log("no ACK from 0x50 to 0x57: check the pull-ups, SDA, SCL and 3.3 V")
        return False
    log("24LC256 at 0x%02x" % device)
    eeprom = Eeprom(host, device, clock)

    old = eeprom.read(BYTE_ADDRESS, 1)[0]
    value = (old + 1) & 0xFF
    nacks, ms = eeprom.write(BYTE_ADDRESS, [value])
    got = eeprom.read(BYTE_ADDRESS, 1)[0]
    log("byte write 0x%04x: %02x -> %02x, %d NACKs over %d ms, read back %02x" % (
        BYTE_ADDRESS, old, value, nacks, ms, got))

    seed = eeprom.read(PAGE_ADDRESS, 1)[0] + 1
    page = [(seed + 13 * i) & 0xFF for i in range(PAGE)]
    nacks, ms = eeprom.write(PAGE_ADDRESS, page)
    back = eeprom.read(PAGE_ADDRESS, PAGE)
    log("page write 0x%04x, %d bytes from %02x: %d NACKs over %d ms, read back %s ..., %s" % (
        PAGE_ADDRESS, PAGE, page[0], nacks, ms, bench.hexs(back[:8]),
        "equal" if back == page else "DIFFERS"))
    found = bench.faults(host)
    log("faults 0x%x" % found)
    return got == value and back == page and not found


def main(firmware):
    import time

    import pico_board

    log = bench.Log()
    spi = pico_board.PicoSpi()
    time.sleep_ms(bench.START_MS)
    start = time.ticks_ms()
    bench.report(lambda: run(
        spi.transfer, lambda: time.ticks_diff(time.ticks_ms(), start), time.sleep_ms, log,
        firmware), log)


if __name__ == "__main__":
    main(bench_firmware.I2C_MASTER)
