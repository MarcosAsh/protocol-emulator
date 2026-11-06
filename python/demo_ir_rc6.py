# SPDX-License-Identifier: Apache-2.0
# Philips RC-6 mode 0 from the library's transmitter (MicroPython, Pico A). OUT0 is high
# for a mark, with no 36 kHz carrier, and is seen by analyser A's D4 and Pico B's GP1.
# Sends two frames, with the trailer bit low, then high.
# outside: analyser=A ms=2000 decode=-P ir_rc6:ir=D4 -A ir_rc6=address:command

import bench
import bench_firmware
import protocol_emulator as pe

# Ir_rc6.standard_unit: 444 us at 48 MHz
UNIT = 21333
# (toggle, address, command), as test/ir_rc6.ml sends them
FRAMES = [(0, 0x1A, 0x35), (1, 0x00, 0xFF)]
# a frame plus its signal free time is 59 units, 26.2 ms; sigrok's ir_rc6 needs 68 units
# (30.2 ms) from one frame's start to the next (test/ir_rc6.ml), before the host's delay
FRAME_MS = 34


def words(toggle, address, command):
    """Ir_rc6.words: the trailer bit, then the address and command in one word."""
    return [toggle, (address << 8) | command]


def lines(frames):
    """What sigrok's ir_rc6 decoder prints for the frames, in order, with the -A fields
    from the outside: line."""
    out = []
    for _, address, command in frames:
        out += ["ir_rc6-1: Address: %02X" % address, "ir_rc6-1: Data: %02X" % command]
    return out


def run(transfer, pause_ms, log=print):
    host = pe.Host(transfer)
    bench.load(host, bench_firmware.IR_RC6)
    host.start()
    host.push([UNIT])
    for toggle, address, command in FRAMES:
        # push both words at once; the second is taken after the leader
        host.push(words(toggle, address, command))
        pause_ms(FRAME_MS)
        log("sent toggle %d address 0x%02x command 0x%02x" % (toggle, address, command))
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
