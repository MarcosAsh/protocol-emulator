# SPDX-License-Identifier: Apache-2.0
# Plays a trace's host frames into the chip from Pico A (MicroPython), each after its gap,
# from the frames.py demo/decode.py --host-frames writes. The trace starts from reset, so
# first both engines are stopped and flushed, and engine 1 runs CLEAR: a stopped engine
# keeps its pins, and the top ORs both engines' outputs.
# Usage: demo/bench_decode.sh, which copies frames.py, protocol_emulator.py and
#        pico_board.py over and runs this with mpremote run --no-follow

import time

from frames import FRAMES
from pico_board import PicoSpi
from protocol_emulator import DEFAULT_CONFIG, Host

# mov pins, null / mov pindirs, null / halt, on OUT0 to IO7
CLEAR = [0x8003, 0x8063, 0xE001]


def main():
    spi = PicoSpi()
    host = Host(spi.transfer)
    time.sleep_ms(800)
    for engine in (1, 0):
        host.select(engine)
        host.stop()
        host.flush()
    host.select(1)
    host.configure(dict(DEFAULT_CONFIG, out_base=5, out_count=15))
    host.load(CLEAR)
    # no jump and no wrap: the certificate is the empty table
    host.certify([0, 0])
    host.start()
    host.select(0)
    for gap_us, frame in FRAMES:
        time.sleep_us(gap_us)
        spi.transfer(frame)


main()
