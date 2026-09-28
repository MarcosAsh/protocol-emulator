# SPDX-License-Identifier: Apache-2.0
# UART transmitter on engine 0, receiver on engine 1, over wire 20.

import cocotb
from cocotb.triggers import ClockCycles

from test import AsyncHost, Pins, assembled, reset
from protocol_emulator import CONTROL, DEFAULT_CONFIG, PROGRAM, PROGRAM_ADDR, RX, SELECT, STATUS, TX, config_writes

WIRE = 20


async def load(host, engine, config, words):
    await host.write(SELECT, [engine])
    for reg, word in config_writes(config):
        await host.write(reg, [word])
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


@cocotb.test()
async def test_one_engine_times_the_other(dut):
    """Engine 1 stamps engine 0's edges: each a whole number of bit periods after its
    start bit, as the certificate says. When the host reads the stamps moves none."""
    await reset(dut)
    host = AsyncHost(Pins(dut).transfer)
    period = 434
    data = [0x55, 0xA3]

    logger = dict(DEFAULT_CONFIG, jmp_pin=WIRE, autopush=1)
    await load(host, 1, logger, assembled("edge_logger_wire"))
    await host.write(CONTROL, [1])
    transmitter = dict(DEFAULT_CONFIG, set_base=WIRE, out_base=WIRE)
    await load(host, 0, transmitter, assembled("uart_tx_host_rate"))
    await host.write(TX, [period] + data)
    await host.write(CONTROL, [1])

    frames = []
    for byte in data:
        levels = [0] + [(byte >> i) & 1 for i in range(8)] + [1]
        edges = [bit for bit in range(10) if levels[bit] != (levels[bit - 1] if bit else 1)]
        frames.append((byte, edges))
    expected = 1 + sum(len(edges) for _, edges in frames)

    await host.write(SELECT, [1])
    stamps = []
    for _ in range(200):
        level = ((await host.read(STATUS))[0] >> 10) & 15
        if level:
            stamps += await host.read(RX, level)
        if len(stamps) >= expected:
            break
        await ClockCycles(dut.clk, 100)
    assert len(stamps) == expected, f"{len(stamps)} edges seen, {expected} expected"
    # both still running, with no irq and no fault
    assert (await host.read(STATUS))[0] & 0x3F == 0
    await host.write(SELECT, [0])
    assert (await host.read(STATUS))[0] & 0x3F == 0

    # the first stamp is the line going idle; then each frame, start bit first
    stamps = stamps[1:]
    for byte, edges in frames:
        measured, stamps = stamps[: len(edges)], stamps[len(edges):]
        offsets = [(stamp - measured[0]) & 0xFFFF for stamp in measured]
        predicted = [bit * period for bit in edges]
        dut._log.info(f"0x{byte:02x} predicted {predicted} measured {offsets}")
        assert offsets == predicted
