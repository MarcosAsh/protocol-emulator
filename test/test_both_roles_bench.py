# SPDX-License-Identifier: Apache-2.0
"""demo_both_roles.py and demo_rates.py on the RTL at the bench's 48 MHz, run blocking in a
thread as Pico A runs them, against the bench's parts where there is a model of one: a
cocotbext-i2c memory at 0x50 for the 24LC256, and picosoc's flash. The pins are sampled
as the analysers sample them and decoded as demo/both_roles.sh and demo/rates.sh decode
the bench's captures."""

import cocotb
from cocotb.task import bridge, resume
from cocotb.utils import get_sim_time

# test_outside puts ../python on the path, through test
from test_outside import Analyser, Memory, acted, bit, decode, reset
import both_roles_firmware
import demo_both_roles
import demo_eeprom
import demo_rates

I2C = ["-P", "i2c:sda=D6:scl=D7", "-A", "i2c=address-read:address-write:data-read:data-write"]


def i2c_analyser(dut):
    return Analyser({6: bit(dut.sda), 7: bit(dut.scl)})


def eeprom(dut):
    return Memory(sda=dut.sda, sda_o=dut.sda_o, scl=dut.scl, scl_o=dut.scl_o, addr=0x50,
                  size=32768)


@cocotb.test()
async def test_both_roles(dut):
    """Every case, the bus case beside a memory at 0x50 that has to stay quiet, and on the
    bus the target's half of it as sigrok reads it."""
    await reset(dut)
    eeprom(dut)
    analyser = i2c_analyser(dut)
    transfer, _, log, lines = acted(dut)
    assert await bridge(demo_both_roles.run)(transfer, log=log)
    assert len([line for line in lines if line.startswith("ok")]) == len(
        both_roles_firmware.CASES), lines
    decoded = decode(analyser, "both_roles", I2C)
    want = [
        "Address write: 42", "Data write: 10", "Data write: 5A", "Address write: 42",
        "Data write: 01", "Address read: 42", "Data read: 12", "Data read: 34",
        "Address write: 77",
    ]
    # the decoder's Write and Read rows say only which way the address went
    got = [line.split(": ", 1)[1] for line in decoded]
    assert [row for row in got if row not in ("Write", "Read")] == want, decoded


def setups(analyser):
    """Each START's setup and hold and each STOP's setup, in ns, from the bus's edges."""
    sda, scl = analyser.levels(6), analyser.levels(7)

    def level(edges, at):
        return [v for t, v in edges if t <= at][-1]

    def last(edges, at, value):
        return max(t for t, v in edges if t <= at and v == value)

    starts, stops = [], []
    for at, value in sda[1:]:
        if level(scl, at) != 1:
            continue
        if value == 0:
            hold = min((t for t, v in scl if t > at and v == 0), default=None)
            starts.append(((at - last(scl, at, 1)) / 1000, hold and (hold - at) / 1000))
        else:
            stops.append((at - last(scl, at, 1)) / 1000)
    return starts, stops


@cocotb.test()
async def test_rates_i2c(dut):
    """The EEPROM demo in Standard-mode then Fast-mode. Each START's setup and hold and
    each STOP's setup, from the pins as they are with no rise time, clear UM10204's least
    for the mode's rows by the rise it allows: 1000 ns and 300 ns."""
    await reset(dut)
    memory = eeprom(dut)
    analyser = i2c_analyser(dut)
    transfer, pause_ms, log, lines = acted(dut)

    @resume
    async def clock():
        return get_sim_time("ns") // 1_000_000

    assert await bridge(demo_rates.i2c)(transfer, clock, pause_ms, log=log)
    page = list(memory.read_mem(demo_eeprom.PAGE_ADDRESS, demo_eeprom.PAGE))
    assert page[0] != 0, page[:8]
    starts, stops = setups(analyser)
    least_setup = min(setup for setup, _ in starts[1:])
    least_hold = min(hold for _, hold in starts if hold)
    cocotb.log.info("least START setup %d ns, hold %d ns, least STOP setup %d ns",
                    least_setup, least_hold, min(stops))
    # the least over both modes is Fast-mode's: 600 ns, and the rise where a release
    # starts the width
    assert least_setup >= 900 and least_hold >= 600 and min(stops) >= 900
    decoded = decode(analyser, "rates_i2c", [
        "-P", "i2c:sda=D6:scl=D7,eeprom24xx:chip=onsemi_cat24c256", "-A", "eeprom24xx"])
    assert any("Page write" in line for line in decoded), decoded


@cocotb.test()
async def test_rates_uart(dut):
    """The two fastest rates on OUT0, each decoded by sigrok's uart decoder at its rate;
    the slower ones take the same words and only longer."""
    await reset(dut)
    for baud in (115200, 230400):
        analyser = Analyser({4: bit(dut.uo_out, 1)})
        transfer, pause_ms, log, _ = acted(dut)
        assert await bridge(demo_rates.uart)(transfer, pause_ms, baud, log=log)
        decoded = decode(analyser, "rates_uart_%d" % baud, [
            "-P", "uart:rx=D4:baudrate=%d" % baud, "-A", "uart=rx-data"])
        assert [line.split(": ")[-1] for line in decoded] == ["55", "A3", "00", "FF"], decoded
