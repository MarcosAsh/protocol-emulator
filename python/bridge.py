# SPDX-License-Identifier: Apache-2.0
# Pico B's SWD port for a debugger on the laptop (MicroPython, Pico A), wired as in
# demo_swd.py. Every edge comes from the chip's SWD firmware via demo_swd's Swd. It reads
# a line of ops and prints a line of replies, in ASCII so Ctrl-C still reaches the REPL.
# demo/swd_probe.py is the client.
#
# Ops, separated by ";", fields hex:
#   h HALF       load the SWD firmware with that half period, and release SWDIO
#   a            selection alert and SW-DP activation
#   l            line reset
#   t TARGET     TARGETSEL
#   r AP A       read: the status (ACK, 8 for a parity error) and RDATA
#   w AP A V     write: the status
#   x            let both lines go and stop serving
# A transfer that gets WAIT is retried up to demo_swd.POLLS times. Ops after one that
# doesn't end OK are skipped, so the reply can be shorter than the request.

import bench
import bench_firmware
import demo_swd
import protocol_emulator as pe


class Bridge:
    def __init__(self, host, swd):
        self.host = host
        self.swd = swd

    def start(self, half):
        bench.load(self.host, bench_firmware.SWD)
        self.host.start()
        return self.swd.send([half], 1)[0] & 1

    def transfer(self, ap, address, value=None):
        for _ in range(demo_swd.POLLS):
            if value is None:
                ack, data, good = self.swd.read(ap, address)
                status = ack | (0 if good else 8)
            else:
                status, data = self.swd.write(ap, address, value), None
            if status != demo_swd.WAIT:
                return status, data
        return status, data

    def handle(self, line):
        """Run one line of ops. Returns the reply and whether to keep serving."""
        replies = []
        for op in line.split(";"):
            fields = op.split()
            if not fields:
                continue
            name, args = fields[0], [int(f, 16) for f in fields[1:]]
            if name == "h":
                replies.append("- %x" % self.start(*args))
            elif name == "a":
                self.swd.wake()
                replies.append("-")
            elif name == "l":
                self.swd.line_reset()
                replies.append("-")
            elif name == "t":
                self.swd.targetsel(*args)
                replies.append("-")
            elif name in "rw":
                status, data = self.transfer(*args)
                replies.append("%x" % status if data is None else "%x %x" % (status, data))
                if status != demo_swd.OK:
                    break
            elif name == "x":
                demo_swd.let_go(self.host)
                replies.append("-")
                return ";".join(replies), False
            else:
                replies.append("?")
                break
        return ";".join(replies), True


def main():
    import sys

    import pico_board

    host = pe.Host(pico_board.PicoSpi().transfer)
    bridge = Bridge(host, demo_swd.Swd(host))
    print("bridge")
    serving = True
    try:
        while serving:
            line = sys.stdin.readline()
            if not line:
                break
            try:
                reply, serving = bridge.handle(line.strip())
            except Exception as e:
                reply = "! %s" % e
            print(reply)
    finally:
        demo_swd.let_go(host)
