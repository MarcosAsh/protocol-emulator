# SPDX-License-Identifier: Apache-2.0
"""demo/traffic.py on made captures, decoded by sigrok-cli with demo/outside.sh's arguments:
the CAN bus Pico B never answered, which Pico A passed on 2026-10-10, must fail."""

import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "demo"))
import ledger  # noqa: E402
import sigrok  # noqa: E402
import traffic  # noqa: E402

RATE = 12_000_000
# 500 kbit/s at the analyser's rate
BIT = RATE // 500_000
# what demo_can logs on a run the chip finished without a fault
CAN_LOG = """armed: OUT1 is recessive
sent id 0x123 dlc 2 de ad
sent id 0x555 dlc 8 00 ff 55 aa 01 80 7f fe
sent id 0x7ef dlc 0
sent id 0x000 dlc 1 01
faults 0x0
PASS
"""


def can_bits(ident, rtr, dlc, data, acked=True):
    """A standard frame on the bus, stuffed, to the end of its intermission."""
    fields = [0] + traffic.bits(ident, 11) + [rtr, 0, 0] + traffic.bits(dlc, 4)
    fields += sum((traffic.bits(b, 8) for b in data), [])
    fields += traffic.bits(traffic.crc15(fields), 15)
    out, run = [], 0
    for bit in fields:
        run = run + 1 if out and bit == out[-1] else 1
        out.append(bit)
        if run == 5:
            out.append(1 - bit)
            run = 1
    return out + [1, 0 if acked else 1, 1] + [1] * 10


def capture(path, levels, channel=5):
    """levels a bit on one channel, the others high."""
    rest = 0xFF & ~(1 << channel)
    sigrok.write(path, RATE, b"".join(bytes([rest | (b << channel)]) * BIT for b in levels))


def decoders():
    text = (ROOT / "demo/outside.sh").read_text()
    return dict(re.findall(r"^(\w+)\)\n\s+ms=\d+\n\s+decode=\"([^\"]*)\"", text, re.M))


@unittest.skipUnless(shutil.which("sigrok-cli"), "needs sigrok-cli")
class Can(unittest.TestCase):
    def setUp(self):
        self.dir = Path(tempfile.mkdtemp())

    def tearDown(self):
        shutil.rmtree(self.dir)

    def run_demo(self, demo, levels, log=CAN_LOG):
        capture(self.dir / (demo + ".sr"), levels)
        (self.dir / (demo + ".log")).write_text(log)
        with open(self.dir / (demo + ".decode"), "w") as f:
            subprocess.run(["sigrok-cli", "-i", str(self.dir / (demo + ".sr")),
                            *decoders()[demo].split()], stdout=f, check=True)
        return traffic.check(demo, self.dir)

    def frames(self, frames, **kw):
        return [1] * 20 + sum((can_bits(*f, **kw) + [1] * 20 for f in frames), []) + [1] * 40

    def test_stuck_dominant(self):
        """Pico B in MicroPython: nothing on the bus, D5 low throughout, and sigrok reads a
        frame of zeros after another. Pico A still says PASS."""
        problems = self.run_demo("can", [0] * 50_000)
        self.assertEqual(problems, ["D5 (CAN R, low is dominant) never changes in the capture: "
                                    "low throughout"])
        self.assertIn("Identifier: 0 (0x0)", (self.dir / "can.decode").read_text())
        self.assertEqual(ledger.last_verdict(CAN_LOG), "PASS")
        out = subprocess.run([sys.executable, str(ROOT / "demo/traffic.py"), "can", str(self.dir)],
                             capture_output=True, text=True, check=True).stdout
        self.assertEqual(ledger.last_verdict(out), "FAIL")
        self.assertIn("traffic: D5 (CAN R, low is dominant) never changes", out)

    def test_can(self):
        frames = [(i, 0, len(d), d) for i, d in traffic.demo_can.FRAMES]
        self.assertEqual(self.run_demo("can", self.frames(frames)), [])

    def test_can_node(self):
        """Pico B's remote frame too, as sigrok misreads it."""
        node = traffic.demo_can_node
        frames = [(i, 0, len(d), d) for i, d in node.FRAMES] + node.REPLIES
        self.assertEqual(self.run_demo("can_node", self.frames(frames), log="PASS\n"), [])

    def test_nobody_acks(self):
        frames = [(i, 0, len(d), d) for i, d in traffic.demo_can.FRAMES]
        problems = self.run_demo("can", self.frames(frames, acked=False))
        self.assertEqual(problems, ["4 frames, each ACKed: decode line 6 reads "
                                    "'can-1: ACK slot: NACK', expected 'can-1: ACK slot: ACK'"])

    def test_a_frame_missing(self):
        frames = [(i, 0, len(d), d) for i, d in traffic.demo_can.FRAMES][:3]
        problems = self.run_demo("can", self.frames(frames))
        self.assertEqual(problems, ["4 frames, each ACKed: the decode has 22 lines, expected 27"])

    def test_dominant_at_the_end(self):
        frames = [(i, 0, len(d), d) for i, d in traffic.demo_can.FRAMES]
        problems = self.run_demo("can", self.frames(frames) + [0] * 40)
        self.assertEqual(problems[0], "D5 (CAN R) is dominant at the capture's end: the bus does "
                                      "not idle recessive")


