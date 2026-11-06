# SPDX-License-Identifier: Apache-2.0
# 10BASE-T frames at 40 MHz. The host builds the frame behind its preamble; the core times
# it onto the wire and its CRC unit appends the FCS. Frames come back in through the chip's
# receiver and test/ethernet_rx.asm. CPython and MicroPython.

from protocol_emulator import CONTROL, DATA, DATA_ADDR, DEFAULT_CONFIG, STATUS, TX, hex_words

PREAMBLE = [0x55] * 7 + [0xD5]
LINK_TENTH = 64000  # cycles in a tenth of the 16 ms between link pulses

# TD+ on IO0, TD- on IO1, a Manchester pair
CONFIG = dict(
    DEFAULT_CONFIG, out_base=12, set_base=12, set_count=2, manchester=1, autopull=1,
    autopull_data=1, crc_width=32, crc_poly=0x8320, crc_poly_high=0xEDB8, crc_init=0xFFFF,
    crc_init_high=0xFFFF, crc_reflect=1, crc_complement=1)


def crc32(data):
    """The FCS of IEEE 802.3, over bytes taken least significant bit first; the chip
    computes it too, and the tests check the two agree."""
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


def wire(frame):
    """The bytes on the wire: preamble, start of frame, the frame and its FCS."""
    fcs = crc32(frame)
    return PREAMBLE + frame + [(fcs >> (8 * n)) & 0xFF for n in range(4)]


def words(data):
    """Two bytes to a word, the first in the low half, as the data memory takes them."""
    return [data[i] | (data[i + 1] << 8) for i in range(0, len(data), 2)]


def writes(frame, link_tenth=LINK_TENTH):
    """The register writes that send [frame]. The data memory takes writes only while
    every core is halted; a start runs the firmware from the top, which reads the link
    interval and then the frame's length in bits less two."""
    return [
        (CONTROL, [4]), (CONTROL, [8]), (DATA_ADDR, [0]), (DATA, words(PREAMBLE + frame)),
        (TX, [link_tenth, 8 * len(frame) - 2]), (CONTROL, [1]),
    ]


def send(host, frame, link_tenth=LINK_TENTH):
    for reg, values in writes(frame, link_tenth):
        host.write(reg, values)


def halves(data, idle=6):
    """What a sender puts on the line for data behind the preamble, a level a half bit:
    each bit its complement then itself, first bit lowest, then TP_IDL high for idle half
    bits and the line at rest."""
    levels = []
    for byte in PREAMBLE + list(data):
        for n in range(8):
            bit = (byte >> n) & 1
            levels += [1 - bit, bit]
    return levels + [1] * idle + [0]


def received(words, count):
    """count bytes from words as the chip's receiver packs them, two to a word, low first."""
    return [(words[n // 2] >> (8 * (n % 2))) & 0xFF for n in range(count)]


# test/ethernet_rx.asm's: it hands a frame to the host from the address pushed first
RX_CONFIG = dict(DEFAULT_CONFIG, autopull=1, autopull_data=1, pull_threshold=16)


def load_receiver(host, engine, name="ethernet_rx"):
    """test/ethernet_rx.asm, its words and certificate in name.hex and name.cert.hex, into
    engine, which is left selected. Both engines have to be halted."""
    def words(path):
        with open(path) as f:
            return hex_words(f.read())

    host.select(engine)
    host.configure(RX_CONFIG)
    host.load(words(name + ".hex"))
    host.certify(words(name + ".cert.hex"))


def heard(host, frame, td_plus, base, polls=200):
    """Engine 0, running the transmit firmware, sends frame while engine 1, running the
    receiver's, waits for the chip's receiver to take it back off td_plus into base up:
    the receiver's status, the bytes on the wire after the start of frame, and what
    engine 1 hands over of them. The data memory takes writes only while both cores are
    halted."""
    data = wire(frame)[len(PREAMBLE):]
    for engine in (1, 0):
        host.select(engine)
        host.stop()
        host.flush()
    host.write(DATA_ADDR, [0])
    host.write(DATA, words(PREAMBLE + frame))
    host.arm_frame(td_plus, base=base, fifty=False, owner=1)
    host.select(1)
    host.push([base])
    host.start()
    host.select(0)
    host.push([LINK_TENTH, 8 * len(frame) - 2])
    host.start()
    status = host.frame_status()
    for _ in range(polls):
        if status["finished"]:
            break
        status = host.frame_status()
    host.select(1)
    got = []
    while status["finished"] and len(got) < status["words"]:
        level = (host.read(STATUS)[0] >> 10) & 15
        if level:
            got += host.pop(level)
    host.select(0)
    return status, data, received(got, len(data))
