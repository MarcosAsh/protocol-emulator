# SPDX-License-Identifier: Apache-2.0
# Two engines and nothing outside the chip: a UART transmitter on engine 0, a receiver on
# engine 1, wire 20 between them, and the host reading from engine 1 what it gave engine 0.

import cocotb
from cocotb.triggers import ClockCycles

from test import AsyncHost, Pins, assembled, reset
from protocol_emulator import CONFIG, CONFIG_FIELDS, CONTROL, DEFAULT_CONFIG, PROGRAM, PROGRAM_ADDR, RX, SELECT, STATUS, TX

WIRE = 20


async def load(host, engine, config, words):
    await host.write(SELECT, [engine])
    for n, name in enumerate(CONFIG_FIELDS):
        await host.write(CONFIG + n, [config.get(name, 0)])
    await host.write(PROGRAM_ADDR, [0])
    await host.write(PROGRAM, words)


@cocotb.test()
async def test_uart_between_engines(dut):
    await reset(dut)
    host = AsyncHost(Pins(dut).transfer)

    receiver = dict(DEFAULT_CONFIG, in_base=WIRE, jmp_pin=WIRE, capture_pin=WIRE)
    await load(host, 1, receiver, assembled("uart_rx_wire"))
    await host.write(CONTROL, [1])
    transmitter = dict(DEFAULT_CONFIG, set_base=WIRE, out_base=WIRE)
    await load(host, 0, transmitter, assembled("uart_tx"))
    await host.write(TX, [0x55, 0xA3])
    await host.write(CONTROL, [1])

    for _ in range(400):
        await ClockCycles(dut.clk, 1)
        assert int(dut.uo_out.value) >> 1 == 0, "a wire reached a pin"
    # both idle: the sender took its two words, and no fault or irq anywhere
    assert (await host.read(STATUS))[0] == 0

    await host.write(SELECT, [1])
    assert (await host.read(SELECT))[0] == 1
    assert (await host.read(STATUS))[0] == 2 << 10, "two words wait in engine 1's rx fifo"
    assert await host.read(RX, 2) == [0x55, 0xA3]