class Decodes(unittest.TestCase):
    """The checks of the other demos, on decodes as sigrok prints them and a capture whose
    channels all move."""

    def setUp(self):
        self.dir = Path(tempfile.mkdtemp())

    def tearDown(self):
        shutil.rmtree(self.dir)

    def check(self, demo, decoded, log="PASS\n", edges=1):
        name = traffic.stem(demo)
        sigrok.write(self.dir / (name + ".sr"), RATE, bytes([0, 0xFF] * edges) + b"\x00")
        (self.dir / (name + ".decode")).write_text("".join(d + "\n" for d in decoded))
        (self.dir / (name + ".log")).write_text(log)
        return traffic.check(demo, self.dir)

    def test_no_check(self):
        self.assertEqual(traffic.check("smoke", self.dir), [])

    def test_no_capture(self):
        self.assertEqual(traffic.check("neopixel", self.dir),
                         ["no capture %s" % (self.dir / "neopixel.sr")])

    def test_a_line_never_moves(self):
        sigrok.write(self.dir / "neopixel.sr", RATE, bytes([0x10]) * 1000)
        self.assertEqual(traffic.check("neopixel", self.dir),
                         ["D4 (NEO_3V3) never changes in the capture: high throughout"])

    def test_neopixel(self):
        p = traffic.demo_neopixel.PIXELS
        good = traffic.stick([p, p[1:] + p[:1]])
        self.assertEqual(self.check("neopixel", good), [])
        self.assertEqual(self.check("neopixel", good[:9]),
                         ["two frames: the decode has 9 lines, expected 18"])

    def test_referee(self):
        decoded = traffic.stick([traffic.demo_referee.score(n) for n in range(1, 8)]
                                + traffic.demo_referee.sweep()
                                + [traffic.demo_referee.score(n) for n in (7, 8)])
        self.assertEqual(len(decoded), 153)
        self.assertEqual(self.check("referee", decoded), [])

    def test_eeprom(self):
        log = ("byte write 0x7fbf: 00 -> 01, 3 NACKs over 5 ms, read back 01\n"
               "page write 0x7fc0, 64 bytes from 01: 2 NACKs over 5 ms, read back ...\nPASS\n")
        page = " ".join("%02X" % ((1 + 13 * i) & 0xFF) for i in range(64))
        decoded = ["eeprom24xx-1: " + x for x in [
            "Warning: Slave replied, but master aborted!",
            "Sequential random read (addr=7FBF, 1 byte): 00", "Page write (addr=7FBF, 1 byte): 01",
            "Warning: No reply from slave!", "Sequential random read (addr=7FBF, 1 byte): 01",
            "Sequential random read (addr=7FC0, 1 byte): 00",
            "Page write (addr=7FC0, 64 bytes): " + page,
            "Sequential random read (addr=7FC0, 64 bytes): " + page]]
        self.assertEqual(self.check("eeprom_stretch", decoded, log), [])
        # SDA with no pull-up reads back zeros, which the decode shows
        stuck = decoded[:-1] + [decoded[-1][:-len(page)] + " ".join(["00"] * 64)]
        self.assertEqual(len(self.check("eeprom", stuck, log)), 1)
        self.assertEqual(self.check("eeprom", decoded, "FAIL\n"), [
            "Pico A's log has no byte write and page write to hold the decode to"])

    def test_ds18b20(self):
        """No analyser channel has DQ: Pico A's readback is checked again, and a flat
        capture on analyser B's D5 counts for nothing."""
        log = ("ROM 28 7d 50 63 79 25 0b 3e: family 28, CRC good\n"
               "scratchpad 68 01 4b 46 7f ff 0c 10 3e: CRC good, configuration 7f, "
               "360/16 = 22.5000 C\nPASS\n")
        sigrok.write(self.dir / "ds18b20.sr", RATE, bytes([0xA0]) * 1000)
        (self.dir / "ds18b20.log").write_text(log)
        self.assertEqual(traffic.check("ds18b20", self.dir), [])
        (self.dir / "ds18b20.log").write_text(log.replace("0c 10 3e", "0c 10 3f"))
        self.assertEqual(traffic.check("ds18b20", self.dir), [
            "scratchpad 68 01 4b 46 7f ff 0c 10 3f: bad CRC or configuration"])
        # the power-on 85 C, with its own good CRC
        pad = [0x50, 0x05, 0x4B, 0x46, 0x7F, 0xFF, 0x0C, 0x10]
        pad = " ".join("%02x" % b for b in pad + [traffic.demo_ds18b20.crc8(pad)])
        (self.dir / "ds18b20.log").write_text(log.replace("68 01 4b 46 7f ff 0c 10 3e", pad))
        self.assertEqual(traffic.check("ds18b20", self.dir), [
            "scratchpad reads 85.0000 C, the power-on value or out of range"])
        (self.dir / "ds18b20.log").write_text("no presence pulse\nFAIL\n")
        self.assertEqual(traffic.check("ds18b20", self.dir),
                         ["Pico A's log has no ROM and scratchpad read back"])

    def test_swd(self):
        log = "AP 0 IDR 0x04770031: designer 0x23b, class 8, a MEM-AP\nPASS\n"
        read = ["swd-1: IDCODE", "swd-1: OK", "swd-1: 0x0bc12477"]
        ap = ["swd-1: RDBUFF", "swd-1: OK", "swd-1: 0x04770031"]
        self.assertEqual(self.check("swd", read + ap + ["swd-1: LINERESET"] + read, log), [])
        self.assertEqual(self.check("swd", read + ap, log),
                         ["DPIDR 0x0bc12477 read OK 1 times, expected one a core"])

    def test_start_hold(self):
        log = "chip, engine 1: 64 STARTs, SDA fall to SCL fall, 48 MHz cycles\n"
        starts = ["i2c-1: Start", "i2c-1: Start repeat"] * 40
        self.assertEqual(self.check("start_hold_pio", starts, log), [])
        self.assertEqual(self.check("start_hold_hw", starts[:63], log),
                         ["the decode has 63 STARTs, fewer than the 64 the chip stamped"])

    def test_self_timing(self):
        log = "'J' 0x4a       0 10000\n'!' 0x21       0  5000\n'J' 0x4a  0\n'!' 0x21  0\nPASS\n"
        self.assertEqual(self.check("self_timing", ["uart-1: 4A", "uart-1: 21"] * 2, log), [])
        self.assertEqual(len(self.check("self_timing", ["uart-1: 4A", "uart-1: 21"], log)), 1)

    def test_keyboard(self):
        log = "typed h\r\ntyped i\r\n"
        self.assertEqual(self.check("keyboard", ["uart-1: 68", "uart-1: 69"], log), [])
        self.assertEqual(self.check("keyboard", [], log),
                         ["the keys typed: the decode has 0 lines, expected 2"])

    def test_sweep(self):
        log = ("uart_tx            line      28     28       0    0  0 0     PASS\n"
               "jtag               tdi       10     10       0    0  0 0     PASS\n")
        self.assertEqual(self.check("sweep", [], log, edges=19), [])
        self.assertEqual(self.check("sweep", [], log, edges=18),
                         ["D4 (OUT0) has 36 edges, fewer than the 38 the chip stamped"])


if __name__ == "__main__":
    unittest.main()
