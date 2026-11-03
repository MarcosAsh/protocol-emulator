# SPDX-License-Identifier: Apache-2.0
# The glitch map on the host Pico (MicroPython): engine 1 runs uart_rx on wire 20 and
# engine 0 each generator image in turn, a frame for each word pushed. A line a frame says
# what engine 1 pushed; demo/glitch_map.py holds the lines to the receiver's rows.

import time

import protocol_emulator as pe

FAULTS = pe.FAULTS


def program(host, words, dirty):
    """The selected engine's words from 0, halted, zeros after them up to dirty."""
    host.write(pe.PROGRAM_ADDR, [0])
    host.write(pe.PROGRAM, list(words) + [0] * (dirty - len(words)))
    return len(words)


def certify(host, check):
    """The selected engine's certificate, with every engine halted."""
    host.certify(
        check["certificate"], loaded=check["loaded"], floor=check["floor"],
        single_edge=check["single_edge"])


def run(transfer, receiver, receiver_config, receiver_check, images, frames=2):
    """images: (k, words, config, check) each, check what the host certifies the words
    with. A line a frame: RESULT k frame irq faults words."""
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
    # nothing is known of engine 0's memory yet
    dirty = pe.PROGRAM_WORDS
    for k, words, config, check in images:
        # both halted for the certificate's write
        host.select(1)
        host.stop()
        host.select(0)
        host.stop()
        host.flush()
        host.configure(config)
        dirty = program(host, words, dirty)
        certify(host, check)
        # the receiver from its start, which waits for the line to idle high
        host.select(1)
        host.flush()
        host.clear_irq()
        host.start()
        host.select(0)
        host.start()
        for frame in range(frames):
            host.select(0)
            host.push([0])
            # a frame and any frame a late pulse starts take 410 cycles
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
