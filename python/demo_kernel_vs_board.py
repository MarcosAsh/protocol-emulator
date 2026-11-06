# SPDX-License-Identifier: Apache-2.0
# Kernel against board, on the host Pico (MicroPython). Runs each delay variant of a swept
# firmware the way the sweep does, checks it against the firmware's own edges and prints
# what the chip did. demo/kernel_vs_board.py sends the variants and checks the lines
# against the kernel's verdicts. Needs demo_sweep.py and its dependencies.

import gc

import protocol_emulator as pe
import sweep_firmware as sf
from demo_self_timing import faults, host_drain
from demo_sweep import config, setup, sweep

# raised when the chip's load check refuses a program (only on builds that have the check)
Refused = getattr(pe, "Refused", None)
FIRMWARE = {firmware["name"]: firmware for firmware in sf.SWEPT}


def stays_halted(host):
    """True if engine 0 stays halted when started, as a refused program must."""
    host.select(0)
    host.start()
    halted = host.status()["halted"]
    host.stop()
    host.select(1)
    return halted


def start_logger(host):
    """Load the logger into engine 1 and halt both engines, as a check needs."""
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
    """Print a line for each (name, k, words, certificate) in variants. "ran" gives the
    sweep's exact, within and out counts and both engines' faults. "refused" gives the
    chip's pc and reason and whether a start left it halted. Faults stick until reset, so
    we stop after the first variant that sets one."""
    host = pe.Host(transfer)
    found = faults(host)
    if any(found):
        print("HELD %x %x" % tuple(found))
        return
    poll = host_drain(host) if drain is None else drain
    start_logger(host)
    # we don't know what engine 0's memory holds yet
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
