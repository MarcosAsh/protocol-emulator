# SPDX-License-Identifier: Apache-2.0
# Plays a trace's host frames into the chip from Pico A (MicroPython), each after its gap,
# from the frames.py demo/decode.py --host-frames writes. Both engines are stopped and
# flushed first, as the trace starts from reset and a running core ignores its program.
# Usage: demo/bench_decode.sh, which copies frames.py, protocol_emulator.py and
#        pico_board.py over and runs this with mpremote run --no-follow

import time

from frames import FRAMES
from pico_board import PicoSpi
from protocol_emulator import Host


def main():
    spi = PicoSpi()
    host = Host(spi.transfer)
    time.sleep_ms(800)
    for engine in (1, 0):
        host.select(engine)
        host.stop()
        host.flush()
    for gap_us, frame in FRAMES:
        time.sleep_us(gap_us)
        spi.transfer(frame)


main()
