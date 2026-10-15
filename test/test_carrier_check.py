# SPDX-License-Identifier: Apache-2.0
"""demo/carrier_check.py against a model of the carrier built from demo/carrier_netlist.csv:
carrier_check.v as its frames describe it, the resistors, both Picos' pins, the CAN boards,
the EEPROM, the DS18B20, the flash and Pico B's SWD port (test/swd_target.py). A whole
carrier passes, and each fault fails the nets it touches and no others."""

import heapq
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "demo"))
sys.path.insert(0, str(ROOT / "python"))
sys.path.insert(0, str(ROOT / "test"))
import carrier_check  # noqa: E402
import swd_target  # noqa: E402
from carrier_pins import HEADER, PIN, Pins, decode  # noqa: E402

# bom.csv's values; R1 is the CAN terminator, left to the boards' model
OHMS = {"R2": 10e3, "R3": 10e3, "R4": 330, "R5": 2200, "R6": 2200, "R7": 4700, "R8": 1e3,
        "R9": 1e3, "R10": 1e3, "R11": 220, "R12": 220, "R13": 4700, "R14": 47, "R15": 47,
        "R16": 470, "R17": 1e3, "R18": 1e3, "R19": 1e3}
# a pin driving, a pad's or Pico's pull, a CAN transceiver's own pull-up on D
DRIVE, PULL, D_PULL = 30, 50e3, 100e3
ROM = [0x28, 0x7D, 0x50, 0x63, 0x79, 0x25, 0x0B, 0x3E]
JEDEC = [0xEF, 0x40, 0x17]


class Flash:
    """A W25Q64's JEDEC ID in mode 0, and nothing else."""

    def __init__(self, carrier):
        self.c = carrier
        self.clk = 0
        self.bits, self.queue, self.do = [], [], None

    def update(self, level):
        cs, clk, di = level("U4.1"), level("U4.6"), level("U4.5")
        before = self.do
        if cs:
            self.bits, self.queue, self.do = [], [], None
        elif clk and not self.clk:
            self.bits.append(di)
            if len(self.bits) == 8 and int("".join(map(str, self.bits)), 2) == 0x9F:
                self.queue = [(b >> (7 - i)) & 1 for b in JEDEC for i in range(8)]
        elif not clk and self.clk and self.queue:
            self.do = self.queue.pop(0)
        self.clk = clk
        return self.do != before

    def drives(self):
        return {"U4.2": self.do} if self.do is not None else {}


class Eeprom:
    """A 24LC256 at 0x50 that ACKs its address and ignores the rest."""

    def __init__(self, carrier, address=0x50):
        self.c, self.address = carrier, address
        self.scl = self.sda = 1
        self.bits, self.ack, self.listening = None, False, False

    def update(self, level):
        scl, sda = level("J10.3"), level("J10.4")
        before = self.ack
        if scl and self.scl and sda != self.sda:
            # START, or STOP
            self.bits, self.ack, self.listening = ([], False, True) if not sda else (None, False,
                                                                                    False)
        elif scl and not self.scl and self.listening and self.bits is not None:
            self.bits.append(sda)
        elif not scl and self.scl:
            if self.ack:
                self.ack, self.listening = False, False
            elif self.bits is not None and len(self.bits) == 8:
                self.ack = int("".join(map(str, self.bits[:7])), 2) == self.address
                self.listening = self.ack
                self.bits = None
        self.scl, self.sda = scl, sda
        return self.ack != before

    def drives(self):
        return {"J10.4": 0} if self.ack else {}


class Ds18b20:
    """The slots carrier_check.v times: a reset and presence, READ ROM and its bits."""

    def __init__(self):
        self.state, self.bits = "idle", []

    def slot(self, length, sample):
        """What the part drives at sample, us from the slot's fall."""
        if length >= 480:
            self.state, self.bits = "command", []
            return 0 if length + 15 <= sample <= length + 120 else None
        if self.state == "command":
            self.bits.append(1 if length < 15 else 0)
            if len(self.bits) == 8:
                byte = sum(b << i for i, b in enumerate(self.bits))
                self.state = "rom" if byte == 0x33 else "idle"
                self.bits = [(b >> i) & 1 for b in ROM for i in range(8)]
            return None
        if self.state == "rom" and self.bits:
            return 0 if self.bits.pop(0) == 0 and sample < 30 else None
        return None


