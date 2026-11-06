# SPDX-License-Identifier: Apache-2.0
# Feeds frames into the chip's 10BASE-T receiver and through test/ethernet_rx.asm to the
# host: one from a sender on IO0 at 10 Mb/s (off the clock grid), one the chip sends
# itself, taken off its TD+ pad. Gate level runs only the first, since gl_test has little
# of its six hours to spare.

import os
import zlib

import cocotb
from cocotb.triggers import ClockCycles, First, RisingEdge, Timer
from cocotb.utils import get_sim_time

from test import AsyncHost, Pins, assembled, padded, reset
from protocol_emulator import (
    CONTROL, DATA, DATA_ADDR, DEFAULT_CONFIG, FRAME_STATUS, PROGRAM, PROGRAM_ADDR, RX,
    SELECT, STATUS, TX, arm_frame_writes, config_writes, frame_fields,
)
import ethernet

IO0 = 12
# where the frames land, above the chip's own frame
RX_BASE = 64
RX_CONFIG = dict(DEFAULT_CONFIG, autopull=1, autopull_data=1, pull_threshold=16)
GATES = os.environ.get("GATES") == "yes"


async def send(dut, levels, ppm):
    """Drive levels onto IO0, a half bit each, with the sender's 100 ns bit stretched by
    ppm. Each edge is moved to midway between a rising and a falling clock edge (the
    nearest pair), so gate-level runs with delays see no setup or hold violation. That
    adds 5 ns of jitter."""
    await RisingEdge(dut.clk)
    t0 = get_sim_time(unit="ps")
    now = t0
    for n, level in enumerate(levels):
        at = t0 + 5_000 + 10_000 * round(n * 50_000 * (1 + ppm * 1e-6) / 10_000)
        if at > now:
            await Timer(at - now, unit="ps")
            now = at
        dut.uio_in.value = level


async def receive(dut, data, ppm):
    """Send data (after the preamble) into the receiver. Returns the frame's status and the
    bytes handed over."""
    host = AsyncHost(Pins(dut).transfer)
    await load_receiver(host)
    # sample for 50 MHz, with the words in engine 0's turns
    for reg, words in arm_frame_writes(IO0, base=RX_BASE, fifty=True, owner=0):
        await host.write(reg, words)
    await host.write(TX, [RX_BASE])
    await host.write(CONTROL, [1])
    await send(dut, ethernet.halves(data), ppm)
    await ClockCycles(dut.clk, 20)
    return await handed(host, len(data))


async def load_receiver(host):
    for reg, word in config_writes(RX_CONFIG):
        await host.write(reg, [word])
    await host.write(PROGRAM_ADDR, [0])
    await host.write(PROGRAM, padded(assembled("ethernet_rx")))
    await host.certify_firmware("ethernet_rx")


async def handed(host, count):
    """Wait for the frame, then return the receiver's status and count bytes from the
    selected engine (which runs ethernet_rx)."""
    status = frame_fields((await host.read(FRAME_STATUS))[0])
    while not status["finished"]:
        status = frame_fields((await host.read(FRAME_STATUS))[0])
    words = []
    while len(words) < status["words"]:
        level = ((await host.read(STATUS))[0] >> 10) & 15
        if level:
            words += await host.read(RX, level)
    assert (await host.read(STATUS))[0] & 0x3D == 0, "running, no fault"
    return status, ethernet.received(words, count)


@cocotb.test()
async def test_frame_received(dut):
    """A UDP datagram with its FCS from a sender 100 ppm slow lands whole and is judged good."""
    await reset(dut)
    data = ethernet.wire(ethernet.udp(b"hello from the pins"))[len(ethernet.PREAMBLE):]
    status, got = await receive(dut, data, ppm=100)
    assert status["finished"] and status["fcs_ok"], status
    assert status["words"] == len(data) // 2 and not status["half"], status
    assert not status["dropped"], status
    assert got == data


@cocotb.test(skip=GATES)
async def test_bad_fcs_received(dut):
    """An odd number of bytes with the FCS's last bit flipped, from a sender 100 ppm fast.
    It still lands, its last word is a single byte, and it is judged bad."""
    await reset(dut)
    frame = list(range(1, 46)) + [0x5A] * 16
    data = frame + list((zlib.crc32(bytes(frame)) ^ 0x80000000).to_bytes(4, "little"))
    status, got = await receive(dut, data, ppm=-100)
    assert status["finished"] and not status["fcs_ok"], status
    assert status["words"] == (len(data) + 1) // 2 and status["half"], status
    assert got == data


@cocotb.test(skip=GATES)
async def test_own_frame_received(dut):
    """The chip hears itself. Engine 0 sends a datagram on TD+, the receiver takes it back
    off the pad as on the Icepi, and engine 1 hands it over with the FCS from engine 0's
    CRC unit, judged good. 4 cycles per bit is 8 samples at any clock."""
    await reset(dut)

    async def pad():
        while True:
            await First(dut.uio_out.value_change, dut.uio_oe.value_change)
            out, oe = dut.uio_out.value, dut.uio_oe.value
            if out.is_resolvable and oe.is_resolvable:
                dut.uio_in.value = int(out) & int(oe)

    looped = cocotb.start_soon(pad())
    host = AsyncHost(Pins(dut).transfer)
    frame = ethernet.udp(b"hello from myself")
    data = ethernet.wire(frame)[len(ethernet.PREAMBLE):]
    await host.write(SELECT, [1])
    await load_receiver(host)
    await host.write(SELECT, [0])
    for reg, word in config_writes(ethernet.CONFIG):
        await host.write(reg, [word])
    await host.write(PROGRAM_ADDR, [0])
    await host.write(PROGRAM, padded(assembled("ethernet")))
    await host.certify_firmware("ethernet")
    # data memory accepts writes only while both cores are halted
    await host.write(DATA_ADDR, [0])
    await host.write(DATA, ethernet.words(ethernet.PREAMBLE + frame))
    for reg, words in arm_frame_writes(IO0, base=RX_BASE, fifty=False, owner=1):
        await host.write(reg, words)
    await host.write(SELECT, [1])
    await host.write(TX, [RX_BASE])
    await host.write(CONTROL, [1])
    await host.write(SELECT, [0])
    await host.write(TX, [ethernet.LINK_TENTH, 8 * len(frame) - 2])
    await host.write(CONTROL, [1])
    await ClockCycles(dut.clk, ethernet.LINK_TENTH + 4 * 8 * len(ethernet.wire(frame)))
    await host.write(SELECT, [1])
    status, got = await handed(host, len(data))
    looped.cancel()
    assert status["finished"] and status["fcs_ok"] and not status["dropped"], status
    assert got == data
