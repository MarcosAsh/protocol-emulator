# SPDX-License-Identifier: Apache-2.0
# The glitch map on the host Pico (MicroPython). Engine 1 runs uart_rx on wire 20 and
# engine 0 runs each generator image in turn, sending a frame per word pushed. Prints one
# line per frame saying what engine 1 pushed; demo/glitch_map.py checks the lines against
# the receiver's rows.

import time

import protocol_emulator as pe

FAULTS = pe.FAULTS


def program(host, words, dirty):
    """Load the selected engine's words from 0, halted, and zero the memory after them up
    to dirty."""
    host.write(pe.PROGRAM_ADDR, [0])
    host.write(pe.PROGRAM, list(words) + [0] * (dirty - len(words)))
    return len(words)


def certify(host, check):
    """Write the selected engine's certificate, with every engine halted."""
    host.certify(
        check["certificate"], loaded=check["loaded"], floor=check["floor"],
        single_edge=check["single_edge"])


def run(transfer, receiver, receiver_config, receiver_check, images, frames=2):
    """images holds (k, words, config, check) tuples, where check is what the host certifies
    the words with. Prints one line per frame: RESULT k frame irq faults words."""
    host = pe.Host(transfer)
    for engine in (0, 1):
        host.select(engine)
        if host.read(pe.STATUS)[0] & FAULTS:
            print("HELD")
            return
    host.select(0)
    host.stop()
    host.select(1)
    host.stop()
    host.flush()
    host.configure(receiver_config)
    host.load(receiver)
    certify(host, receiver_check)
    # we don't know what engine 0's memory holds yet
    dirty = pe.PROGRAM_WORDS
    for k, words, config, check in images:
        # both must be halted for the certificate's write
        host.select(1)
        host.stop()
        host.select(0)
        host.stop()
        host.flush()
        host.configure(config)
        dirty = program(host, words, dirty)
        certify(host, check)
        # start the receiver from the top; it waits for the line to idle high
        host.select(1)
        host.flush()
        host.clear_irq()
        host.start()
        host.select(0)
        host.start()
        for frame in range(frames):
            host.select(0)
            host.push([0])
            # a frame, plus any frame a late pulse starts, takes 410 cycles
            time.sleep_us(200)
            host.select(1)
            status = host.read(pe.STATUS)[0]
            level = (status >> 10) & 15
            got = host.pop(level) if level else []
            host.clear_irq()
            print("RESULT %d %d %d %x %s" % (
                k, frame, (status >> 1) & 1, status & FAULTS,
                " ".join("%x" % w for w in got)))
            if status & FAULTS:
                return
    host.select(0)
    host.stop()
    host.select(1)
    host.stop()
    print("DONE")