class Swd:
    """Pico B's two cores on the far end of J8's cable."""

    def __init__(self, carrier):
        self.c = carrier
        dps = [swd_target.Dp(t, cycle_ps=10**9) for t in (swd_target.CORE0, swd_target.CORE1)]
        self.bus = swd_target.Bus(dps)
        self.drive = None

    def update(self, level):
        host = None
        if self.c.fpga_drives(36) and "R12" not in self.c.removed:
            host = self.c.fpga_level(36)
        self.bus.step(level("J8.1"), host)
        drives = [dp.drive for dp in self.bus.dps if dp.drive is not None]
        before, self.drive = self.drive, drives[0] if drives else None
        return self.drive != before

    def drives(self):
        return {"J8.3": self.drive} if self.drive is not None else {}


class Carrier:
    """The board, its parts in removed left out, the pad pairs in swapped on each other's
    nets, the net pairs in shorted one net, and the analyser probe pairs in crossed."""

    def __init__(self, removed=(), swapped=(), shorted=(), crossed=(), bitstream=True):
        nets, _ = carrier_check.netlist()
        self.pad = {p: n for n, ps in nets.items() for p in ps}
        for a, b in swapped:
            self.pad[a], self.pad[b] = self.pad[b], self.pad[a]
        for a, b in shorted:
            self.pad = {p: a if n == b else n for p, n in self.pad.items()}
        self.removed = set(removed)
        self.probe = {}
        for a, b in crossed:
            self.probe[a], self.probe[b] = b, a
        self.bitstream = bitstream
        self.oe = self.out = sum(1 << PIN[h] for h in (10, 28))
        self.slot_drive = None
        self.sample = None
        self.gpio = {"A": {}, "B": {}}
        self.button = False
        self.host = {"J13.4": 0, "J13.5": 0, "J13.7": 1, "J1.21": 0}
        self.devices = []
        if "U4" not in self.removed:
            self.devices.append(Flash(self))
        if "J10" not in self.removed:
            self.devices.append(Eeprom(self))
        if "J8" not in self.removed:
            self.devices.append(Swd(self))
        self.ds18b20 = Ds18b20() if "U5" not in self.removed else None
        self.recording = None
        self.levels = {}
        self.settle()

    def fpga_drives(self, h):
        return self.slot_drive and self.slot_drive[0] == h or (self.oe >> PIN[h]) & 1

    def fpga_level(self, h):
        if self.slot_drive and self.slot_drive[0] == h:
            return self.slot_drive[1]
        return (self.out >> PIN[h]) & 1

    def can_boards(self, level):
        """Each board's R, and its D's own pull-up."""
        boards = [(b, j) for b, j in (("J4", "J5"), ("J6", "J7")) if b not in self.removed]
        local = {b: level(b + ".1") == 0 for b, _ in boards if level(b + ".4")}
        bus = any(d for b, j in boards if j not in self.removed for d in [local.get(b)])
        out = {}
        for b, j in boards:
            out[b + ".1"] = (1, D_PULL)
            if b in local:
                sees = local[b] or (j not in self.removed and bus)
                out[b + ".2"] = (0 if sees else 1, DRIVE)
        return out

    def sources(self, extra):
        found = [("3V3_A", 1, 0), ("3V3_B", 1, 0), ("5V_A", 1, 0), ("GND", 0, 0)]
        for h in HEADER:
            net = self.pad["J1.%d" % h]
            driven = self.fpga_drives(h)
            found.append((net, self.fpga_level(h) if driven else 0, DRIVE if driven else PULL))
        for side, pins in self.gpio.items():
            for gp, (mode, value) in pins.items():
                net = self.pad[carrier_check.pico_pad(side, gp)]
                if mode == "out":
                    found.append((net, value, DRIVE))
                elif value:
                    found.append((net, 1 if value == "up" else 0, PULL))
        # Pico A's SPI and carrier_check.v's MISO, toggled once a frame
        for pad, value in self.host.items():
            found.append((self.pad[pad], value, DRIVE))
        if self.button and "SW1" not in self.removed:
            found.append((self.pad["SW1.1"], 0, 1))
        for pad, (value, ohms) in extra.items():
            found.append((self.pad[pad], value, ohms))
        return found

    def resolve(self, extra):
        edges = {}
        for r, ohms in OHMS.items():
            if r not in self.removed:
                a, b = self.pad[r + ".1"], self.pad[r + ".2"]
                edges.setdefault(a, []).append((b, ohms))
                edges.setdefault(b, []).append((a, ohms))
        best = {0: {}, 1: {}}
        for value in (0, 1):
            heap = [(ohms, net) for net, v, ohms in self.sources(extra) if v == value]
            heapq.heapify(heap)
            while heap:
                ohms, net = heapq.heappop(heap)
                if net in best[value]:
                    continue
                best[value][net] = ohms
                for other, more in edges.get(net, []):
                    heapq.heappush(heap, (ohms + more, other))
        inf = float("inf")
        return {net: int(best[1].get(net, inf) < best[0].get(net, inf))
                for net in set(self.pad.values())}

    def settle(self, extra=None):
        for _ in range(20):
            drives = dict(extra or {})
            drives.update(self.can_boards(lambda p: self.levels.get(self.pad[p], 0)))
            for device in self.devices:
                drives.update({p: (v, DRIVE) for p, v in device.drives().items()})
            self.levels = self.resolve(drives)
            level = lambda p: self.levels[self.pad[p]]  # noqa: E731
            powered = level("U4.8")
            changed = [d.update(level) for d in self.devices if powered]
            if not any(changed) and self.can_boards(level) == {
                    k: v for k, v in drives.items() if k in ("J4.1", "J4.2", "J6.1", "J6.2")}:
                break
        if self.recording is not None:
            self.recording.append(sum(self.levels[self.pad[self.probe.get(p, p)]] << k
                                      for k, p in enumerate(self.analyser_pads)))

    def header(self):
        return sum(self.levels[self.pad["J1.%d" % h]] << PIN[h] for h in HEADER)

    def transfer(self, data):
        if not self.bitstream:
            return b"\xff" * len(data)
        sample = (2 | self.sample) if self.sample is not None else 0
        reply = b"pin" + self.header().to_bytes(3, "big") + bytes([sample]) + bytes(4)
        if self.recording is not None:
            self.host = {"J13.4": 1, "J13.5": 1, "J13.7": 0, "J1.21": 1}
            self.settle()
            self.host = {"J13.4": 0, "J13.5": 0, "J13.7": 1, "J1.21": 0}
        oe, out = int.from_bytes(data[0:3], "big"), int.from_bytes(data[3:6], "big")
        self.oe, self.out = oe & 0x1FFFFF, out & 0x1FFFFF
        self.settle()
        if data[6] & 0x40:
            h, level = HEADER[data[6] & 0x1F], data[6] >> 7
            length, at = int.from_bytes(data[7:9], "big"), int.from_bytes(data[9:11], "big")
            self.slot_drive = (h, level)
            self.settle()
            answer = None
            if self.ds18b20 and self.pad["J1.%d" % h] == self.pad["U5.2"] and not level:
                answer = self.ds18b20.slot(length, at)
            self.slot_drive = None
            if at < length:
                self.sample = level
            else:
                self.settle({"U5.2": (0, DRIVE)} if answer == 0 else None)
                self.sample = self.levels[self.pad["J1.%d" % h]]
            self.settle()
        assert decode(reply)[0] == b"pin"
        return reply

    def capture(self, analyser, action):
        header = carrier_check.ANALYSERS[analyser]
        self.analyser_pads = ["%s.%d" % (header, k + 1) for k in range(8)]
        self.recording = []
        action()
        samples, self.recording = bytes(self.recording), None
        return samples


