# SPDX-License-Identifier: Apache-2.0
# The chip records a transmitter it was never told about (MicroPython, Pico A): each engine
# runs the edge logger on its line and stamps every edge with its own 16-bit clock, and this
# drains the stamps and reads the clock after each drain, which extends every stamp to whole
# cycles as long as no two reads are 65536 cycles apart (1.4 ms at 48 MHz). A poll later
# than that marks the recording broken rather than guess. With two lines, engine 1 starts
# first and stamps the wire engine 0 raises as it starts, which puts both on one clock.
# record.json (demo/learn_prepare.py) has the loggers; record.edges and record.log are kept.

import json
import time

import micropython

import pico_board
import protocol_emulator as pe

CLOCK_HZ = 48_000_000
# cycles from engine 0's raise of the wire to engine 1's stamp of it, the same path an
# edge on a pin takes less its two synchronizer flops
SYNC_CYCLES = 2
LATE_US = 1000


def load(host, engine):
    host.select(engine["engine"])
    host.stop()
    host.flush()
    host.configure(dict(pe.DEFAULT_CONFIG, **engine["config"]))
    host.load(engine["words"])


@micropython.native
def poll(spi, engine, words):
    """Selects engine, appends its waiting words to words, then returns the low half of its
    clock, read after the drain."""
    cs_n, bus, status, rx_in = spi.cs_n, spi.spi, spi.status, spi.rx_in
    cs_n(0)
    bus.write(bytes((0x80 | pe.SELECT, 0, engine)))
    cs_n(1)
    cs_n(0)
    bus.write_readinto(spi.reads[pe.STATUS], status)
    cs_n(1)
    level = (status[1] >> 2) & 15
    if level:
        out, into = spi.rx_frames[level]
        cs_n(0)
        bus.write_readinto(out, into)
        cs_n(1)
        for i in range(1, 1 + 2 * level, 2):
            words.append(rx_in[i] << 8 | rx_in[i + 1])
    cs_n(0)
    bus.write_readinto(spi.reads[pe.NOW_LO], status)
    cs_n(1)
    return status[1] << 8 | status[2]


def record(spi, host, engines, ms):
    # engine 1, if there are two, first: it waits for engine 0's wire
    for e in sorted(engines, key=lambda e: -e["engine"]):
        load(host, e)
    for e in sorted(engines, key=lambda e: -e["engine"]):
        host.select(e["engine"])
        host.start()
    n = len(engines)
    words = [[] for _ in range(n)]
    times = [[] for _ in range(n)]
    last = [0] * n
    clock = [0] * n
    seen = [0] * n
    late = 0
    then = [time.ticks_us()] * n
    start = time.ticks_ms()
    while time.ticks_diff(time.ticks_ms(), start) < ms:
        for k in range(n):
            got = words[k]
            before = len(got)
            now = poll(spi, engines[k]["engine"], got)
            t = time.ticks_us()
            if time.ticks_diff(t, then[k]) > LATE_US:
                late += 1
            then[k] = t
            clock[k] += (now - last[k]) & 0xFFFF
            last[k] = now
            for i in range(before, len(got)):
                times[k].append(clock[k] - ((now - got[i]) & 0xFFFF))
            seen[k] = len(got)
    faults = []
    for e in engines:
        host.select(e["engine"])
        faults.append(host.read(pe.STATUS)[0] & 0x3C)
        host.stop()
    return words, times, late, faults


def run(log=print):
    settings = json.load(open("record.json"))
    engines = settings["engines"]
    spi = pico_board.PicoSpi()
    host = pe.Host(spi.transfer)
    words, times, late, faults = record(spi, host, engines, settings["ms"])
    lines = []
    offset = 0
    for k, e in enumerate(engines):
        # the sync stamp, then the line's level, then an edge a word
        skip = 1 + (1 if e.get("sync") else 0)
        if e.get("sync"):
            offset = times[k][0] - SYNC_CYCLES
        lines.append((e, words[k][skip - 1] if len(words[k]) >= skip else None, times[k][skip:]))
    out = ["rate %d" % CLOCK_HZ]
    pins = []
    length = 0
    for e, level, edges in lines:
        # engine 0's clock started at its own start, which engine 1 saw at offset
        shift = 0 if e.get("sync") else offset
        edges = [t + shift for t in edges]
        if edges:
            length = max(length, edges[-1] + 1)
        pins.append("pin %s %d %s" % (e["name"], level or 0, " ".join(str(t) for t in edges)))
    out.append("length %d" % length)
    with open("record.edges", "w") as f:
        f.write("\n".join(out + pins) + "\n")
    for (e, _, edges), fault in zip(lines, faults):
        log("%s: %d edges stamped by engine %d, faults 0x%x" % (e["name"], len(edges), e["engine"], fault))
    log("polls more than %d us apart: %d" % (LATE_US, late))
    ok = not late and not any(faults) and all(len(edges) for _, _, edges in lines)
    log("PASS" if ok else "FAIL")
    return ok


if __name__ == "__main__":
    lines = []

    def log(text):
        print(text)
        lines.append(text)

    try:
        run(log)
    except Exception as e:
        log("stopped: %s" % e)
        log("FAIL")
    with open("record.log", "w") as f:
        f.write("\n".join(lines) + "\n")
