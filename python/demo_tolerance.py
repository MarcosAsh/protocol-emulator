# SPDX-License-Identifier: Apache-2.0
# The receiver's tolerance, measured (MicroPython, Pico A): engine 1 sends the same bytes
# back to back from one anchor at each rate tolerance_firmware.py lists, in steps of
# 2^-16 of a cycle a bit through its period fraction, and engine 0's uart_rx_host_rate
# takes them off a wire no pin shows. Each step is held to what the model predicts; the
# first failure either side should fall just past the bound the certificate gives.
# demo/tolerance.sh runs it.

import bench
import protocol_emulator as pe
import tolerance_firmware as tf

DEPTH = bench.DEPTH


def levels(host):
    """The selected engine's tx and rx fifo levels."""
    status = host.read(pe.STATUS)[0]
    return (status >> 6) & 15, (status >> 10) & 15


def ppm(m):
    nominal = 2 * tf.HALF * tf.UNIT
    return (m - nominal) * 1_000_000 // nominal


def load(host, m):
    """Both engines stopped and flushed; engine 0 the receiver, engine 1 the sender at m,
    the whole cycles of its period as its first host word and the rest as its fraction."""
    for engine in (1, 0):
        host.select(engine)
        found = bench.faults(host)
        if found:
            raise RuntimeError(
                "engine %d holds faults 0x%x from an earlier run: reset the chip" % (engine, found))
        host.stop()
        host.flush()
        host.clear_irq()
    host.select(0)
    host.configure(tf.RECEIVER["config"])
    host.load(tf.RECEIVER["words"])
    host.select(1)
    config = dict(tf.SENDER["config"])
    config["period_fraction"] = m % tf.UNIT
    host.configure(config)
    host.load(tf.SENDER["words"])


def run_step(host, m, polls=20_000):
    """The receiver started first, so it is armed, then the sender with its period and a
    fifo's worth of bytes, the rest as it has room. Returns the bytes engine 0 pushed and
    both status words."""
    load(host, m)
    host.select(0)
    host.push([tf.HALF])
    host.start()
    words = [m // tf.UNIT] + tf.BYTES
    host.select(1)
    host.push(words[:DEPTH])
    host.start()
    sent = min(DEPTH, len(words))
    got = []
    quiet = 0
    for _ in range(polls):
        host.select(1)
        tx, _ = levels(host)
        if sent < len(words) and tx < DEPTH:
            chunk = words[sent:sent + DEPTH - tx]
            host.push(chunk)
            sent += len(chunk)
        host.select(0)
        _, rx = levels(host)
        if rx:
            got.extend(host.pop(rx))
            quiet = 0
        else:
            quiet += 1
        # a lost frame leaves fewer words: done once the line has long gone quiet
        if sent == len(words) and (len(got) >= len(tf.BYTES) or quiet > 2_000):
            break
    status = []
    for engine in (0, 1):
        host.select(engine)
        status.append(host.read(pe.STATUS)[0])
    return got, status


def run(transfer, log=print):
    """Every step, then the first failure either side against the bounds. Stops at a
    fault, which holds until reset; a framing error is only an irq and is cleared."""
    host = pe.Host(transfer)
    agree = True
    first_faster, first_slower = None, None
    log("bounds: m from %d to %d (%d to %d ppm)" % (
        tf.LEAST, tf.MOST, ppm(tf.LEAST), ppm(tf.MOST)))
    for m, predicted in tf.STEPS:
        got, status = run_step(host, m)
        if any(s & bench.FAULTS for s in status):
            log("m %d: a fault holds until reset (0x%x 0x%x): stopped" % (m, status[0], status[1]))
            return False
        ok = got == tf.BYTES and not status[0] & 2
        agree = agree and ok == predicted
        if not ok and m < tf.LEAST and (first_faster is None or m > first_faster):
            first_faster = m
        if not ok and m > tf.MOST and (first_slower is None or m < first_slower):
            first_slower = m
        inside = tf.LEAST <= m <= tf.MOST
        log("%s m %d (%+d ppm): %s, predicted %s%s" % (
            "ok  " if ok == predicted else "FAIL", m, ppm(m), "received" if ok else "lost",
            "received" if predicted else "lost",
            "" if ok or not inside else " INSIDE THE BOUNDS"))
    log("first failure faster: %s, %s steps past the bound" % (
        first_faster, None if first_faster is None else tf.LEAST - first_faster))
    log("first failure slower: %s, %s steps past the bound" % (
        first_slower, None if first_slower is None else first_slower - tf.MOST))
    return agree


if __name__ == "__main__":
    import time

    import pico_board

    log = bench.Log()
    spi = pico_board.PicoSpi()
    time.sleep_ms(bench.START_MS)
    bench.report(lambda: run(spi.transfer, log), log)
