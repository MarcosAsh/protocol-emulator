# SPDX-License-Identifier: Apache-2.0
# The chip speaks what it learned (MicroPython, Pico A): send.json's firmware, written by
# generate.exe learn and accepted by the kernel, into engine 0, the period it was checked
# under, then each frame's words, PAUSE_MS apart so a receiver sees separate presses.

import json
import time

import bench
import pico_board
import protocol_emulator as pe

PAUSE_MS = 150
# sigrok-cli takes up to 3 s to start sampling once demo/capture.sh starts it
START_MS = 3000


def run(transfer, log):
    send = json.load(open("send.json"))
    host = pe.Host(transfer)
    bench.load(host, {"config": send["config"], "words": send["words"]})
    host.start()
    host.push([send["period"]])
    for frame in send["frames"]:
        words = list(frame["words"])
        # as the fifo has room; the firmware pulls a word no sooner than a unit apart
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
    time.sleep_ms(START_MS)
    bench.report(lambda: run(spi.transfer, log), log)
