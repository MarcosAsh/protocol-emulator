# SPDX-License-Identifier: Apache-2.0
"""Runs demo_tolerance.py on the RTL at the bench's 48 MHz, blocking in a thread like Pico
A. Shortened to simulate: half period 26 cycles, four bytes, a step at each certificate
bound and one well outside each."""

import cocotb
from cocotb.task import bridge

# test_outside puts ../python on the path
from test_outside import acted, reset
import demo_tolerance
import tolerance_firmware as tf

HALF = tf.SHORT_HALF
UNIT = 65536
NOMINAL = 2 * HALF * UNIT
# bounds from test/tolerance.ml at this half period: the arm is 19 halves + 2 cycles after
# the start edge (before the next start bit), and the stop bit's middle after its start
LEAST = -(-UNIT * (19 * HALF + 3) // 10)
MOST = UNIT * 19 * HALF // 9


@cocotb.test()
async def test_tolerance(dut):
    """Frames must pass at the nominal rate and both bounds, and be lost at +-10% and one
    step past the fast bound (the single-edge fault), exactly as predicted."""
    await reset(dut)
    tf.HALF = HALF
    tf.BYTES = tf.SHORT_BYTES
    tf.SENDER = dict(tf.SENDER, **tf.SHORT_SENDER)
    tf.RECEIVER = dict(tf.RECEIVER, **tf.SHORT_RECEIVER)
    tf.FAULT = tf.SHORT_FAULT
    tf.LEAST, tf.MOST = LEAST, MOST
    # faults from test/tolerance.ml for this half period and these bytes
    tf.FAULTS = [LEAST - 1]
    tf.STEPS = [(NOMINAL, True), (LEAST, True), (MOST, True),
                (NOMINAL * 9 // 10, False), (NOMINAL * 11 // 10, False), (LEAST - 1, False)]
    transfer, _, log, lines = acted(dut)
    assert await bridge(demo_tolerance.run)(transfer, log=log), lines
    assert len([line for line in lines if line.startswith("ok")]) == len(tf.STEPS), lines
