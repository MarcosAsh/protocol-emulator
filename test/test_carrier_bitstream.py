# SPDX-License-Identifier: Apache-2.0
"""Runs icepi/carrier_check.v (the bench carrier's self-test bitstream) with
python/carrier_pins.py's own frames in a thread, each an SPI transfer at Pico A's 1 MHz.
Checks the signature, what a frame drives and reads, slot timing to the microsecond, a
presence pulse read back, and the button restoring idle. `make carrier_check`."""

import sys

import cocotb
from cocotb.clock import Clock
from cocotb.task import bridge, resume
from cocotb.triggers import Edge, Timer
from cocotb.utils import get_sim_time

sys.path.insert(0, "../python")
from carrier_pins import IDLE, PIN, Pins, bit  # noqa: E402

HALF_NS = 500


async def start(dut):
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())
    await Timer(1, "us")


def pins(dut):
    @resume
    async def transfer(data):
        dut.cs_n.value = 0
        await Timer(1, "us")
        reply = []
        for byte in data:
            got = 0
            for i in range(8):
                dut.mosi.value = (byte >> (7 - i)) & 1
                await Timer(HALF_NS, "ns")
                dut.sck.value = 1
                got = (got << 1) | int(dut.miso.value)
                await Timer(HALF_NS, "ns")
                dut.sck.value = 0
            reply.append(got)
        await Timer(1, "us")
        dut.cs_n.value = 1
        await Timer(2, "us")
        return bytes(reply)

    @resume
    async def wait_us(us):
        await Timer(us, "us")

    return Pins(transfer, wait_us)


def drive(dut, header, level):
    """Drive the far end of a header pin to 0 or 1, or None to leave it to the pulls."""
    mask = 1 << PIN[header]
    oe, out = int(dut.ext_oe.value), int(dut.ext_out.value)
    dut.ext_oe.value = oe | mask if level is not None else oe & ~mask
    dut.ext_out.value = out | mask if level else out & ~mask


@cocotb.test()
async def test_frames(dut):
    await start(dut)
    p = pins(dut)

    def run():
        assert p.signature() == b"pin"
        idle = p.apply({})
        # headers 10 and 28 are driven high, the pull-ups are high, the rest pull down
        high = {10, 28, 33, 35, 36, 37}
        assert idle == sum(1 << PIN[h] for h in high), hex(idle)
        assert bit(p.apply({8: 1, 33: 0}), 8) == 1
        assert bit(p.apply({}), 33) == 0
        assert not bit(p.apply({8: None, 33: None}), 8)
        return p

    await bridge(run)()
    for header in (3, 5, 7, 11, 13, 15, 29, 40):
        drive(dut, header, 1)
        levels = await bridge(p.apply)({})
        assert bit(levels, header) == 1, header
        assert levels & ~(1 << PIN[header]) == await bridge(p.apply)({}) & ~(1 << PIN[header])
        drive(dut, header, None)
        # a write lands at the end of the step, after the next drive reads
        await Timer(1, "us")


@cocotb.test()
async def test_slots(dut):
    """A reset slot is low for 480 us and samples at 550, and a presence pulse from 510 to
    630 reads as 0. A 5 us pull reads 1 at 30 us from a pull-up and 0 from a pull-down."""
    await start(dut)
    p = pins(dut)
    dq = dut.dq
    edges = []

    async def presence():
        await Edge(dq)
        fell = get_sim_time("ns")
        edges.append(fell)
        await Edge(dq)
        rose = get_sim_time("ns")
        edges.append(rose)
        if rose - fell >= 480_000:
            await Timer(30, "us")
            drive(dut, 37, 0)
            await Timer(120, "us")
            drive(dut, 37, None)

    watcher = cocotb.start_soon(presence())
    assert await bridge(p.one_wire_reset)()
    await watcher
    low = edges[1] - edges[0]
    assert 480_000 <= low <= 480_100, low
    assert await bridge(p.slot)(33, 0, 5, 30) == 1
    assert await bridge(p.slot)(7, 0, 5, 30) == 0
    assert await bridge(p.slot)(7, 1, 50, 20) == 1
    # no answer: the pull-up holds the line high through the sample
    assert not await bridge(p.one_wire_reset)()


@cocotb.test()
async def test_button(dut):
    """The button releases every pin except the two idle ones."""
    await start(dut)
    p = pins(dut)
    await bridge(p.apply)({8: 1, 10: 0, 28: None})
    dut.button_n.value = 0
    await Timer(1, "us")
    dut.button_n.value = 1
    p.oe = p.out = IDLE
    levels = await bridge(p.frame)()
    assert (bit(levels[0], 8), bit(levels[0], 10), bit(levels[0], 28)) == (0, 1, 1)
