# SPDX-License-Identifier: Apache-2.0
# The chip as a CAN node at 500 kbit/s on one SN65HVD230 (MicroPython, Pico A): OUT1 into
# its D, its R into IN1, the bus to Pico B running demo/can_node. Engine 0 sends four
# frames with the sender, which reads each ACK slot, the last asking Pico B for frames of
# its own; then engine 0 takes the receiver, which ACKs Pico B's four. OUT1 is dominant
# from reset until the sender has its period, which the run gives first.

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
# the replies end about 0.5 s in, and a failed act must still end inside the capture
LISTEN_MS = 1000
POLL_MS = 1
# Can_node.Receiver.Error_code's words
ERRORS = {1: "stuff error", 2: "refused: IDE or r0 recessive", 3: "CRC delimiter dominant",
          4: "CRC error"}


def arm(transfer, log=print):
    """Loads the sender and sends the period, after which the pin stays recessive."""
    host = pe.Host(transfer)
    bench.load(host, bench_firmware.CAN_SENDER)
    host.start()
    host.push([PERIOD])
    log("armed: OUT1 is recessive")


def frames(words):
    """Can_node.Receiver.read's whole frames from the front of words, as (id, rtr, dlc,
    data), and the words after them: the ID, RTR at bit 6 with the DLC, the data two bytes
    a word behind a zero byte if odd, then 0. A frame an error ended stays, its code where
    the 0 would be."""
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
    """Frames off the bus until REPLIES' number have come or LISTEN_MS. An error comes with
    irq, its code the last word: the frame it ended is dropped, irq cleared, and a word
    lets the receiver listen again."""
    words, heard = [], []
    for _ in range(LISTEN_MS // POLL_MS):
        irq = host.status()["irq"]
        level = pe.rx_level(host.read_status())
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
    if host.faults():
        log("engine 0 holds faults 0x%x: reset first" % host.faults())
        return False
    # the sender again, armed from reset or by an earlier run, as demo/capture.sh may run
    # this more than once: a stopped engine leaves OUT1 at the level it had
    bench.load(host, bench_firmware.CAN_SENDER)
    host.start()
    host.push([PERIOD])
    pause_ms(IDLE_MS)
    acked = []
    for ident, data in FRAMES:
        host.push(demo_can.words(ident, data))
        pause_ms(FRAME_MS)
        level = pe.rx_level(host.read_status())
        ack = host.pop(level) if level else []
        acked.append(ack == [0])
        log("sent %s, %s" % (describe(ident, 0, len(data), data),
                             "ACKed" if ack == [0] else "no ACK %s" % ack))
    faults = host.faults()
    # the sender stops with OUT1 recessive, and the receiver keeps it so
    bench.load(host, bench_firmware.CAN_RECEIVER)
    host.start()
    log("engine 0 is the receiver")
    heard = listen(host, pause_ms, log)
    faults |= host.faults()
    log("faults 0x%x" % faults)
    return all(acked) and heard == REPLIES and not faults


class Quiet(bench.Log):
    """Keeps the lines for demo/outside.sh without printing them: it starts this with
    mpremote's --no-follow, and a USB port nobody reads can stall a print, and the polls
    behind it, for longer than Pico B waits between frames."""

    def __call__(self, text=""):
        self.lines.append(text)


if __name__ == "__main__":
    import time

    import pico_board

    log = Quiet()
    spi = pico_board.PicoSpi()
    time.sleep_ms(bench.START_MS)
    bench.report(lambda: run(spi.transfer, time.sleep_ms, log), log)
