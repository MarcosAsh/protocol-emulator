# SPDX-License-Identifier: Apache-2.0
# The video's first two shots on Pico A (MicroPython), where the chip's check judges a uart_tx
# on engine 0. A refused program must stay halted, and an accepted one sends data on OUT0 with
# no fault. demo/video.py supplies the words and reads the RESULT line.

import time

import protocol_emulator as pe


def run(transfer, words, certificate, data):
    host = pe.Host(transfer)
    for engine in (1, 0):
        host.select(engine)
        host.stop()
        host.flush()
    host.configure(pe.DEFAULT_CONFIG)
    host.load(words)
    try:
        host.certify(certificate)
    except pe.Refused as e:
        pc, reason = e.args
        host.start()
        print("RESULT refused %d %d %d" % (pc, reason, host.status()["halted"]))
        return
    host.start()
    host.push(data)
    time.sleep_ms(200)
    status = host.status()
    print("RESULT ran %d %x" % (status["halted"], host.read(pe.STATUS)[0] & pe.FAULTS))
