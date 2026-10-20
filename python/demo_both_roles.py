# SPDX-License-Identifier: Apache-2.0
# Both roles on one chip (MicroPython, Pico A): engine 0 a controller and engine 1 a target,
# each the library's firmware, on wires no pin shows, so only the host sees them: I2C in
# Standard-mode and Fast-mode, SPI in modes 0 to 3, UART at 9600 to 230400 baud. Each case
# holds both engines to what they pushed on the RTL (both_roles_firmware.py).
# demo/both_roles.sh runs it.

import bench
import both_roles_firmware
import protocol_emulator as pe

DEPTH = bench.DEPTH


def levels(host):
    """The selected engine's tx and rx fifo levels."""
    status = host.read(pe.STATUS)[0]
    return (status >> 6) & 15, (status >> 10) & 15


def load(host, case):
    """Both engines stopped and flushed, the controller on engine 0 and the target on 1."""
    bench.load(host, case["controller"], engine=0)
    host.select(1)
    host.configure(case["target"]["config"])
    host.load(case["target"]["words"])


def run_case(host, case, polls=20_000):
    """The target started first with its words queued, then the controller with a fifo's
    worth and the rest as it has room, both engines' pushes popped until each has as many
    as on the RTL. Returns what each pushed, and their status words."""
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
    """Every case, or those whose name holds only. Stops at the first that leaves a fault,
    which holds until reset."""
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
