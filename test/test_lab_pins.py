# SPDX-License-Identifier: Apache-2.0
"""Derives from demo/carrier_netlist.csv which chip pins a remote lab job may drive, and
checks it against the list in src/remote_lab.ml (Pads.safety). A pad is safe when every
other part on its net only listens, or can drive it only through a series resistor, and
none of them keeps state a job could change. What each part's pin does is stated below;
the netlist says what connects to what."""

import csv
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RAILS = {"GND", "3V3_A", "3V3_B", "5V_A"}
# pads that only listen: the analysers, test points, the 74AHCT125's 1A, CAN board A's
# CTX, the RP2040 target's SWCLK
LISTEN = re.compile(r"J2\.\d+|J3\.\d+|TP\d+\.1|U3\.2|J4\.1|J8\.1")
# pads that can drive their net: every Pico GPIO, the flash's DO and DI (in dual and quad
# reads), the DS18B20, the I2C parts, CAN board A's CRX, the target's SWDIO, the Ethernet jack
DRIVE = re.compile(r"J1[3-6]\.\d+|U4\.[25]|U5\.2|J10\.[34]|J17\.[34]|J4\.2|J8\.3|J11\.\d+")
# parts that keep what they are sent: the flash, the EEPROM, the DS18B20, Pico B's debug
# port, and the network past the Ethernet jack
STATE = re.compile(r"U4\.\d+|J10\.\d+|J17\.\d+|U5\.\d+|J8\.3|J11\.\d+")
# the drivable pads remote_lab.ml lists
DRIVABLE = {"OUT0", "OUT1", "OUT2", "OUT3"}


def netlist():
    with open(ROOT / "demo/carrier_netlist.csv") as f:
        nets = {row["net"]: row["pads"].split() for row in csv.DictReader(f)}
    return nets, {pad: net for net, pads in nets.items() for pad in pads}


def chip_pins():
    """Each output and bidirectional pin's Icepi header pad, from icepi/header.lpf."""
    found = {}
    for port, index, header in re.findall(
            r'LOCATE COMP "(uo|uio)\[(\d)\]" SITE "\w+"; # header (\d+)',
            (ROOT / "icepi/header.lpf").read_text()):
        # uo[0] is the host port's MISO
        if port == "uo" and index != "0":
            found["OUT%d" % (int(index) - 1)] = "J1." + header
        elif port == "uio":
            found["IO" + index] = "J1." + header
    return found


def why_unsafe(pad, nets, net_of):
    """None if a job may drive the chip pin on pad, else the part that forbids it."""
    net = net_of[pad]
    for other in nets[net]:
        if other == pad:
            continue
        if STATE.fullmatch(other):
            return "%s keeps state" % other
        if LISTEN.fullmatch(other):
            continue
        if DRIVE.fullmatch(other):
            return "%s drives %s directly" % (other, net)
        ref, n = other.split(".")
        if not ref.startswith("R"):
            return "%s is unknown" % other
        far = net_of["%s.%d" % (ref, 3 - int(n))]
        if far in RAILS:
            continue
        for beyond in nets[far]:
            if beyond.startswith(ref + "."):
                continue
            if STATE.fullmatch(beyond):
                return "%s keeps state, through %s" % (beyond, ref)
            if not (LISTEN.fullmatch(beyond) or DRIVE.fullmatch(beyond)
                    or beyond.startswith("R")):
                return "%s is unknown, through %s" % (beyond, ref)
    return None


class Pads(unittest.TestCase):
    def test_the_netlist_allows_exactly_the_pads_remote_lab_drives(self):
        nets, net_of = netlist()
        verdicts = {name: why_unsafe(pad, nets, net_of) for name, pad in chip_pins().items()}
        self.assertEqual(len(verdicts), 15)
        self.assertEqual({name for name, why in verdicts.items() if why is None}, DRIVABLE,
                         verdicts)

    def test_swdio_is_never_driven(self):
        """SWCLK is safe only because SWDIO stays at R13's high, so no SWD request can end
        in its 0 stop bit."""
        nets, net_of = netlist()
        self.assertIsNotNone(why_unsafe(chip_pins()["IO5"], nets, net_of))
        self.assertIn("R13.1", nets["SWDIO_PICO"])
        self.assertIn("R13.2", nets["3V3_B"])

    def test_each_safe_pad_is_what_remote_lab_says(self):
        nets, _ = netlist()
        pins = chip_pins()
        self.assertEqual(sorted(nets["UART_B"]), sorted([pins["OUT0"], "J2.5", "R8.1"]))
        self.assertEqual(nets["UART_B_PICO"], ["J15.2", "R8.2"])
        self.assertEqual(sorted(nets["CAN_TX"]), sorted([pins["OUT1"], "R9.1"]))
        self.assertEqual(nets["CANA_CTX"], ["J4.1", "R9.2"])
        self.assertEqual(sorted(nets["SWCLK"]), sorted([pins["OUT2"], "J2.7", "R11.1"]))
        self.assertEqual(nets["SWCLK_PICO"], ["J8.1", "R11.2"])
        self.assertEqual(sorted(nets["NEO_3V3"]), sorted([pins["OUT3"], "J3.5", "R3.1", "U3.2"]))
        self.assertIn("R3.2", nets["GND"])

    def test_a_direct_driver_and_a_stateful_part_are_refused(self):
        nets = {"N": ["J1.1", "J13.9"], "M": ["J1.2", "R1.1"], "M2": ["R1.2", "U4.5"],
                "GND": []}
        net_of = {pad: net for net, pads in nets.items() for pad in pads}
        self.assertIn("directly", why_unsafe("J1.1", nets, net_of))
        self.assertIn("keeps state", why_unsafe("J1.2", nets, net_of))


if __name__ == "__main__":
    unittest.main()
