# SPDX-License-Identifier: Apache-2.0
# NEC infrared from the library's transmitter (MicroPython, Pico A): OUT0 high for the on
# third of the 38 kHz carrier, an LED's drive, which analyser A's D4 and Pico B's GP1 see.
# A frame of the spec's example, address 0x59 command 0x16, then a repeat code.
# outside: analyser=A ms=2000 decode=-P ir_nec:ir=D4:polarity=active-high:cd_freq=38000 -A ir_nec=addr:cmd:repeat-code

import bench
import bench_firmware
import protocol_emulator as pe

# Ir_nec.standard_third: a third of 37.9 kHz at 48 MHz
THIRD = 422
# (address, command), as test/ir_nec.ml sends it
ADDRESS, COMMAND = 0x59, 0x16
# the firmware starts each message 110 ms or more after the one before (test/ir_nec.ml)
MESSAGE_MS = 120


def frame(address, command):
    """Ir_nec.words of a frame: 0, then the command high and the address low."""
    return [0, (command << 8) | address]


REPEAT_CODE = [1]


def lines():
    """What sigrok's ir_nec prints with outside:'s -A, in order."""
    return [
        "ir_nec-1: Address: 0x%02X" % ADDRESS,
        "ir_nec-1: Command: 0x%02X" % COMMAND,
        "ir_nec-1: Repeat code",
    ]


def run(transfer, pause_ms, log=print):
    host = pe.Host(transfer)
    bench.load(host, bench_firmware.IR_NEC)
    host.start()
    host.push([THIRD])
    host.push(frame(ADDRESS, COMMAND))
    pause_ms(MESSAGE_MS)
    log("sent address 0x%02x command 0x%02x" % (ADDRESS, COMMAND))
    host.push(REPEAT_CODE)
    pause_ms(MESSAGE_MS)
    log("sent a repeat code")
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
