# SPDX-License-Identifier: Apache-2.0
# I2C START hold times on a bus the chip only listens to (MicroPython, Pico A). Engine 1
# runs Firmware.start_hold on IO2 (SDA) and IO3 (SCL), driving neither, and pushes the
# cycles from each START's SDA fall to its SCL fall. Pico B is the master, through
# pico-examples' pio_i2c or its I2C block (demo/start_hold_master). The chip measures and
# this script judges, against UM10204's Standard-mode 4.0 us. demo/start_hold.sh runs it.

import bench
import bench_firmware
import protocol_emulator as pe

MHZ = 48
# UM10204 table 10, t_HD;STA in Standard-mode: 192 cycles
LIMIT_NS = 4000
COUNT = 64
# Pico B starts a read every 20 ms, two STARTs a read
LIMIT_MS = 5000


def ns(cycles):
    return cycles * 1000 // MHZ


def arm(host):
    bench.load(host, bench_firmware.START_HOLD, engine=1)
    host.start()


def collect(host, pause_ms, count, limit_ms):
    """Up to count holds, or what limit_ms of waits for them brought."""
    holds = []
    waited = 0
    while len(holds) < count and waited < limit_ms:
        level = bench.rx_level(host)
        if level:
            holds.extend(host.pop(level))
        else:
            pause_ms(1)
            waited += 1
    return holds[:count]


def judge(holds, log):
    """Logs the chip's holds as a histogram, then the verdict; True if all meet it."""
    log("chip, engine 1: %d STARTs, SDA fall to SCL fall, %d MHz cycles" % (len(holds), MHZ))
    counts = {}
    for hold in holds:
        counts[hold] = counts.get(hold, 0) + 1
    most = max(counts.values())
    for hold in sorted(counts):
        bar = "#" * max(1, 40 * counts[hold] // most)
        log("  %5d cycles %6d ns %5d  %s" % (hold, ns(hold), counts[hold], bar))
    short = [h for h in holds if ns(h) < LIMIT_NS]
    least = min(holds)
    ok = not short
    log("host, against t_HD;STA >= %d ns (%d cycles): %s, %d of %d short, least %d cycles (%d ns)" % (
        LIMIT_NS, LIMIT_NS * MHZ // 1000, "PASS" if ok else "FAIL", len(short), len(holds),
        least, ns(least)))
    return ok


def measure(host, pause_ms, log=print, count=COUNT, limit_ms=LIMIT_MS):
    """The verdict on count holds, or None if they did not come or the chip faulted."""
    holds = collect(host, pause_ms, count, limit_ms)
    found = bench.faults(host)
    if found:
        log("engine 1 faults 0x%x" % found)
        return None
    if not holds:
        log("no START in %d ms: is Pico B running and on IO2, IO3?" % limit_ms)
        return None
    return judge(holds, log)


def run(transfer, pause_ms, log=print, count=COUNT):
    host = pe.Host(transfer)
    arm(host)
    return measure(host, pause_ms, log, count)


if __name__ == "__main__":
    import time

    import pico_board

    log = bench.Log()
    spi = pico_board.PicoSpi()
    time.sleep_ms(bench.START_MS)
    try:
        verdict = run(spi.transfer, time.sleep_ms, log)
    except Exception as e:
        log("stopped: %s" % e)
        verdict = None
    log("no verdict" if verdict is None else ("PASS" if verdict else "FAIL"))
    log.save()
