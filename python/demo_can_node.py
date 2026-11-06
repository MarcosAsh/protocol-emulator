# SPDX-License-Identifier: Apache-2.0
# The chip as a CAN node at 500 kbit/s on one SN65HVD230 (MicroPython, Pico A): OUT1 to
# its D, its R to IN1, the bus to Pico B running demo/can_node. Engine 0 first runs the
# sender, which sends four frames and reads each ACK slot; the last frame asks Pico B for
# frames of its own. Then engine 0 switches to the receiver, which ACKs Pico B's four.
# OUT1 is dominant from reset until the sender gets its period, so the run sends that first.

import bench
import bench_firmware
import demo_can
import protocol_emulator as pe

PERIOD = demo_can.PERIOD
IDLE_MS = demo_can.IDLE_MS
FRAME_MS = demo_can.FRAME_MS
# Pico B answers this ID with REPLIES, after demo/can_node.c's REPLY_DELAY_MS
REQUEST = 0x7E0
FRAMES = demo_can.FRAMES[:3] + [(REQUEST, [])]
# (id, rtr, dlc, data), as demo/can_node.c sends them
REPLIES = [
    (0x0A1, 0, 3, [0x01, 0x02, 0x03]),
    (0x0A2, 1, 2, []),
    (0x6B1, 0, 8, [0xFF] * 8),
    (0x000, 0, 2, [0x00, 0x00]),
]
# the replies finish about 0.5 s in, and even a failed run must end within the capture
LISTEN_MS = 1000
POLL_MS = 1
# Can_node.Receiver.Error_code's words
ERRORS = {1: "stuff error", 2: "refused: IDE or r0 recessive", 3: "CRC delimiter dominant",
          4: "CRC error"}


def arm(transfer, log=print):
    """Load the sender and send it the period; after that the pin stays recessive."""
    host = pe.Host(transfer)
    bench.load(host, bench_firmware.CAN_SENDER)
    host.start()
    host.push([PERIOD])
    log("armed: OUT1 is recessive")


def frames(words):
    """Parse Can_node.Receiver.read's whole frames from the front of words. Returns the
    frames as (id, rtr, dlc, data) plus the leftover words. A frame is the ID, RTR (bit 6)
    with the DLC, the data two bytes per word (zero-padded if odd), then 0. A frame ended
    by an error stays in, with its error code where the 0 would be."""
    found = []
    while len(words) >= 2:
        ident, control = words[0], words[1]
        rtr, dlc = (control >> 6) & 1, control & 15
        count = 0 if rtr else min(dlc, 8)
        end = 2 + (count + 1) // 2
        if len(words) <= end or words[end] != 0:
            break
        data = []
        for word in words[2:end]:
            data += [word >> 8, word & 0xFF]
        found.append((ident, rtr, dlc, data[len(data) - count:]))
        words = words[end + 1:]
    return found, words


def describe(ident, rtr, dlc, data):
    return " ".join(["id 0x%03x %s dlc %d" % (ident, "remote" if rtr else "data", dlc)]
                    + ["%02x" % b for b in data])


def listen(host, pause_ms, log):
    """Collect frames off the bus until REPLIES of them arrive or LISTEN_MS passes. An
    error raises irq and its code is the last word. We drop the frame it ended, clear
    irq and push a word so the receiver listens again."""
    words, heard = [], []
    for _ in range(LISTEN_MS // POLL_MS):
        irq = host.status()["irq"]
        level = bench.rx_level(host)
        if level:
            words += host.pop(level)
        if irq and words:
            log("receiver: %s, dropped %s" % (ERRORS.get(words[-1], words[-1]), words[:-1]))
            words = []
            host.clear_irq()
            host.push([0])
        found, words = frames(words)
        for frame in found:
            log("received " + describe(*frame))
            heard.append(frame)
        if len(heard) >= len(REPLIES):
            break
        pause_ms(POLL_MS)
    return heard


def run(transfer, pause_ms, log=print):
    host = pe.Host(transfer)
    host.select(0)
    if bench.faults(host):
        log("engine 0 holds faults 0x%x: reset first" % bench.faults(host))
        return False
    # load the sender again: it may be armed from reset or an earlier run (demo/capture.sh
    # can run this more than once), and a stopped engine leaves OUT1 at the level it had
    bench.load(host, bench_firmware.CAN_SENDER)
    host.start()
    host.push([PERIOD])
    pause_ms(IDLE_MS)
    acked = []
    for ident, data in FRAMES:
        host.push(demo_can.words(ident, data))
        pause_ms(FRAME_MS)
        ack = host.pop(bench.rx_level(host)) if bench.rx_level(host) else []
        acked.append(ack == [0])
        log("sent %s, %s" % (describe(ident, 0, len(data), data),
                             "ACKed" if ack == [0] else "no ACK %s" % ack))
    faults = bench.faults(host)
    # the sender stops with OUT1 recessive and the receiver keeps it that way
    bench.load(host, bench_firmware.CAN_RECEIVER)
    host.start()
    log("engine 0 is the receiver")
    heard = listen(host, pause_ms, log)
    faults |= bench.faults(host)
    log("faults 0x%x" % faults)
    return all(acked) and heard == REPLIES and not faults


class Quiet(bench.Log):
    """Keep the lines for demo/outside.sh without printing them. It starts this with
    mpremote's --no-follow, and a print to a USB port nobody reads can stall the polls for
    longer than Pico B waits between frames."""

    def __call__(self, text=""):
        self.lines.append(text)


if __name__ == "__main__":
    import time

    import pico_board

    log = Quiet()
    spi = pico_board.PicoSpi()
    time.sleep_ms(bench.START_MS)
    bench.report(lambda: run(spi.transfer, time.sleep_ms, log), log)
