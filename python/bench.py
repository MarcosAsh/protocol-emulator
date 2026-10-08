# SPDX-License-Identifier: Apache-2.0
# What the outside chip acts share (MicroPython and CPython): loading a bench_firmware.py
# entry into an engine, a stream of host words that never overflows either fifo, and the
# log demo/outside.sh reads back from Pico A once the capture is done.

import protocol_emulator as pe

# the chip's clock on the bench, from the Icepi's PLL
MHZ = 48
DEPTH = 8
# demo/capture.sh starts the analyser after mpremote returns, which takes this long
START_MS = 1000


def load(host, firmware, engine=0):
    """Both engines stopped and flushed, then engine loaded with a bench_firmware.py entry,
    its certificate checked, and left selected. Faults hold until reset, so one left from an
    earlier run is refused rather than reported as this one's."""
    for other in (1, 0):
        host.select(other)
        found = host.faults()
        if found:
            raise RuntimeError(
                "engine %d holds faults 0x%x from an earlier run: reset the chip" % (other, found))
        host.stop()
        host.flush()
    host.select(engine)
    host.configure(firmware["config"])
    host.load(firmware["words"])
    host.certify(
        firmware["certificate"], loaded=firmware["loaded"], single_edge=firmware["single_edge"])


def exchange(host, words, polls=100_000):
    """The reply to each word, for firmware that answers every host word with one. No more
    than a fifo's depth is ever waiting, so neither fifo can overflow."""
    replies = []
    sent = 0
    for _ in range(polls):
        room = DEPTH - (sent - len(replies))
        if sent < len(words) and room:
            chunk = words[sent:sent + room]
            host.push(chunk)
            sent += len(chunk)
        level = pe.rx_level(host.read_status())
        if level:
            replies.extend(host.pop(level))
        if len(replies) == len(words):
            return replies
    raise RuntimeError("%d of %d replies" % (len(replies), len(words)))


def hexs(data):
    return " ".join("%02x" % b for b in data)


class Log:
    """Prints each line and keeps it, for demo/outside.sh to read back as outside.log."""

    def __init__(self):
        self.lines = []

    def __call__(self, text=""):
        print(text)
        self.lines.append(text)

    def save(self, path="outside.log"):
        with open(path, "w") as f:
            f.write("\n".join(self.lines) + "\n")


def report(act, log):
    """Runs act, then logs PASS, FAIL or what stopped it, and saves the log."""
    try:
        ok = act()
    except Exception as e:
        log("stopped: %s" % e)
        ok = False
    log("PASS" if ok else "FAIL")
    log.save()
