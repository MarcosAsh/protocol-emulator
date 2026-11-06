# SPDX-License-Identifier: Apache-2.0
# NEC infrared from the library's transmitter (MicroPython, Pico A): OUT0 low for a mark, as
# an IR receiver module's output, which analyser A's D4 and Pico B's GP1 see. A key held for
# two repeat codes, then two keys tapped, a frame or repeat code every 108 ms.
# outside: analyser=A ms=4000 decode=-P ir_nec:ir=D4 -A ir_nec=addr:addr-inv:cmd:cmd-inv:repeat-code

import bench
import bench_firmware
import protocol_emulator as pe

# Nec.standard_unit: 562.5 us at 48 MHz
UNIT = 27000
# (address, command, repeat codes after the frame), as test/test_nec.ml sends them
KEYS = [(0x04, 0x08, 2), (0x00, 0x45, 0), (0xFF, 0x00, 0)]
PERIOD_MS = 108


def words(address, command, repeats):
    """Nec.words: the repeat codes, then the address and the command, each with its inverse
    in the high byte."""
    return [repeats] + [b | ((~b & 0xFF) << 8) for b in (address, command)]


def lines(keys):
    """What sigrok's ir_nec prints of the keys with outside:'s -A, in order."""
    out = []
    for address, command, repeats in keys:
        for name, byte in (("Address", address), ("Address#", ~address & 0xFF),
                           ("Command", command), ("Command#", ~command & 0xFF)):
            out.append("ir_nec-1: %s: 0x%02X" % (name, byte))
        out += ["ir_nec-1: Repeat code"] * repeats
    return out


def run(transfer, pause_ms, log=print):
    host = pe.Host(transfer)
    bench.load(host, bench_firmware.NEC_TX)
    host.start()
    host.push([UNIT])
    for address, command, repeats in KEYS:
        # all three at once: the address word is taken 9 ms into the frame
        host.push(words(address, command, repeats))
        pause_ms(PERIOD_MS * (repeats + 1))
        log("sent address 0x%02x command 0x%02x, %d repeat codes" % (address, command, repeats))
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
