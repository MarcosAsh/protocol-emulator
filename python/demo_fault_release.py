# SPDX-License-Identifier: Apache-2.0
# Runtime fault on the board (MicroPython, Pico A), as test_two_engines.py's
# test_a_faulted_engine_lets_go_of_its_pins. Engine 0 (test/fault_release_low.asm) holds
# SWDIO (IO5, analyser A D7) low against its pull-up until one host word, then its second
# pull underflows. Engine 1's blink runs on OUT2 (D6) throughout. Words and certificates
# are test/*.hex's. demo/outside.sh fault_release takes the analyser and capture length from
# the next line, and its decode is SWDIO's low time.
# outside: analyser=A ms=4000 decode=-P timing:data=D7 -A timing=time
import time

import bench
import pico_board
import protocol_emulator as pe

FAULT = ([41057, 40960, 8416, 57348, 57348, 57345], [0, 0])
BLINK = ([41057, 41729, 41472, 1], [1, 0, 128, 0, 0])


def load(host, engine, config, firmware):
    host.select(engine)
    host.configure(config)
    host.load(firmware[0])
    host.certify(firmware[1])


log = bench.Log()
time.sleep_ms(bench.START_MS)
host = pe.Host(pico_board.PicoSpi().transfer)
for e in (1, 0):
    host.select(e)
    host.stop()
    host.flush()
load(host, 1, dict(pe.DEFAULT_CONFIG, set_base=7), BLINK)
load(host, 0, dict(pe.DEFAULT_CONFIG, set_base=17), FAULT)
host.select(1)
host.start()
host.select(0)
host.start()
time.sleep_ms(300)
log("before 0x%04x" % host.read(pe.STATUS)[0])
host.push([0])
time.sleep_ms(10)
s = host.read(pe.STATUS)[0]
pc = host.read(pe.PC)[0]
log("after 0x%04x pc %d" % (s, pc))
host.start()
time.sleep_ms(10)
s2 = host.read(pe.STATUS)[0]
pc2 = host.read(pe.PC)[0]
log("after a start 0x%04x pc %d" % (s2, pc2))
host.select(1)
s1 = host.read(pe.STATUS)[0]
log("engine 1 0x%04x" % s1)
ok = (s & 0x3D) == 0x05 and (s2 & 0x3D) == 0x05 and pc2 == pc and (s1 & 0x3D) == 0
log("PASS" if ok else "FAIL")
log.save()
