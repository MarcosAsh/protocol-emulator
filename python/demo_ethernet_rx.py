# SPDX-License-Identifier: Apache-2.0
# 10BASE-T into the chip (MicroPython, Pico A). A PIO on GP6 sends frames at 10 Mb/s, off
# Pico A's own crystal, into IO0 (header 29) and the chip's receiver, which samples for a
# 40 MHz clock. Engine 0's ethernet_rx hands each frame to the host, which checks the bytes
# and the receiver's FCS verdict against what it sent: good and bad FCSs, odd and even
# lengths, one frame past the end of the data memory, then the rate stepped both ways until
# frames fail. Needs the Icepi's 40 MHz header build, the host SPI at 5 MHz, and bench.py,
# ethernet.py, ethernet_rx.hex and ethernet_rx.cert.hex on the Pico.

import array
import gc
import random
import time

import machine
import rp2
from machine import Pin

import bench
import ethernet
import protocol_emulator as pe

SPI_HZ = 5_000_000
IO0 = 12
LINE = 6
BASE = 16
# the number of bytes that fit in the data memory from BASE
ROOM = 2 * (512 - BASE)
SEED = 802
# The PIO divides the 200 MHz system clock by 2 + step/256 and uses five PIO cycles per
# half bit, so one step changes the rate by 0.195% and each edge moves by up to one 5 ns
# system cycle relative to step 0. Below are the steps a pass needs, then the sweep.
CLAIMED = (-1, 0, 1)
SWEEP = range(-16, 17)
PIO0_SM0_CLKDIV = 0x502000C8


@rp2.asm_pio(out_init=rp2.PIO.OUT_LOW, out_shiftdir=rp2.PIO.SHIFT_RIGHT, autopull=True,
             pull_thresh=32, fifo_join=rp2.PIO.JOIN_TX)
def halves():
    out(pins, 1)[4]  # noqa: F821


# each byte as sixteen half bits, first one lowest: a bit's complement, then the bit
CODES = [sum((1 - ((b >> n) & 1)) << (2 * n) | ((b >> n) & 1) << (2 * n + 1) for n in range(8))
         for b in range(256)]


def line_words(data, idle=6):
    """The PIO's words for data after the preamble, as ethernet.halves has it: one half bit
    per bit of each word, first one lowest, then TP_IDL and the line at rest."""
    sent = ethernet.PREAMBLE + list(data)
    words = array.array("I", bytes(4 * (len(sent) // 2 + 2)))
    for n, byte in enumerate(sent):
        words[n >> 1] |= CODES[byte] << (16 * (n & 1))
    at = 16 * len(sent)
    for k in range(idle):
        words[(at + k) >> 5] |= 1 << ((at + k) & 31)
    return words


class Sender:
    def __init__(self):
        self.sm = None
        self.step = None

    def rate(self, step):
        if step != self.step:
            if self.sm:
                self.sm.active(0)
            self.sm = rp2.StateMachine(0, halves, freq=200_000_000 * 256 // (512 + step),
                                       out_base=Pin(LINE))
            self.step = step
        return machine.mem32[PIO0_SM0_CLKDIV] >> 8

    def send(self, words):
        """Send the words, with the first eight in the fifo before the machine starts and
        interrupts off so the line has no gap. The last level, at rest, stays."""
        first, rest = words[:8], words[8:]
        self.sm.restart()
        state = machine.disable_irq()
        self.sm.put(first)
        self.sm.active(1)
        self.sm.put(rest)
        machine.enable_irq(state)
        while self.sm.tx_fifo():
            pass
        time.sleep_us(10)
        self.sm.active(0)


def setup(host):
    for engine in (1, 0):
        host.select(engine)
        found = bench.faults(host)
        if found:
            raise RuntimeError("engine %d holds faults 0x%x: reset the chip" % (engine, found))
        host.stop()
        host.flush()
    ethernet.load_receiver(host, 0)


def receive(host, sender, data):
    """Return the receiver's status and the bytes engine 0 hands over (at most what fits)."""
    host.stop()
    host.flush()
    host.arm_frame(IO0, base=BASE, fifty=False, owner=0)
    host.push([BASE])
    host.start()
    gc.collect()
    sender.send(line_words(data))
    status = host.frame_status()
    for _ in range(100):
        if status["finished"]:
            break
        time.sleep_ms(1)
        status = host.frame_status()
    words = []
    wanted = min(status["words"], ROOM // 2) if status["finished"] else 0
    while len(words) < wanted:
        level = bench.rx_level(host)
        if level:
            words += host.pop(min(level, wanted - len(words)))
    host.stop()
    return status, ethernet.received(words, min(len(data), 2 * len(words)))


def frame(length, bad):
    body = [random.getrandbits(8) for _ in range(length - 4)]
    fcs = ethernet.crc32(body)
    data = body + [(fcs >> (8 * k)) & 0xFF for k in range(4)]
    if bad:
        bit = random.getrandbits(16) % (8 * length)
        data[bit >> 3] ^= 1 << (bit & 7)
    return data


def judge(status, got, data, bad, log, label):
    """Return one frame's lines (whether it was received whole, then what was sent and
    what came back) in the format demo/frames.py reads."""
    fits = len(data) <= ROOM
    ok = (status["finished"] and status["fcs_ok"] == (not bad)
          and status["words"] == (len(data) + 1) // 2 and status["half"] == len(data) % 2
          and status["dropped"] == (not fits) and got == data[:min(len(data), ROOM)])
    log("%s len %d fcs %s: words %d finished %d fcs_ok %d half %d dropped %d, %s" % (
        label, len(data), "bad" if bad else "good", status["words"], status["finished"],
        status["fcs_ok"], status["half"], status["dropped"], "PASS" if ok else "FAIL"))
    log("  sent %s" % bench.hexs(data))
    log("  got  %s" % bench.hexs(got))
    return ok


def run(transfer, log=print):
    random.seed(SEED)
    host = pe.Host(transfer)
    setup(host)
    sender = Sender()
    passed = True
    n = 0
    plan = [(64, False)] * 3 + [(65, False), (128, False), (255, False), (512, False),
                                (ROOM - 1, False), (ROOM, False), (64, True), (65, True),
                                (300, True), (ROOM, True), (ROOM + 208, False)]
    divider = sender.rate(0)
    log("seed %d, step 0, divider %d/256" % (SEED, divider))
    for length, bad in plan:
        data = frame(length, bad)
        status, got = receive(host, sender, data)
        passed = judge(status, got, data, bad, log, "frame %d step 0" % n) and passed
        n += 1
    edges = {}
    for step in SWEEP:
        divider = sender.rate(step)
        ok = True
        for k in range(4):
            data = frame(64 + 300 * k, False)
            status, got = receive(host, sender, data)
            ok = judge(status, got, data, False, log,
                       "frame %d step %d divider %d/256" % (n, step, divider)) and ok
            n += 1
        edges[step] = ok
        if step in CLAIMED:
            passed = passed and ok
    held = [s for s in SWEEP if edges[s]]
    log("rate steps received whole: %s" % " ".join("%+d" % s for s in held))
    found = bench.faults(host)
    log("faults 0x%x" % found)
    return passed and not found


if __name__ == "__main__":
    import pico_board

    # the frames' hex lines would fill the Pico's heap if kept, so we only print them (for
    # the ledger's copy of Pico A's output)
    spi = pico_board.PicoSpi(baudrate=SPI_HZ)
    try:
        ok = run(spi.transfer)
    except Exception as e:
        print("stopped: %s" % e)
        ok = False
    print("PASS" if ok else "FAIL")
