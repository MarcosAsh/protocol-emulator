# SPDX-License-Identifier: Apache-2.0
# Pico B's SWD port on the library's SWD host (MicroPython, Pico A): OUT2 (header 12) to
# SWCLK, pin 1 of Pico B's debug connector, IO5 (header 36) to SWDIO, pin 3, GND to pin 2,
# each line through 220 R, and 4.7 k from SWDIO to Pico B's 3V3. Reads core 0's DPIDR and
# AP IDR and core 1's DPIDR, checks an absent instance stays silent, then lets the lines
# go. demo/outside.sh swd runs it; test/test_swd.py rehearses it on the RTL.

import bench
import bench_firmware
import protocol_emulator as pe

# Swd.firmware's half period: 24 cycles at 48 MHz, a 1 MHz SWCLK
HALF = 24
OK, WAIT, FAULT = 1, 2, 4
# RP2040 datasheet 2.3.4: core 0, core 1, and an instance ID nobody on the bus has
CORE0 = 0x01002927
CORE1 = 0x11002927
NOBODY = 0x21002927
# what OpenOCD reads from an RP2040: Arm's designer code, DPv2, MINDP
DPIDR = 0x0BC12477
# ADIv5.2 B5.3.4: the selection alert LSB first, then four low and the SW-DP activation
# code 0b0101_1000 MSB first, the last four bits high into the line reset
ALERT = [0xF392, 0x6209, 0x2D95, 0x8685, 0xAFE9, 0xE3DD, 0x0EA2, 0x19BC]
ACTIVATION = 0xF1A0
LINE_RESET = [0xFFFF] * 4 + [0x0000]
# bit 15 of a word with bit 0 clear: SWCLK low and SWDIO let go until the next command
RELEASE = [0x8000]
# DP registers (B2.2), and ABORT's sticky flag clears less STKCMPCLR, which a MINDP DP
# takes as SBZ
ABORT, CTRL_STAT, SELECT, RDBUFF = 0x0, 0x4, 0x8, 0xC
CLEAR_STICKY = 0x1C
POWER_UP = 0x50000000
POWERED = 0xA0000000
POLLS = 20
# the polls of one transfer's words in and replies out, each an SPI frame
STEPS = 10_000


def sequence(words):
    """Driven bits, sixteen a word LSB first, behind the count less one."""
    return [(len(words) - 1) << 1] + words


def request(ap, read, address):
    """Start, APnDP, RnW, A[2:3], even parity, stop 0, park 1, from bit 0."""
    fields = ap | (read << 1) | (address & 0xC)
    parity = bin(fields).count("1") & 1
    return 1 | (fields << 1) | (parity << 5) | 0x80


class Swd:
    def __init__(self, host):
        self.host = host

    def send(self, words, replies):
        """The words into the tx fifo as it has room, and the replies they make. One
        transfer at a time, so at most three replies are ever waiting."""
        sent, got = 0, []
        for _ in range(STEPS):
            status = self.host.read(pe.STATUS)[0]
            tx, rx = (status >> 6) & 15, (status >> 10) & 15
            if rx:
                got.extend(self.host.pop(rx))
            if sent < len(words) and tx < bench.DEPTH:
                chunk = words[sent:sent + bench.DEPTH - tx]
                self.host.push(chunk)
                sent += len(chunk)
            if sent == len(words) and len(got) == replies:
                return got
        raise RuntimeError("%d of %d words sent, %d of %d replies" % (
            sent, len(words), len(got), replies))

    def bits(self, words):
        self.send(sequence(words), 0)

    def wake(self):
        self.bits([0xFFFF] + ALERT + [ACTIVATION])

    def line_reset(self):
        self.bits(LINE_RESET)

    def targetsel(self, target):
        """The ACK lines as nobody drove them, since no DP answers TARGETSEL."""
        word = request(0, 0, 0xC) | 0x100
        return self.send([word, target & 0xFFFF, target >> 16], 1)[0] & 7

    def read(self, ap, address):
        """ACK, data and whether its parity held."""
        low, high, status = self.send([request(ap, 1, address)], 3)
        return status & 7, low | (high << 16), not status & 8

    def write(self, ap, address, value):
        return self.send([request(ap, 0, address), value & 0xFFFF, value >> 16], 1)[0] & 7

    def read_until(self, ap, address, done=lambda v: True):
        """Retried on WAIT, and until done(value), as many as POLLS times."""
        for _ in range(POLLS):
            ack, value, good = self.read(ap, address)
            if ack == OK and good and done(value):
                break
        return ack, value, good


