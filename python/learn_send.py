# SPDX-License-Identifier: Apache-2.0
# The chip speaks what it learned (MicroPython, Pico A). Loads send.json's firmware
# (written by generate.exe learn and accepted by the kernel) into engine 0 with its
# certificate and the period it was checked under (done in start, before the analyser runs),
# then sends each frame's words PAUSE_MS apart so a receiver sees separate presses.

import json
import time

import bench
import pico_board
import protocol_emulator as pe

PAUSE_MS = 150
# sigrok-cli can take up to 3 s to start sampling after demo/capture.sh starts it
START_MS = 3000


def start(transfer):
    """Load and start the firmware, which sets the idle levels. Run this before the
    analyser starts so a clock's first move to idle isn't read as a bit."""
    send = json.load(open("send.json"))
    host = pe.Host(transfer)
    bench.load(host, send)
    host.start()
    host.push([send["period"]])


def run(transfer, log):
    """Send the frames to the firmware that start left running."""
    send = json.load(open("send.json"))
    host = pe.Host(transfer)
    time.sleep_ms(START_MS)
    for frame in send["frames"]:
        words = list(frame["words"])
        # push as the fifo has room; the firmware pulls words at least a unit apart
        while words:
            room = bench.DEPTH - host.status()["tx_level"]
            if room:
                host.push(words[:room])
                words = words[room:]
        log("sent kind %d bits %s" % (frame["kind"], frame["bits"]))
        time.sleep_ms(PAUSE_MS)
    found = bench.faults(host)
    log("firmware %d words, worst slack %s cycles, faults 0x%x" % (
        len(send["words"]), send["slack"], found))
    return not found


if __name__ == "__main__":
    log = bench.Log()
    spi = pico_board.PicoSpi()
    bench.report(lambda: run(spi.transfer, log), log)
