# SPDX-License-Identifier: Apache-2.0
# CAN at 500 kbit/s from the library's transmitter (MicroPython, Pico A): OUT1 into an
# SN65HVD230's D, the bus to Pico B running demo/can_node, which ACKs. OUT1 is dominant
# from reset until it has the period, so the run arms first, then waits 11
# recessive bits before the frames, as the firmware waits for no idle bus.

import bench
import bench_firmware
import protocol_emulator as pe

# Can.period: 96 cycles a bit at 48 MHz
PERIOD = 96
# 11 recessive bits are 22 us, and the Pico cannot wait less than this
IDLE_MS = 1
# a frame is at most 135 bits with its stuff bits, 270 us
FRAME_MS = 2
# (id, data), as the sigrok scenario test/traces/sigrok/can.trace sends the first two
FRAMES = [
    (0x123, [0xDE, 0xAD]),
    (0x555, [0x00, 0xFF, 0x55, 0xAA, 0x01, 0x80, 0x7F, 0xFE]),
    (0x7EF, []),
    (0x000, [0x01]),
]


def bits(value, width):
    return [(value >> (width - 1 - i)) & 1 for i in range(width)]


def words(ident, data):
    """Can.words of a data frame: the bits after SOF less one, then ID, RTR, IDE, r0, DLC
    and the data, MSB first sixteen to a word."""
    fields = bits(ident, 11) + [0, 0, 0] + bits(len(data), 4)
    for byte in data:
        fields += bits(byte, 8)
    out = [len(fields) - 1]
    for i in range(0, len(fields), 16):
        chunk = fields[i:i + 16]
        out.append(sum(bit << (15 - n) for n, bit in enumerate(chunk)))
    return out


def arm(transfer, log=print):
    """Loads the transmitter and sends the period, after which the pin stays recessive."""
    host = pe.Host(transfer)
    bench.load(host, bench_firmware.CAN)
    host.start()
    host.push([PERIOD])
    log("armed: OUT1 is recessive")


def run(transfer, pause_ms, log=print):
    host = pe.Host(transfer)
    host.select(0)
    if bench.faults(host):
        log("engine 0 holds faults 0x%x: reset first" % bench.faults(host))
        return False
    # again if armed already, which a stopped engine's OUT1 stays recessive through
    arm(transfer, log)
    pause_ms(IDLE_MS)
    for ident, data in FRAMES:
        host.push(words(ident, data))
        pause_ms(FRAME_MS)
        log(" ".join(["sent id 0x%03x dlc %d" % (ident, len(data))] + ["%02x" % b for b in data]))
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
