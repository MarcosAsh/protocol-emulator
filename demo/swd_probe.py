# SPDX-License-Identifier: Apache-2.0
# Pico B's SWD port as a pyOCD debug probe, served over pyOCD's own remote probe protocol so
# a stock pyOCD drives it with no plugin. Every SWD edge comes from the chip's SWD firmware,
# which Pico A runs through python/bridge.py; the wiring is demo_swd.py's. No nRESET is
# wired, so connect with -M attach.
# Usage: PICO=id:<serial of Pico A> python3 demo/swd_probe.py [--port 5555] [--core 0]
#        pyocd commander -u remote:localhost:5555 -t cortex_m -M attach
import argparse
import math
import os
import signal
import subprocess
import sys
import time

from pyocd.core import exceptions
from pyocd.core.session import Session
from pyocd.probe.debug_probe import DebugProbe
from pyocd.probe.tcp_probe_server import DebugProbeServer

HERE = os.path.dirname(os.path.abspath(__file__))
PYTHON = os.path.join(HERE, "..", "python")
FILES = ["protocol_emulator.py", "pico_board.py", "bench.py", "bench_firmware.py",
         "demo_swd.py", "bridge.py"]

# the Icepi's PLL, and Swd.shortest_half, the firmware's floor
CLOCK_HZ = 48_000_000
SHORTEST_HALF = 10
OK, WAIT, FAULT = 1, 2, 4
PARITY = 8
# RP2040 datasheet 2.3.4
TARGETS = [0x01002927, 0x11002927]
RDBUFF = 0xC
# ops on one line, so a reply stays well inside the bridge's line
CHUNK = 64


def half_for(frequency):
    """The half period in chip cycles for the fastest SWCLK at most frequency."""
    return max(SHORTEST_HALF, math.ceil(CLOCK_HZ / (2 * frequency)))


class SerialLink:
    """python/bridge.py on Pico A, over its USB serial port's raw REPL."""

    def __init__(self, pico):
        self.pico = pico
        self.transport = None

    def install(self):
        subprocess.run(["mpremote", "connect", self.pico, "cp"]
                       + [os.path.join(PYTHON, f) for f in FILES] + [":"],
                       check=True, stdout=subprocess.DEVNULL)

    def open(self):
        import serial.tools.list_ports
        from mpremote.transport_serial import SerialTransport

        serial_number = self.pico.removeprefix("id:")
        ports = [p.device for p in serial.tools.list_ports.comports()
                 if p.serial_number == serial_number]
        if not ports:
            raise exceptions.ProbeError("no Pico with serial number %s" % serial_number)
        self.transport = SerialTransport(ports[0], baudrate=115200)
        self.transport.enter_raw_repl()
        self.transport.exec_raw_no_follow("import bridge\nbridge.main()")
        self.transport.read_until(1, b"bridge\r\n", timeout=10)
        self.transport.serial.timeout = 5

    def call(self, line):
        self.transport.serial.write(line.encode() + b"\n")
        reply = self.transport.serial.readline()
        if not reply.endswith(b"\n"):
            raise exceptions.ProbeDisconnected("no reply from Pico A to %r" % line[:40])
        return reply.decode().strip()

    def close(self):
        if self.transport is None:
            return
        try:
            self.call("x")
            self.transport.follow(5)
            self.transport.exit_raw_repl()
        finally:
            self.transport.close()
            self.transport = None


def check(status):
    if status & PARITY:
        raise exceptions.TransferError("RDATA parity error")
    if status == WAIT:
        raise exceptions.TransferTimeoutError("SWD ACK WAIT, retried")
    if status == FAULT:
        raise exceptions.TransferFaultError("SWD ACK FAULT")
    if status != OK:
        raise exceptions.TransferError("no SWD ACK (0b%s)" % format(status, "03b"))


