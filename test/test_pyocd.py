# SPDX-License-Identifier: Apache-2.0
"""A stock pyOCD session through demo/swd_probe.py and python/bridge.py on the RTL at the
bench's 48 MHz and 1 MHz SWCLK, run blocking in a thread as Pico A runs the bridge, against
an RP2040's two DPs and core 0 (swd_target.py): connect, halt, read pc and the bootrom's
magic, resume. test_swd_probe.py runs the same in a second on a model of the firmware."""

import sys

import cocotb
from cocotb.task import bridge as threaded
from cocotb.triggers import ClockCycles

from test_swd import acted, clean, let_go, reset, unwire, wire
import bridge
import demo_swd
import swd_target

sys.path.insert(0, "../demo")
import swd_probe  # noqa: E402
from pyocd.core.session import Session  # noqa: E402


class Link:
    def __init__(self, transfer):
        host = demo_swd.pe.Host(transfer)
        self.bridge = bridge.Bridge(host, demo_swd.Swd(host))
        self.lines = []

    def open(self):
        pass

    def call(self, line):
        self.lines.append(line)
        return self.bridge.handle(line)[0]

    def close(self):
        self.call("x")


@cocotb.test()
async def test_pyocd_halt_read_resume(dut):
    await reset(dut)
    core = swd_target.Core()
    bus = swd_target.Bus([swd_target.Dp(swd_target.CORE0, core=core),
                          swd_target.Dp(swd_target.CORE1)])
    task = wire(dut, bus)
    transfer, _, _ = acted(dut)
    link = Link(transfer)

    def debug():
        with Session(swd_probe.Probe(link), no_config=True, target_override="cortex_m",
                     connect_mode="attach") as session:
            target = session.target
            target.halt()
            pc = target.read_core_register("pc")
            magic = target.read32(0x10)
            target.resume()
        return pc, magic

    pc, magic = await threaded(debug)()
    await ClockCycles(dut.clk, 100)
    assert let_go(dut)
    await unwire(dut, task)
    cocotb.log.info("%d bridge lines, core 0: %s", len(link.lines), core.log)
    # pyOCD's ABORT sets STKCMPCLR, SBZ on a MINDP DP: its own, as test_swd_probe.py says
    for dp in bus.dps:
        dp.violations = [v for v in dp.violations if v != "STKCMPCLR written to a MINDP DP"]
    clean(bus)
    assert (pc, magic) == (0x10001234, 0x0301754D), (hex(pc), hex(magic))
    assert core.log == ["halted", "resumed"], core.log
