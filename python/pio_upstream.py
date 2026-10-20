# SPDX-License-Identifier: Apache-2.0
# What the upstream PIO demos share (MicroPython and CPython): a pio_firmware.py entry's
# provenance and the kernel's verdict in the log, and its host words fed only as fast as
# the tx fifo makes room, since a push into a full fifo is dropped without a fault.

import bench
import pio_firmware
import protocol_emulator as pe


def tx_level(host):
    return (host.read(pe.STATUS)[0] >> 6) & 15


def header(firmware, log):
    log("upstream: raspberrypi/pico-examples %s %s, unchanged" % (
        pio_firmware.COMMIT[:7], firmware["file"]))
    log("sha256 %s" % firmware["sha256"])
    log("%s at k = %s, %d words:" % (firmware["program"], firmware["k"], len(firmware["words"])))
    words = firmware["words"]
    for i in range(0, len(words), 8):
        log("  " + " ".join("%04x" % w for w in words[i:i + 8]))
    log("kernel: certified, %d deadline waits, worst slack %s cycles" % (
        firmware["deadline_waits"], firmware["worst_slack"]))
    for term in firmware["contract"]:
        log("host: " + term)


def feed(host, words, polls=100_000):
    """words into the tx fifo, no more at a time than it has room for."""
    sent = 0
    for _ in range(polls):
        if sent == len(words):
            return
        room = bench.DEPTH - tx_level(host)
        if room:
            host.push(words[sent:sent + room])
            sent += min(room, len(words) - sent)
    raise RuntimeError("%d of %d words in" % (sent, len(words)))


def drain(host, polls=100_000):
    """Until the firmware has taken every word."""
    for _ in range(polls):
        if not tx_level(host):
            return
    raise RuntimeError("the tx fifo never emptied")
