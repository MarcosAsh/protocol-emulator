# Runtime fault on the board (MicroPython, Pico A), test_two_engines.py's
# test_a_faulted_engine_lets_go_of_its_pins with engine 1's blink on OUT2 (analyser A D6).
# Engine 0 (test/fault_release.asm) holds OUT0 (D4) high until one host word, then its
# second pull underflows. Words and certificates from test/*.hex at commit 67386afb.
import time
import pico_board
import protocol_emulator as pe

FAULT = ([45153, 45057, 12512, 61444, 61444, 40960, 57345], [0, 0])
BLINK = ([41057, 41729, 41472, 1], [1, 0, 128, 0, 0])
lines = []

def log(s):
    lines.append(s)

def load(host, engine, config, firmware):
    host.select(engine)
    host.configure(config)
    host.load(firmware[0])
    host.certify(firmware[1])

time.sleep_ms(1000)
host = pe.Host(pico_board.PicoSpi().transfer)
for e in (1, 0):
    host.select(e)
    host.stop()
    host.flush()
load(host, 1, dict(pe.DEFAULT_CONFIG, set_base=7), BLINK)
load(host, 0, dict(pe.DEFAULT_CONFIG, set_base=12, side_set_count=1, side_set_base=5), FAULT)
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
with open("fault.log", "w") as f:
    f.write("\n".join(lines) + "\n")