def ack_name(ack):
    return {OK: "OK", WAIT: "WAIT", FAULT: "FAULT"}.get(ack, "none (%s)" % bin(ack))


def select(swd, target, log):
    """Line reset, TARGETSEL, then the DPIDR read B4.3.4 asks for: whether it is the
    RP2040's DPIDR, with good parity."""
    swd.line_reset()
    swd.targetsel(target)
    ack, value, good = swd.read(0, 0x0)
    log("TARGETSEL 0x%08x, DPIDR: ACK %s, 0x%08x, parity %s" % (
        target, ack_name(ack), value, "good" if good else "BAD"))
    return ack, value, good


def run(transfer, log=print, half=HALF):
    """The act, leaving SWCLK low and SWDIO let go however it ends."""
    host = pe.Host(transfer)
    bench.load(host, bench_firmware.SWD)
    host.start()
    swd = Swd(host)
    # the core answers the half period with SWDIO's level before it drives either line
    if swd.send([half], 1)[0] != 1:
        log("SWDIO is low with nobody driving it: power Pico B and fit the 4.7 k from SWDIO "
            "to Pico B's 3V3 (pin 36)")
        host.stop()
        return False
    try:
        return act(swd, host, log)
    finally:
        swd.send(RELEASE, 0)


def act(swd, host, log):
    swd.wake()
    ack, dpidr, good = select(swd, CORE0, log)
    core0 = ack == OK and dpidr == DPIDR and good
    if ack != OK:
        log("core 0 does not answer: check SWCLK on pin 1 and SWDIO on pin 3 of Pico B's "
            "debug connector, and that Pico B is powered")
        return False

    clear = swd.write(0, ABORT, CLEAR_STICKY)
    power = swd.write(0, CTRL_STAT, POWER_UP)
    ack, ctrl, _ = swd.read_until(0, CTRL_STAT, lambda v: v & POWERED == POWERED)
    powered = clear == power == ack == OK and ctrl & POWERED == POWERED
    log("ABORT ACK %s, CTRL/STAT 0x%08x written ACK %s, reads 0x%08x: powered up %s" % (
        ack_name(clear), POWER_UP, ack_name(power), ctrl, "yes" if powered else "NO"))

    # AP 0's IDR, bank 0xf, address 0xc: posted, so RDBUFF has it (B4.2.2)
    swd.write(0, SELECT, 0xF0)
    first, _, _ = swd.read_until(1, 0xC)
    ack, idr, good = swd.read_until(0, RDBUFF)
    designer, kind = (idr >> 17) & 0x7FF, (idr >> 13) & 0xF
    # C1.3.2: Arm is JEP106 0x7f four times then 0x3b, so 4 << 7 | 0x3b; class 8, a MEM-AP
    ap = first == ack == OK and good and designer == 0x23B and kind == 8
    log("AP 0 IDR 0x%08x: designer 0x%03x, class %d, %s" % (
        idr, designer, kind, "an Arm MEM-AP" if ap else "NOT an Arm MEM-AP"))
    swd.write(0, SELECT, 0)
    swd.write(0, CTRL_STAT, 0)

    ack, value, good = select(swd, CORE1, log)
    core1 = ack == OK and value == DPIDR and good
    ack, _, _ = select(swd, NOBODY, log)
    # the ACK lines read 111 or 000 as the pull-up or the pad's pull-down wins
    silent = ack != OK
    log("nobody answers instance 2: %s" % ("yes" if silent else "NO"))
    ack, value, good = select(swd, CORE0, log)
    again = ack == OK and value == DPIDR and good

    found = bench.faults(host)
    log("faults 0x%x" % found)
    return core0 and powered and ap and core1 and silent and again and not found


if __name__ == "__main__":
    import time

    import pico_board

    log = bench.Log()
    spi = pico_board.PicoSpi()
    time.sleep_ms(bench.START_MS)
    bench.report(lambda: run(spi.transfer, log), log)
