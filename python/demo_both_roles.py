# SPDX-License-Identifier: Apache-2.0
# Both roles on one chip (MicroPython, Pico A): engine 0 is a controller and engine 1 a
# target, each running the library's firmware on wires no pin shows, so only the host sees
# them. Covers I2C in Standard-mode and Fast-mode, SPI modes 0 to 3 and UART at 9600 to
# 230400 baud. Each case checks both engines against what they pushed on the RTL
# (both_roles_firmware.py). demo/both_roles.sh runs it.

import bench
import both_roles_firmware
import protocol_emulator as pe

DEPTH = bench.DEPTH


def levels(host):
    """Return the selected engine's (tx, rx) fifo levels."""
    status = host.read(pe.STATUS)[0]
    return (status >> 6) & 15, (status >> 10) & 15


def load(host, case):
    """Stop and flush both engines, then load and certify the controller on engine 0 and
    the target on engine 1."""
    bench.load(host, case["controller"], engine=0)
    target = case["target"]
    host.select(1)
    host.configure(target["config"])
    host.load(target["words"])
    host.certify(
        target["certificate"],
        loaded=target["loaded"],
        floor=target["floor"],
        single_edge=target["single_edge"])


def run_case(host, case, polls=20_000):
    """Start the target first with its words queued, then the controller with one fifo's
    worth and the rest as room appears. Pops both engines' pushes until each matches the
    RTL's count. Returns what each pushed and their status words."""
    load(host, case)
    host.select(1)
    host.push(case["target_words"])
    host.start()
    words = case["controller_words"]
    host.select(0)
    host.push(words[:DEPTH])
    host.start()
    sent = min(DEPTH, len(words))
    got = [[], []]
    wanted = [len(case["controller_pushes"]), len(case["target_pushes"])]
    for _ in range(polls):
        for engine in (0, 1):
            host.select(engine)
            tx, rx = levels(host)
            if rx:
                got[engine].extend(host.pop(rx))
            if engine == 0 and sent < len(words) and tx < DEPTH:
                chunk = words[sent:sent + DEPTH - tx]
                host.push(chunk)
                sent += len(chunk)
        if sent == len(words) and len(got[0]) >= wanted[0] and len(got[1]) >= wanted[1]:
            break
    status = []
    for engine in (0, 1):
        host.select(engine)
        status.append(host.read(pe.STATUS)[0])
    return got, status


def check(case, got, status, log):
    irq = [bool(s & 2) for s in status]
    faults = [s & bench.FAULTS for s in status]
    ok = (got[0] == case["controller_pushes"] and got[1] == case["target_pushes"]
          and irq == case["irq"] and faults == [0, 0])
    log("%s %s: controller %s, target %s%s" % (
        "ok  " if ok else "FAIL", case["name"], bench.hexs(got[0]), bench.hexs(got[1]),
        "" if ok else " (wanted %s, %s; irq %s, faults 0x%x 0x%x)" % (
            bench.hexs(case["controller_pushes"]), bench.hexs(case["target_pushes"]),
            irq, faults[0], faults[1])))
    return ok


def run(transfer, log=print, only=None):
    """Run every case, or only those whose name contains `only`. Stops at the first case
    that leaves a fault, since faults stick until reset."""
    host = pe.Host(transfer)
    passed = True
    for case in both_roles_firmware.CASES:
        if only and only not in case["name"]:
            continue
        got, status = run_case(host, case)
        passed = check(case, got, status, log) and passed
        if any(s & bench.FAULTS for s in status):
            log("a fault holds until reset: stopped")
            return False
    return passed


if __name__ == "__main__":
    import sys
    import time

    import pico_board

    log = bench.Log()
    spi = pico_board.PicoSpi()
    time.sleep_ms(bench.START_MS)
    only = sys.argv[1] if len(sys.argv) > 1 else None
    bench.report(lambda: run(spi.transfer, log, only), log)
