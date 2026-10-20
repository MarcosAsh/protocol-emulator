# SPDX-License-Identifier: Apache-2.0
# 10BASE-T frames at 40 MHz. The host builds the frame and its FCS; the core sends the
# preamble and start of frame itself and times the rest onto the wire. CPython and
# MicroPython.

from protocol_emulator import CONTROL, DATA, DATA_ADDR, DEFAULT_CONFIG, TX

PREAMBLE = [0x55] * 7 + [0xD5]
LINK_TENTH = 64000  # cycles in a tenth of the 16 ms between link pulses

# TD+ on IO0, TD- on IO1, a Manchester pair
CONFIG = dict(
    DEFAULT_CONFIG, out_base=12, set_base=12, set_count=2, manchester=1, autopull=1,
    autopull_data=1)


def crc32(data):
    """The FCS of IEEE 802.3, over bytes taken least significant bit first."""
    crc = 0xFFFFFFFF
    for byte in data:
        crc ^= byte
        for _ in range(8):
            crc = (crc >> 1) ^ 0xEDB88320 if crc & 1 else crc >> 1
    return crc ^ 0xFFFFFFFF


def _big16(n):
    return [n >> 8, n & 0xFF]


def _ip_checksum(header):
    total = sum((header[i] << 8) | header[i + 1] for i in range(0, len(header), 2))
    while total > 0xFFFF:
        total = (total & 0xFFFF) + (total >> 16)
    return ~total & 0xFFFF


def udp(payload, source=(10, 0, 0, 2), port=1234):
    """A broadcast UDP datagram over IPv4, padded to the shortest frame and to an even
    length, without its FCS."""
    payload = list(payload)
    datagram = _big16(port) + _big16(port) + _big16(8 + len(payload)) + _big16(0)

    def ip(checksum):
        return ([0x45, 0] + _big16(20 + len(datagram) + len(payload))
                + [0, 0, 0x40, 0, 64, 17] + _big16(checksum)
                + list(source) + [255, 255, 255, 255])

    frame = [0xFF] * 6 + [0x02, 0, 0, 0, 0, 0x02] + _big16(0x0800)
    frame += ip(_ip_checksum(ip(0))) + datagram + payload
    length = max(60, len(frame))
    length += length & 1
    return frame + [0] * (length - len(frame))


def with_fcs(frame):
    """The frame and its FCS, what goes into the data memory."""
    fcs = crc32(frame)
    return frame + [(fcs >> (8 * n)) & 0xFF for n in range(4)]


def wire(frame):
    """The bytes on the wire: preamble, start of frame, the frame and its FCS."""
    return PREAMBLE + with_fcs(frame)


def words(data):
    """Two bytes to a word, the first in the low half, as the data memory takes them."""
    return [data[i] | (data[i + 1] << 8) for i in range(0, len(data), 2)]


def writes(frame, link_tenth=LINK_TENTH):
    """The register writes that send [frame]. The data memory takes writes only while
    every core is halted; a start runs the firmware from the top, which reads the link
    interval and then the length in bits less one of the frame and its FCS."""
    data = with_fcs(frame)
    return [
        (CONTROL, [4]), (CONTROL, [8]), (DATA_ADDR, [0]), (DATA, words(data)),
        (TX, [link_tenth, 8 * len(data) - 1]), (CONTROL, [1]),
    ]


def send(host, frame, link_tenth=LINK_TENTH):
    for reg, values in writes(frame, link_tenth):
        host.write(reg, values)
