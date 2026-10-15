# SPDX-License-Identifier: Apache-2.0
# The kernel against the board, on the host Pico (MicroPython): each delay variant of a
# swept firmware runs as the sweep runs the firmware, held to the firmware's own edges, and
# a line says what the chip did with it. demo/kernel_vs_board.py sends the variants and
# holds the lines to the kernel's verdicts. Needs demo_sweep.py and what it needs.

import gc

import protocol_emulator as pe
import sweep_firmware as sf
from demo_self_timing import faults, host_drain
from demo_sweep import config, setup, sweep

# the chip's load check refuses with it, on a build that has one
Refused = getattr(pe, "Refused", None)
FIRMWARE = {firmware["name"]: firmware for firmware in sf.SWEPT}


def stays_halted(host):
    """Whether engine 0 stays halted when told to start, as a refused program must."""
    host.select(0)
    host.start()
    halted = host.status()["halted"]
    host.stop()
    host.select(1)
    return halted


def start_logger(host):
    """Engine 1 loaded with the logger and halted, engine 0 halted, as a check needs."""
    host.select(0)
    host.stop()
    host.select(1)
    host.stop()
    host.flush()
    host.configure(config(sf.LOGGER["config"]))
    host.load(sf.LOGGER["words"])
    if Refused is not None:
        host.certify(sf.LOGGER["certificate"])


def run(transfer, variants, drain=None):
    """A line for each (name, k, words, certificate) in variants: "ran" with the sweep's
    exact, within and out counts and both engines' faults, or "refused" with the chip's pc
    and reason and whether a start then left it halted. Faults hold until reset, so it
    stops after the first variant that sets one."""
    host = pe.Host(transfer)
    found = faults(host)
    if any(found):
        print("HELD %x %x" % tuple(found))
        return
    poll = host_drain(host) if drain is None else drain
    start_logger(host)
    # nothing is known of engine 0's memory yet
    dirty = pe.PROGRAM_WORDS
    for name, k, words, certificate in variants:
        gc.collect()
        firmware = dict(FIRMWARE[name], words=words)
        if certificate is not None:
            firmware["certificate"] = certificate
        try:
            dirty = setup(host, firmware, dirty)
        except Exception as e:
            if Refused is None or not isinstance(e, Refused):
                raise
            dirty = max(dirty, len(words))
            pc, reason = e.args
            print("RESULT %s %d refused %d %d %d" % (name, k, pc, reason, stays_halted(host)))
            continue
        (exact, within, out), _ = sweep(host, firmware, poll, None)
        found = faults(host)
        print("RESULT %s %d ran %d %d %d %x %x" % ((name, k, exact, within, out) + tuple(found)))
        if any(found):
            return
    print("DONE")
