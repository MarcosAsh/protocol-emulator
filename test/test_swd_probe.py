# SPDX-License-Identifier: Apache-2.0
"""demo/swd_probe.py under a stock pyOCD session, through python/bridge.py, against an
RP2040's two DPs and core 0 (swd_target.py), in a second. The chip's SWD firmware is
stood in for by Firmware, cycle for cycle as test/swd.mli describes it; test_pyocd.py runs
the same on the RTL. Run from the repository root: python3 test/test_swd_probe.py"""

import os
import shutil
import socket
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path[:0] = [HERE, os.path.join(HERE, "..", "python"), os.path.join(HERE, "..", "demo")]

import bridge  # noqa: E402
import demo_swd  # noqa: E402
import swd_probe  # noqa: E402
import swd_target  # noqa: E402
from pyocd.core.session import Session  # noqa: E402
from pyocd.probe.tcp_probe_server import DebugProbeServer  # noqa: E402

# chip cycles a half period: what the DP model times against its 21 ns floor
HALF_CYCLES = 2


class Firmware(demo_swd.Swd):
    """Swd.send as the SWD firmware answers it, on a swd_target.Bus: a sequence's driven
    bits, or a transfer and its eight idle cycles, SWDIO moving and sampled as SWCLK
    falls."""

    def __init__(self, bus):
        super().__init__(host=None)
        self.bus = bus
        self.started = False

    def clock(self, bit=None):
        """One SWCLK period, the host driving bit or not, and the line as it falls."""
        for swclk in (0, 1):
            for _ in range(HALF_CYCLES):
                line = self.bus.step(swclk, bit)
        return line

    def transfer(self, words):
        """The request, ACK on the three rises after it, then RDATA, parity and a
        turnaround, or two turnaround cycles and WDATA, which TARGETSEL's bit 8 sends
        whatever the ACK."""
        request = words[0] & 0xFF
        for i in range(8):
            self.clock((request >> i) & 1)
        ack = sum(self.clock() << i for i in range(3))
        if request & 4:
            reply = [0, 0, ack]
            if ack == demo_swd.OK:
                bits = [self.clock() for _ in range(33)]
                value = sum(b << i for i, b in enumerate(bits[:32]))
                bad = bin(value).count("1") & 1 != bits[32]
                reply = [value & 0xFFFF, value >> 16, ack | (bad << 3)]
            self.clock()
        else:
            reply = [ack]
            self.clock()
            if ack == demo_swd.OK or words[0] & 0x100:
                self.clock()
                value = words[1] | (words[2] << 16)
                for i in range(32):
                    self.clock((value >> i) & 1)
                self.clock(bin(value).count("1") & 1)
        for _ in range(8):
            self.clock(0)
        return reply

    def send(self, words, replies):
        if not self.started:
            self.started = True
            for _ in range(32):
                line = self.clock()
            return [line]
        if words[0] & 1:
            return self.transfer(words)
        for word in words[1:]:
            for i in range(16):
                self.clock((word >> i) & 1)
        return []


class Host:
    def stop(self):
        pass

    def flush(self):
        pass

    def start(self):
        pass


class Local(bridge.Bridge):
    """The bridge without Pico A: the line protocol straight to Firmware."""

    def __init__(self, bus):
        super().__init__(Host(), Firmware(bus))
        self.lines = []

    def start(self, half):
        self.swd.started = False
        return self.swd.send([half], 1)[0]

    def open(self):
        pass

    def call(self, line):
        self.lines.append(line)
        reply, _ = self.handle(line)
        return reply

    def close(self):
        self.call("x")


def clean(bus):
    """No timing or protocol violation but pyOCD's own: its ABORT sets STKCMPCLR, which a
    MINDP DP takes as SBZ, and which picoprobe and CMSIS-DAP send an RP2040 too."""
    for i, dp in enumerate(bus.dps):
        others = [v for v in dp.violations if v != "STKCMPCLR written to a MINDP DP"]
        assert others == [], (i, others)
    assert bus.contention == 0


def session(probe):
    return Session(probe, no_config=True, target_override="cortex_m", connect_mode="attach",
                   options={"resume_on_disconnect": True})


def test_halt_read_resume():
    core = swd_target.Core()
    bus = swd_target.Bus([swd_target.Dp(swd_target.CORE0, core=core),
                          swd_target.Dp(swd_target.CORE1)])
    link = Local(bus)
    probe = swd_probe.Probe(link)
    with session(probe) as s:
        target = s.target
        assert not core.halted
        target.halt()
        assert core.halted
        pc = target.read_core_register("pc")
        rom = target.read32(0x10)
        words = target.read_memory_block32(0, 5)
        target.resume()
        assert not core.halted
    assert pc == 0x10001234, hex(pc)
    assert rom == 0x0301754D, hex(rom)
    assert words == [swd_target.BOOTROM[4 * i] for i in range(5)], words
    clean(bus)
    assert "TARGETSEL 0x01002927: selected" in bus.dps[0].log
    assert "TARGETSEL 0x01002927: deselected" in bus.dps[1].log
    assert core.log == ["halted", "resumed"], core.log
    assert link.lines[-1] == "x"
    print("pyOCD halted, read and resumed core 0 in %d bridge lines" % len(link.lines))


def test_unpowered():
    bus = swd_target.Bus(undriven=0)
    probe = swd_probe.Probe(Local(bus))
    try:
        with session(probe):
            pass
    except Exception as e:
        assert "SWDIO is low" in str(e), e
    else:
        raise AssertionError("connected to nobody")


def test_fault():
    """A read outside the memory map: pyOCD sees the FAULT, clears it, and goes on."""
    core = swd_target.Core()
    bus = swd_target.Bus([swd_target.Dp(swd_target.CORE0, core=core)])
    with session(swd_probe.Probe(Local(bus))) as s:
        try:
            s.target.read32(0x50000000)
        except Exception as e:
            assert "fault" in type(e).__name__.lower() or "fault" in str(e).lower(), repr(e)
        else:
            raise AssertionError("no fault")
        assert s.target.read32(0x10) == 0x0301754D


def test_stock_commander():
    """pyocd commander, unchanged, over pyOCD's remote probe protocol, as on the bench."""
    pyocd = shutil.which("pyocd")
    if pyocd is None:
        print("no pyocd on PATH: commander skipped")
        return
    core = swd_target.Core()
    bus = swd_target.Bus([swd_target.Dp(swd_target.CORE0, core=core),
                          swd_target.Dp(swd_target.CORE1)])
    probe = swd_probe.Probe(Local(bus))
    with socket.socket() as free:
        free.bind(("localhost", 0))
        port = free.getsockname()[1]
    server = DebugProbeServer(Session(None, no_config=True), probe, port, serve_local_only=True)
    server.start()
    try:
        run = subprocess.run(
            [pyocd, "commander", "-u", "remote:localhost:%d" % port, "-t", "cortex_m",
             "-M", "attach", "-c", "halt; reg pc; read32 0x10; go"],
            capture_output=True, text=True, timeout=60)
    finally:
        server.stop()
    assert run.returncode == 0, run.stdout + run.stderr
    assert "Successfully halted device" in run.stdout, run.stdout
    assert "pc = 0x10001234" in run.stdout, run.stdout
    assert "00000010:  0301754d" in run.stdout, run.stdout
    assert "Successfully resumed device" in run.stdout, run.stdout
    assert core.log == ["halted", "resumed"], core.log
    clean(bus)


if __name__ == "__main__":
    test_halt_read_resume()
    test_stock_commander()
    test_unpowered()
    test_fault()
    print("PASS")
