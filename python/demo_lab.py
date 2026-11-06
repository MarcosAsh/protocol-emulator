# SPDX-License-Identifier: Apache-2.0
# A remote lab job on Pico A (MicroPython). lab.json is generate.exe lab's firmware.json:
# the certified table interpreter, the diagram's table and its tx words. We load all of it
# while the engine is halted (the tx words fit the fifo), so the host's timing can't shape
# the waveform. The engine runs for run_ms and is stopped; PASS if its faults match the
# model's. demo/lab.py copies this over with lab.json and resets the chip before and after.

import bench
import protocol_emulator as pe


def run(transfer, pause_ms, firmware, log=print):
    host = pe.Host(transfer)
    bench.load(host, firmware)
    host.load_data(firmware["data"])
    if len(firmware["tx"]) > bench.DEPTH:
        raise RuntimeError("%d tx words, past the fifo's %d" % (len(firmware["tx"]), bench.DEPTH))
    if firmware["tx"]:
        host.push(firmware["tx"])
    host.start()
    pause_ms(firmware["run_ms"])
    host.stop()
    found = bench.faults(host)
    log("ran %d ms, faults 0x%x, the model's 0x%x" % (firmware["run_ms"], found, firmware["faults"]))
    return found == firmware["faults"]


if __name__ == "__main__":
    import json
    import time

    import pico_board

    log = bench.Log()
    with open("lab.json") as f:
        firmware = json.load(f)
    spi = pico_board.PicoSpi()
    time.sleep_ms(bench.START_MS)
    bench.report(lambda: run(spi.transfer, time.sleep_ms, firmware, log), log)
