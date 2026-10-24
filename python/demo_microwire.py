# SPDX-License-Identifier: Apache-2.0
# MICROWIRE (AN-452), the controller's end (MicroPython, Pico A): CS on OUT6, the flash's
# CS, analyser B's D3; SK on OUT5, the flash's CLK, B's D0; DI on OUT4, the flash's DI,
# B's D1; DO on IN0, the flash's DO, B's D2. CS high deselects the flash. EWEN, READ 5,
# WRITE 5 with its 25.94 ms CS low, READ 5: no bench part answers, so DO is not judged.
# demo/outside.sh microwire runs it.
# outside: analyser=B ms=2000 decode=-P microwire:cs=D3:sk=D0:si=D1:so=D2 -A microwire=start-bit:si-bit:so-bit

import bench
import bench_firmware
import protocol_emulator as pe


def bits(value, width):
    return [(value >> (width - 1 - i)) & 1 for i in range(width)]


def frame(frame_bits, erase_write=False):
    """A header, bit 15 erase/write and the bits less one, then the bits MSB first."""
    words = [(0x8000 if erase_write else 0) | (len(frame_bits) - 1)]
    for i in range(0, len(frame_bits), 16):
        word = 0
        for j, b in enumerate(frame_bits[i : i + 16]):
            word |= b << (15 - j)
        words.append(word)
    return words


def instruction(op, field):
    """p.6: the start bit, two opcode bits and six more."""
    return bits(0x100 | op << 6 | field, 9)


EWEN = frame(instruction(0b11, 0b000001))


def read(address):
    return frame(instruction(0b00, address) + [0] * 16)


def write(address, value):
    return frame(instruction(0b10, address) + bits(value, 16), erase_write=True)


def run(transfer, pause_ms, log=print):
    host = pe.Host(transfer)
    bench.load(host, bench_firmware.MICROWIRE)
    host.start()
    host.push(EWEN + read(5) + write(5, 0xA5C3))
    pause_ms(40)
    host.push(read(5))
    pause_ms(2)
    words = host.pop(4)
    log("DO's last 16 bits a frame: %s" % " ".join("%04X" % w for w in words))
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
