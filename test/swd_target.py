# SPDX-License-Identifier: Apache-2.0
"""An RP2040's SWD port as ADIv5.2 (ARM IHI 0031G) has it, for the cocotb tests: SW-DPs of
SWD protocol version 2 on one multi-drop line, pulled up. Each is dormant from power-on
(B5.3), selected by a line reset and kept or let go by the TARGETSEL write straight after
it (B4.3.4), answers ACK OK, WAIT or FAULT (B4.2), and samples SWDIO and moves it on the
rise of SWCLK. Behind each is a MEM-AP whose accesses keep it busy for ap_latency clocks.
It is the same model as Swd.Dp in test/swd.ml, written again for Python."""

ALERT = 0x19BC0EA2E3DDAFE986852D956209F392
# Table B5-2, the SW-DP activation code, MSB first
SWD_ACTIVATION = [0, 1, 0, 1, 1, 0, 0, 0]
CORE0 = 0x01002927
CORE1 = 0x11002927
DPIDR = 0x0BC12477
# the IDR of an Arm AHB MEM-AP: designer 0x23b (Arm), class 8 (MEM-AP), type 1
AP_IDR = 0x04770031
OK, WAIT, FAULT = 1, 2, 4
# SWCLK high and low, and the host's setup and hold: half of a 24 MHz SWCLK, the most the
# RP2040 datasheet recommends
MINIMUM_PS = 21_000


def parity(value):
    return bin(value).count("1") & 1


