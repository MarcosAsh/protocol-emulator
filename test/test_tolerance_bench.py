# SPDX-License-Identifier: Apache-2.0
"""demo_tolerance.py on the RTL at the bench's 48 MHz, run blocking in a thread as Pico A
runs it, shortened to simulate: a half period of 26 cycles, four bytes, and a step at
each bound the receiver's certificate gives there and either side well past them."""

import cocotb
from cocotb.task import bridge

# test_outside puts ../python on the path, through test
from test_outside import acted, reset
import demo_tolerance
import tolerance_firmware as tf

HALF = 26
UNIT = 65536
NOMINAL = 2 * HALF * UNIT
# test/tolerance.ml's bounds at this half period: the arm 19 halves and 2 cycles after
# the start edge before the next start bit, the stop bit's middle after its own start
LEAST = -(-UNIT * (19 * HALF + 3) // 10)
MOST = UNIT * 19 * HALF // 9


@cocotb.test()
async def test_tolerance(dut):
    """Every frame through at the nominal rate and at both bounds, and lost 10% either
    side, each as predicted."""
    await reset(dut)
    tf.HALF = HALF
    tf.BYTES = [0x00, 0x55, 0xA5, 0x7F]
    tf.LEAST, tf.MOST = LEAST, MOST
    tf.STEPS = [(NOMINAL, True), (LEAST, True), (MOST, True),
                (NOMINAL * 9 // 10, False), (NOMINAL * 11 // 10, False)]
    transfer, _, log, lines = acted(dut)
    assert await bridge(demo_tolerance.run)(transfer, log=log), lines
    assert len([line for line in lines if line.startswith("ok")]) == len(tf.STEPS), lines