class Probe(DebugProbe):
    """No SWJ_SEQUENCE: pyOCD's own line reset would leave both RP2040 DPs answering, so
    connect does the wake-up and TARGETSEL itself, as demo_swd.py does."""

    def __init__(self, link, core=0):
        super().__init__()
        self.link = link
        self.target = TARGETS[core]
        self.half = half_for(1_000_000)
        self.opened = False
        self.connected = False
        self.lines = 0
        self.transfers = 0

    @property
    def vendor_name(self):
        return "protocol-emulator"

    @property
    def product_name(self):
        return "SWD through the chip"

    @property
    def supported_wire_protocols(self):
        return [DebugProbe.Protocol.DEFAULT, DebugProbe.Protocol.SWD]

    @property
    def unique_id(self):
        return "protoemu"

    @property
    def wire_protocol(self):
        return DebugProbe.Protocol.SWD if self.connected else None

    @property
    def is_open(self):
        return self.opened

    @property
    def capabilities(self):
        return set()

    def open(self):
        self.link.open()
        self.opened = True

    def close(self):
        self.connected = False
        self.opened = False
        self.link.close()

    def ops(self, ops):
        """The replies to ops, a line at a time; the first not OK raises."""
        replies = []
        self.transfers += sum(op[0] in "rw" for op in ops)
        for i in range(0, len(ops), CHUNK):
            self.lines += 1
            got = self.link.call(";".join(ops[i:i + CHUNK]))
            if got.startswith("!"):
                raise exceptions.ProbeError("Pico A: %s" % got[1:].strip())
            for reply in got.split(";"):
                fields = reply.split()
                if fields[0] != "-":
                    check(int(fields[0], 16))
                replies.append(int(fields[1], 16) if len(fields) > 1 else None)
        return replies

    def select(self):
        if self.ops(["h %x" % self.half])[0] != 1:
            raise exceptions.ProbeError(
                "SWDIO is low with nobody driving it: power Pico B and fit its pull-up")
        self.ops(["a", "l", "t %x" % self.target])

    def connect(self, protocol=None):
        if protocol not in (None, DebugProbe.Protocol.DEFAULT, DebugProbe.Protocol.SWD):
            raise exceptions.ProbeError("SWD only")
        self.select()
        self.connected = True

    def disconnect(self):
        self.connected = False

    def set_clock(self, frequency):
        half = half_for(frequency)
        if half != self.half:
            self.half = half
            if self.connected:
                self.select()

    def assert_reset(self, asserted):
        if asserted:
            raise exceptions.ProbeError("nRESET is not wired: connect with -M attach")

    def is_reset_asserted(self):
        return False

    def reset(self):
        self.assert_reset(True)

    def read_dp(self, addr, now=True):
        value = self.ops(["r 0 %x" % (addr & 0xC)])[0]
        return value if now else (lambda: value)

    def write_dp(self, addr, data):
        self.ops(["w 0 %x %x" % (addr & 0xC, data)])

    def read_ap(self, addr, now=True):
        value = self.read_ap_multiple(addr, 1)[0]
        return value if now else (lambda: value)

    def write_ap(self, addr, data):
        self.write_ap_multiple(addr, [data])

    def read_ap_multiple(self, addr, count=1, now=True):
        """AP reads are posted, so each returns the one before and RDBUFF the last."""
        ops = ["r 1 %x" % (addr & 0xC)] * count + ["r 0 %x" % RDBUFF]
        values = self.ops(ops)[1:]
        return values if now else (lambda: values)

    def write_ap_multiple(self, addr, values):
        self.ops(["w 1 %x %x" % (addr & 0xC, v) for v in values])


def stopped(signum, frame):
    raise KeyboardInterrupt


def serve(probe, port):
    """Until Ctrl-C or SIGTERM: a shell's background job ignores SIGINT."""
    signal.signal(signal.SIGTERM, stopped)
    session = Session(probe=None, serve_local_only=True)
    server = DebugProbeServer(session, probe, port, serve_local_only=True)
    server.start()
    print("serving on localhost:%d: pyocd commander -u remote:localhost:%d -t cortex_m -M attach"
          % (server.port, server.port), flush=True)
    try:
        while server.is_running:
            time.sleep(0.2)
    except KeyboardInterrupt:
        pass
    finally:
        server.stop()
        if probe.is_open:
            probe.close()
        print("%d SWD transfers on %d bridge lines" % (probe.transfers, probe.lines),
              file=sys.stderr)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--pico", default=os.environ.get("PICO"), help="id:<serial of Pico A>")
    parser.add_argument("--port", type=int, default=5555)
    parser.add_argument("--core", type=int, choices=[0, 1], default=0)
    args = parser.parse_args()
    if not args.pico:
        parser.error("set PICO or --pico")
    link = SerialLink(args.pico)
    link.install()
    serve(Probe(link, args.core), args.port)


if __name__ == "__main__":
    main()
