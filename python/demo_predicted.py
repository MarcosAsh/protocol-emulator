# SPDX-License-Identifier: Apache-2.0
# Runs a bench copy the way test/measure/predict.exe predicts it (MicroPython, Pico A).
# Loads the firmware into engine 0, then pushes the prediction's load and bursts as its run
# feeds them: a word whenever the fifo has room, each burst once the previous one is in the
# core. demo/hold_capture.py checks the capture against the same file. The gaps between
# bursts are the host's here, so only the first burst's edges line up with one alignment.
# Usage: mpremote connect $PICO cp python/protocol_emulator.py python/pico_board.py \
#            python/bench.py python/bench_firmware.py python/demo_predicted.py X.predicted : \
#            + exec "import demo_predicted; demo_predicted.main('X.predicted')"

import bench
import bench_firmware
import protocol_emulator as pe


def read(path):
    """Return the firmware's name, the host's bursts (with the load before the first, as
    the run feeds it) and the run's length in cycles at 48 MHz."""
    name, load, bursts, length = None, [], [], 0
    for line in open(path):
        word, _, rest = line.strip().partition(" ")
        if word == "firmware":
            name = rest
        elif word == "load":
            load = [int(rest)]
        elif word == "burst":
            bursts.append([int(w) for w in rest.split()])
        elif word == "length":
            length = int(rest)
            break
    if bursts:
        bursts[0] = load + bursts[0]
    return name, bursts, length


def run(host, firmware, bursts, polls=100_000):
    """Load and start engine 0 and feed it the bursts. Returns the fault bits once the last
    is in."""
    bench.load(host, firmware)
    host.start()
    for burst in bursts:
        waiting = list(burst)
        for _ in range(polls):
            level = host.status()["tx_level"]
            if not waiting and not level:
                break
            room = bench.DEPTH - level
            if waiting and room:
                host.push(waiting[:room])
                waiting = waiting[room:]
        else:
            raise RuntimeError("the fifo held %d words after %d polls" % (level, polls))
    return bench.faults(host)


def main(path):
    import time

    import pico_board

    log = bench.Log()
    name, bursts, length = read(path)
    host = pe.Host(pico_board.PicoSpi().transfer)

    def act():
        time.sleep_ms(bench.START_MS)
        run(host, getattr(bench_firmware, name.upper()), bursts)
        # the last burst is in the core but not out on the wire yet
        time.sleep_ms(1 + length // 48_000)
        found = bench.faults(host)
        log("%s: %d bursts, %d words, faults 0x%x" % (
            name, len(bursts), sum(len(b) for b in bursts), found))
        return not found

    bench.report(act, log)
