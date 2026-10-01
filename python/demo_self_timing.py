# SPDX-License-Identifier: Apache-2.0
# Act 2 on the host Pico (MicroPython): engine 0 sends UART frames over wire 20, engine 1
# stamps every edge and echoes the wire on OUT0 for the listener Pico and the analyser.
# An engine's set and out pins are one run from their base, so it cannot drive OUT0 and
# the wire together: hence the echo. Needs protocol_emulator.py, pico_board.py and the
# two .hex files on the Pico.

import protocol_emulator as pe

WIRE = 20
# 9600 baud at 48 MHz; `assemble -period 5000 test/uart_tx_host_rate.asm` accepts it, so
# every edge lands a whole number of periods after its start bit
PERIOD = 5000
TRANSMITTER = dict(pe.DEFAULT_CONFIG, set_base=WIRE, out_base=WIRE)
# sets OUT0, the default set pin
LOGGER = dict(pe.DEFAULT_CONFIG, jmp_pin=WIRE, autopush=1)
FAULTS = 0x3C
FLOOD = (pe.NOW_LO, pe.PC)


def words(name):
    with open(name + ".hex") as f:
        return pe.hex_words(f.read())


def edges(byte):
    """The bits of a frame, start bit first, at which the line changes."""
    levels = [0] + [(byte >> i) & 1 for i in range(8)] + [1]
    return [bit for bit in range(10) if levels[bit] != (levels[bit - 1] if bit else 1)]


def load(host, engine, config, program):
    host.select(engine)
    host.stop()
    host.flush()
    host.configure(config)
    host.load(program)


def rx_level(host):
    return (host.read(pe.STATUS)[0] >> 10) & 15


def setup(host, transmitter, logger, period=PERIOD):
    """Both engines running, the wire idle and no stamp waiting."""
    load(host, 1, LOGGER, logger)
    host.start()
    load(host, 0, TRANSMITTER, transmitter)
    host.push([period])
    host.start()
    host.select(1)
    # the line going idle, unless a previous run left it there
    for _ in range(4):
        level = rx_level(host)
        if level:
            host.pop(level)


def host_drain(host):
    """The poll as Host makes it, for the cocotb rehearsal: append the selected engine's
    waiting stamps, then read each register in reads."""

    def drain(stamps, reads):
        level = rx_level(host)
        if level:
            stamps.extend(host.pop(level))
        for reg in reads:
            host.read(reg)

    return drain


def send(host, drain, data, flood=False, pause=None, polls=100_000):
    """The stamps of every edge. Flooding, the host reads two more registers each poll."""
    expected = sum(len(edges(b)) for b in data)
    host.select(0)
    host.push(list(data))
    host.select(1)
    stamps = []
    for _ in range(polls):
        drain(stamps, FLOOD if flood else ())
        if len(stamps) >= expected:
            return stamps
        if pause and not flood:
            pause()
    raise RuntimeError("%d of %d edges stamped" % (len(stamps), expected))


def offsets(data, stamps):
    """Per byte, each edge's time after its start bit."""
    frames = []
    for byte in data:
        n = len(edges(byte))
        frame, stamps = stamps[:n], stamps[n:]
        frames.append([(s - frame[0]) & 0xFFFF for s in frame])
    return frames


def faults(host):
    """Each engine's fault bits: underflow, overflow, missed deadline, bad decode."""
    found = []
    for engine in (0, 1):
        host.select(engine)
        found.append(host.read(pe.STATUS)[0] & FAULTS)
    host.select(1)
    return found


def table(data, measured, period=PERIOD):
    print("byte       predicted, cycles after the start bit")
    print("           measured")
    exact = True
    for byte, got in zip(data, measured):
        predicted = [bit * period for bit in edges(byte)]
        exact = exact and got == predicted
        c = chr(byte) if 32 <= byte < 127 else "."
        print("%r 0x%02x   %s" % (c, byte, " ".join("%5d" % t for t in predicted)))
        print("           %s  %s" % (" ".join("%5d" % t for t in got), "ok" if got == predicted else "DIFFERS"))
    return exact


class Counted:
    """The SPI frames sent, through Host or a transport's own drain."""

    def __init__(self, transfer, drain=None):
        self.inner = transfer
        self.inner_drain = drain
        self.frames = 0

    def transfer(self, data):
        self.frames += 1
        return self.inner(data)

    def drain(self, stamps, reads):
        self.frames += self.inner_drain(stamps, reads)


def run(transfer, text=b"Jane St!", pause=None, drain=None):
    """Quiet, then with the host flooding SPI: both tables, and whether they agree. A
    transport's own drain, like host_drain's but returning the frames it sent, stands in
    for Host's where the host is too slow to poll through it."""
    data = bytes(text)
    assert len(data) <= 8, "the tx fifo holds eight"
    spi = Counted(transfer, drain)
    host = pe.Host(spi.transfer)
    poll = host_drain(host) if drain is None else spi.drain
    setup(host, words("uart_tx_host_rate"), words("edge_logger_echo"))
    spi.frames = 0
    quiet = offsets(data, send(host, poll, data, pause=pause))
    print("\nquiet, %d SPI frames:" % spi.frames)
    ok = table(data, quiet)
    spi.frames = 0
    flooded = offsets(data, send(host, poll, data, flood=True))
    print("\nflooded, %d SPI frames:" % spi.frames)
    ok = table(data, flooded) and ok
    found = faults(host)
    print("\nfaults %s, flooded %s quiet" % (found, "==" if flooded == quiet else "!="))
    return ok and flooded == quiet and not any(found)


if __name__ == "__main__":
    import time

    import pico_board

    spi = pico_board.PicoSpi()
    ok = run(spi.transfer, pause=lambda: time.sleep_us(300), drain=spi.drain)
    print("PASS" if ok else "FAIL")
