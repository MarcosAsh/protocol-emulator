# SPDX-License-Identifier: Apache-2.0
# The chip built with a journal (make journal): a uart run on engine 0 while the pads move,
# then the dump firmware on engine 0 reads the ring back through the host port.

import random

import cocotb
from cocotb.triggers import ClockCycles

from test import AsyncHost, Pins, assembled, reset
from protocol_emulator import CONTROL, DEFAULT_CONFIG, JOURNAL, JOURNAL_WORDS, PROGRAM, PROGRAM_ADDR, RX, TX, config_writes, decode_journal


class PadPins(Pins):
    """Keeps IN0-4 where the test put them while the host talks on ui[2:0]."""

    def __init__(self, dut):
        super().__init__(dut)
        self.inputs = 0

    def drive(self):
        self.dut.ui_in.value = (self.inputs << 3) | (self.cs_n << 2) | (self.mosi << 1) | self.sck


async def load(host, config, words):
    for reg, word in config_writes(config):
        await host.write(reg, [word])
    await host.write(PROGRAM_ADDR, [0])
    await host.write(PROGRAM, words)


@cocotb.test()
async def test_journal_records_a_run(dut):
    await reset(dut)
    pins = PadPins(dut)
    host = AsyncHost(pins.transfer)
    await load(host, DEFAULT_CONFIG, assembled("uart_tx"))

    await host.write(JOURNAL, [1])
    await host.write(TX, [0x55, 0xA3])
    await host.write(CONTROL, [1])

    # the pads a few dozen cycles apart, IN0-4 low and IO0-7 above as the journal keeps them
    rng = random.Random(1)
    applied, gaps = [], []
    pads = 0
    for _ in range(12):
        gap = rng.randint(12, 60)
        await ClockCycles(dut.clk, gap)
        while True:
            moved = pads ^ (1 << rng.randrange(13))
            if moved != pads:
                break
        pads = moved
        pins.inputs = pads & 0x1F
        pins.drive()
        dut.uio_in.value = pads >> 5
        applied.append(pads)
        gaps.append(gap)
    await ClockCycles(dut.clk, 20)
    await host.write(JOURNAL, [0])

    await host.write(CONTROL, [4])
    dump = dict(DEFAULT_CONFIG, autopull=1, autopull_data=1)
    await load(host, dump, assembled("journal_dump"))
    await host.write(CONTROL, [1])
    ring = await host.read(RX, JOURNAL_WORDS)

    from_arm, entries = decode_journal(ring)
    codes = [code for code, _, _ in entries]
    assert from_arm, [hex(w) for w in ring[:24]]
    assert codes == ["arm", "tx", "tx", "control"] + ["pads"] * 12 + ["disarm"], entries
    moves = entries[4:16]
    assert [p for _, p, _ in moves] == applied, (moves, applied)
    # the synchroniser delays every edge alike, so the cycles between them are exact
    assert [d for _, _, d in moves[1:]] == gaps[1:], (moves, gaps)