class Gpio:
    """carrier_pins.Gpio on the model."""

    def __init__(self, carrier, side):
        self.c, self.side = carrier, side

    def drive(self, gp, level):
        self.c.gpio[self.side][gp] = ("out", level)
        self.c.settle()

    def let_go(self, gp, pull=None):
        # the RP2040's pads come out of reset pulled down
        self.c.gpio[self.side][gp] = ("in", pull)
        self.c.settle()

    def read(self, gp):
        return self.c.levels[self.c.pad[carrier_check.pico_pad(self.side, gp)]]

    def pressed(self, gp, ms):
        self.let_go(gp, "up")
        if ms and not self.c.button:
            self.c.button = True
            self.c.settle()
            low = not self.read(gp)
            self.c.button = False
            self.c.settle()
            return low
        return not self.read(gp)

    def i2c_scan(self, sda, scl):
        def line(gp, level):
            if level:
                self.let_go(gp)
            else:
                self.drive(gp, 0)

        found = []
        for address in range(0x08, 0x78):
            line(sda, 0)
            line(scl, 0)
            for i in range(8):
                line(sda, ((address << 1) >> (7 - i)) & 1)
                line(scl, 1)
                line(scl, 0)
            line(sda, 1)
            line(scl, 1)
            if not self.read(sda):
                found.append(address)
            line(scl, 0)
            line(sda, 0)
            line(scl, 1)
            line(sda, 1)
        return found


