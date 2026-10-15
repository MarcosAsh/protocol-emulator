# SPDX-License-Identifier: Apache-2.0
# Pico B's SWD port for a debugger on the laptop (MicroPython, Pico A), wired as demo_swd.py
# says: every edge comes from the chip's SWD firmware, through demo_swd's Swd. A line of
# ops in, a line of replies out, ASCII so Ctrl-C still reaches the REPL. demo/swd_probe.py
# speaks it.
#
# Ops, separated by ";", fields hex:
#   h HALF       load the SWD firmware at that half period: SWDIO's level let go
#   a            selection alert and SW-DP activation
#   l            line reset
#   t TARGET     TARGETSEL
#   r AP A       read: the status (ACK, 8 for a parity error) and RDATA
#   w AP A V     write: the status
#   x            let both lines go and stop serving
# A transfer WAITed is retried, as many as demo_swd.POLLS times. The ops after one that ends
# other than OK are not run, so the reply is shorter than the request.

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
        """The replies to one line of ops, and whether to go on serving."""
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