class Dp:
    """One SW-DP and its MEM-AP, busy ap_latency clocks after each access. corrupt_acks
    garbles that many OK ACKs, the DP going on as if the host had seen OK."""

    def __init__(self, targetid, dpidr=DPIDR, ap_latency=0, memory=None, corrupt_acks=0,
                 cycle_ps=20834):
        self.targetid = targetid
        self.dpidr = dpidr
        self.ap_latency = ap_latency
        self.memory = dict(memory or {})
        self.corrupt_acks = corrupt_acks
        self.cycle_ps = cycle_ps
        self.dormant = True
        self.seen = []
        self.after_alert = None
        self.selected = False
        self.in_reset = False
        self.may_select = False
        self.high = 0
        self.idle_after_high = 0
        self.bits = None
        self.actions = []
        self.sampled = []
        self.request = 0
        self.drive = None
        self.ctrl_stat = 0
        self.select = 0
        self.sticky_err = False
        self.wdata_err = False
        self.tar = 0
        self.rdbuff = 0
        self.busy = 0
        self.now = 0
        self.swclk = 1
        self.line = 1
        self.rose = self.fell = self.moved = None
        self.held = True
        self.took = False
        self.shortest = {}
        self.log = []
        self.violations = []

    def timed(self, name, since):
        if since is None:
            return
        ps = (self.now - since) * self.cycle_ps
        self.shortest[name] = min(ps, self.shortest.get(name, ps))
        if ps < MINIMUM_PS:
            self.violations.append("%s of %d ps" % (name, ps))

    def wake(self, b):
        """The selection alert, four cycles ignored, then the activation code (B5.3.4)."""
        if self.after_alert is None:
            self.seen = (self.seen + [b])[-128:]
            if self.seen == [(ALERT >> i) & 1 for i in range(128)]:
                self.after_alert = []
            return
        self.after_alert.append(b)
        if len(self.after_alert) == 12:
            if self.after_alert[4:] == SWD_ACTIVATION:
                self.dormant = False
                self.selected = False
                self.log.append("dormant to SWD")
            self.after_alert = None
            self.seen = []

    def line_reset(self, b):
        """50 cycles high and two idle (B4.3.3), seen while the DP does not drive."""
        if self.drive is not None:
            return
        if b:
            self.high = 1 if self.idle_after_high else self.high + 1
            self.idle_after_high = 0
        elif self.high < 50:
            self.high = self.idle_after_high = 0
        elif not self.idle_after_high:
            self.idle_after_high = 1
        else:
            self.high = self.idle_after_high = 0
            self.bits = None
            self.actions = []
            self.selected = self.in_reset = self.may_select = True
            self.log.append("line reset")

    def ctrl(self):
        req = self.ctrl_stat & 0x50000000
        return req | (req << 1) | (self.wdata_err << 7) | (self.sticky_err << 5)

    def ap_read(self, address):
        bank = (self.select >> 4) & 0xF
        if bank == 0xF and address == 0xC:
            return AP_IDR
        if bank == 0 and address == 0x4:
            return self.tar
        if bank == 0 and address == 0xC:
            if self.tar in self.memory:
                return self.memory[self.tar]
            self.sticky_err = True
        return 0

    def respond(self, ap, read, address):
        name = "%s %s 0x%x" % ("R" if read else "W", "AP" if ap else "DP", address)
        # B4.2.3, B4.2.4: never to a DPIDR or CTRL/STAT read, nor to an ABORT write
        may_refuse = ap or (read and address > 4) or (not read and address != 0)
        busy = self.busy and (ap or (read and address == 0xC))
        sticky = self.sticky_err or self.wdata_err
        ack = FAULT if may_refuse and sticky else WAIT if may_refuse and busy else OK
        if read and not ap and address == 0:
            self.in_reset = False
        sent = ack
        if ack == OK and self.corrupt_acks:
            self.corrupt_acks -= 1
            sent = 0b101
        acks = [("drive", (sent >> i) & 1) for i in range(3)]
        if ack != OK:
            self.log.append("%s %s" % (name, "WAIT" if ack == WAIT else "FAULT"))
            return acks + [("release", None), ("skip", None)]
        if not read:
            return acks + [("release", None), ("skip", None)] + [("sample", None)] * 33
        if ap:
            value = self.rdbuff
            self.rdbuff = self.ap_read(address)
            self.busy = self.ap_latency
        elif address == 0:
            value = self.dpidr
        elif address == 4:
            value = {0: self.ctrl(), 2: self.targetid & 0x0FFFFFFF,
                     3: (self.targetid & 0xF0000000) | 1}.get(self.select & 0xF, 0)
        elif address == 0xC:
            value = self.rdbuff
        else:
            value = 0
        self.log.append("%s OK 0x%08x%s" % (name, value, "" if sent == OK else ", ACK garbled"))
        data = [("drive", (value >> i) & 1) for i in range(32)]
        return acks + data + [("drive", parity(value)), ("release", None), ("skip", None)]

    def decode(self):
        request = sum(b << i for i, b in enumerate(self.bits))
        self.bits = None
        ap, read, address = (request >> 1) & 1, (request >> 2) & 1, ((request >> 3) & 3) << 2
        fine = parity((request >> 1) & 0xF) == (request >> 5) & 1 and not (request >> 6) & 1 \
            and (request >> 7) & 1
        may_select, self.may_select = self.may_select, False
        if not fine:
            # a line reset's ones look like a request too
            if request != 0xFF:
                self.log.append("protocol error")
            self.selected = False
        elif not ap and not read and address == 0xC:
            if not may_select:
                self.violations.append("TARGETSEL not straight after a line reset")
            # five cycles not driven (B4.3.4), then WDATA and parity
            self.request = request
            self.actions = [("skip", None)] * 5 + [("sample", None)] * 33
        elif self.in_reset and not (read and not ap and address == 0):
            self.violations.append("request 0x%02x in the reset state" % request)
            self.selected = False
        else:
            self.request = request
            self.actions = self.respond(ap, read, address)

    def complete(self):
        """WDATA the host drove every bit of, or none of, which is a host backing off."""
        driven = sum(d for _, d in self.sampled)
        bits = [b for b, _ in self.sampled]
        value = sum(b << i for i, b in enumerate(bits[:32]))
        good = parity(value) == bits[32]
        ap, address = (self.request >> 1) & 1, ((self.request >> 3) & 3) << 2
        name = "W %s 0x%x" % ("AP" if ap else "DP", address)
        if driven == 0:
            self.log.append(name + " with no WDATA")
            return
        if driven < len(bits):
            self.violations.append(name + ", WDATA part undriven")
            return
        if not ap and address == 0xC:
            self.selected = good and value == self.targetid
            self.log.append("TARGETSEL 0x%08x: %s" % (
                value, "selected" if self.selected else "deselected"))
            return
        self.log.append("%s OK 0x%08x" % (name, value))
        if not good:
            self.wdata_err = True
        elif ap:
            self.busy = self.ap_latency
            if (self.select >> 4) & 0xF == 0 and address == 0x4:
                self.tar = value
            elif (self.select >> 4) & 0xF == 0 and address == 0xC:
                if self.tar in self.memory:
                    self.memory[self.tar] = value
                else:
                    self.sticky_err = True
        elif address == 0:
            # MINDP: STKCMPCLR is SBZ (B1.2)
            if value & 2 and self.dpidr & (1 << 16):
                self.violations.append("STKCMPCLR written to a MINDP DP")
            self.sticky_err = self.sticky_err and not value & 4
            self.wdata_err = self.wdata_err and not value & 8
        elif address == 4 and self.select & 0xF == 0:
            self.ctrl_stat = value
        elif address == 8:
            self.select = value

    def host_bit(self, host):
        if host is None:
            self.violations.append("a bit taken from the host while it does not drive")
        else:
            self.timed("setup", self.moved)
            self.took = True

    def rise(self, b, host):
        self.timed("SWCLK low", self.fell)
        self.took = False
        if self.dormant:
            self.wake(b)
            return
        self.line_reset(b)
        self.busy = max(0, self.busy - 1)
        if not self.selected:
            return
        if self.actions:
            action, level = self.actions.pop(0)
            if action == "drive":
                self.drive = level
            elif action == "release":
                self.drive = None
            elif action == "sample":
                if host is not None:
                    self.timed("setup", self.moved)
                    self.took = True
                self.sampled.append((b, host is not None))
                if not self.actions:
                    self.complete()
                    self.sampled = []
        elif self.bits is not None:
            self.host_bit(host)
            self.bits.append(b)
            if len(self.bits) == 8:
                self.decode()
        elif b:
            self.host_bit(host)
            self.bits = [1]

    def step(self, swclk, host, line):
        """One cycle: [host] is the level the host drives, None if it does not, [line] what
        everyone sees."""
        if host is not None and self.drive is not None:
            self.violations.append("contention: host and target both drive")
        if line != self.line and host is not None:
            # hold counts only after a rise that took a bit from the host
            if not self.held:
                self.held = True
                self.timed("hold", self.rose)
            self.moved = self.now
        self.line = line
        if swclk and not self.swclk:
            self.rise(line, host)
            self.rose = self.now
            self.held = not self.took
        elif not swclk and self.swclk:
            self.timed("SWCLK high", self.rose)
            self.fell = self.now
        self.swclk = swclk
        self.now += 1


class Bus:
    """The host's pins and the RP2040's two core DPs on one line, at undriven when nobody
    drives it: 1 for a pull-up."""

    def __init__(self, dps=None, undriven=1):
        self.dps = dps or [Dp(CORE0), Dp(CORE1)]
        self.undriven = undriven
        self.host = None
        self.contention = 0

    def line(self):
        if self.host is not None:
            return self.host
        drives = [dp.drive for dp in self.dps if dp.drive is not None]
        return drives[0] if drives else self.undriven

    def step(self, swclk, host):
        self.host = host
        line = self.line()
        if sum(dp.drive is not None for dp in self.dps) > 1:
            self.contention += 1
        for dp in self.dps:
            dp.step(swclk, host, line)
        return self.line()