def check(carrier=None, button=True, analysers=False):
    """The run's verdict and its lines, each (status, nets)."""
    c = carrier or Carrier()
    said = []
    bench = carrier_check.Bench(Pins(c.transfer), Gpio(c, "A"), Gpio(c, "B"), c.capture,
                                said.append)
    for gp in (1, 2, 3, 6, 7):
        c.gpio["B"][gp] = ("in", "down")
    ok = carrier_check.run(bench, carrier_check.netlist()[0], button, analysers)
    return ok, said


def failed(said):
    """The nets of every FAIL line."""
    return {net for line in said if line.startswith("FAIL ")
            for net in line[5:].split(" [")[0].split()}


class CarrierCheck(unittest.TestCase):
    def test_whole(self):
        ok, said = check(analysers=True)
        self.assertTrue(ok, "\n".join(said))
        self.assertEqual(failed(said), set())
        self.assertIn("PASS DQ [J1.37 J3.6 R7.1 TP6.1 U5.2]: DS18B20 ROM 28 7d 50 63 79 25 0b "
                      "3e, CRC good", said)
        self.assertTrue(any("JEDEC ID ef 40 17: W25Q64JV" in line for line in said))
        self.assertTrue(any("core 0 answers DPIDR 0x0bc12477" in line for line in said))
        self.assertTrue(any("the EEPROM ACKs at 0x50" in line for line in said))
        self.assertEqual(said[-1], "PASS")
        skipped = [line.split(" [")[0] for line in said if line.startswith("SKIP")]
        self.assertEqual(skipped, ["SKIP NEO_3V3 NEO_5V NEO_DIN", "SKIP 5V_A LED_5V"])

    def test_no_flash(self):
        """The breakout left out: its SPI reads all zeros, a SKIP and not a FAIL."""
        ok, said = check(Carrier(removed={"U4"}))
        self.assertTrue(ok, "\n".join(said))
        self.assertTrue(any(line.startswith("SKIP FLASH_CLK") and "not fitted (JEDEC ID 00 00 "
                            "00)" in line for line in said))

    def assert_fails(self, carrier, nets, **kwargs):
        ok, said = check(carrier, **kwargs)
        self.assertFalse(ok)
        self.assertEqual(failed(said), set(nets), "\n".join(said))
        return said

    def test_no_bitstream(self):
        said = self.assert_fails(Carrier(bitstream=False),
                                 {"HOST_SCK", "HOST_MOSI", "HOST_MISO", "HOST_CS_N"})
        self.assertEqual(len(said), 2)

    def test_uart_resistor(self):
        self.assert_fails(Carrier(removed={"R8"}), {"UART_B", "UART_B_PICO"})

    def test_pico_b_i2c_crossed(self):
        """SDA and SCL crossed at Pico B: its lines and its scan fail, the header's do not."""
        self.assert_fails(Carrier(swapped=[("J15.4", "J15.5")]), {"I2C_SDA", "I2C_SCL", "3V3_A"})

    def test_dq_pull_up(self):
        said = self.assert_fails(Carrier(removed={"R7"}), {"DQ"})
        self.assertTrue(any("R7 4k7 to 3V3_A missing" in line for line in said))

    def test_can_bus(self):
        """Board B's jumpers off: both boards echo, the bus between them fails."""
        said = self.assert_fails(Carrier(removed={"J7"}), {"CANH", "CANL"})
        self.assertTrue(any("jumpers from J5 and J7" in line for line in said))

    def test_can_board_a(self):
        self.assert_fails(Carrier(removed={"J4"}), {"CAN_TX", "CANA_CTX", "CANA_CRX", "CAN_RX"})

    def test_short(self):
        said = self.assert_fails(Carrier(shorted=[("SPARE_IN2", "SPARE_IN3")]),
                                 {"SPARE_IN2", "SPARE_IN3"})
        self.assertTrue(any("driving header 7 to 1 moves header 11: a short" in line
                            for line in said))

    def test_swd_cable(self):
        self.assert_fails(Carrier(removed={"J8"}),
                          {"SWCLK", "SWCLK_PICO", "SWDIO", "SWDIO_PICO"})

    def test_replug(self):
        self.assert_fails(Carrier(removed={"SW1"}), {"REPLUG"})

    def test_probes_crossed(self):
        """Analyser B's D5 and D6 probes on each other's pins."""
        said = self.assert_fails(Carrier(crossed=[("J3.6", "J3.7")]), {"DQ", "I2C_SDA"},
                                 analysers=True)
        self.assertTrue(any("analyser B D5 sees 22 edges, I2C_SDA's 11 pulses, not DQ's 10" in line
                            for line in said), "\n".join(said))


if __name__ == "__main__":
    unittest.main()
