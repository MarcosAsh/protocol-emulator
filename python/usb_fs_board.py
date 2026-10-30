# SPDX-License-Identifier: Apache-2.0
"""The board's half of the full speed USB device.

The chip takes in every packet itself, clock recovery, NRZI, unstuffing and both CRCs
in Usb_frame_rx, and its engine answers inside the turnaround from records in the data
memory: ACK and NAK at fixed places, and each data packet this board encodes once, before
the start, with SYNC, CRC-16 and bit stuffing; the line table adds the NRZI. The board
does the rest: SETUPs, descriptors, data toggles, the address, which record answers the
next IN on each endpoint.

`Board` does no I/O: `memory` is what to load into the data memory, `feed` takes the
words the engine pushes and `out` holds the words for the tx fifo, each list whole and in
order. `load`, `restart` and `service` do the I/O over a `protocol_emulator.Host`.
"""

import usb_fs_device_firmware as firmware
from protocol_emulator import STATUS

DATA0 = 0xC3
DATA1 = 0x4B
ACK = 0xD2
NAK = 0x5A
STALL = 0x1E
MAX_PACKET = 8

# what the engine pushes, besides a SETUP's five words, the first holding a data PID
TAG_OUT = 2  # an OUT's data was acknowledged
TAG_ACKED = 3  # the host acknowledged the record sent
TAG_NOACK = 4  # the packet after the record sent was no ACK

# the requests' lengths a record is made for in advance; another that cuts a descriptor
# mid-packet is stalled
LENGTHS = (2, 4, 8, 9, 18, 34, 64, 255)

DEVICE, CONFIGURATION, STRING, REPORT = 1, 2, 3, 0x22


def crc16(data):
    """USB's CRC-16 over the bytes, complemented as sent."""
    crc = 0xFFFF
    for byte in data:
        for i in range(8):
            if (crc ^ (byte >> i)) & 1:
                crc = (crc >> 1) ^ 0xA001
            else:
                crc >>= 1
    return crc ^ 0xFFFF


def data_packet(pid, payload):
    """A data packet's bytes after SYNC, PID first, CRC-16 last."""
    crc = crc16(payload)
    return [pid] + list(payload) + [crc & 0xFF, crc >> 8]


def line_bits(packet):
    """SYNC and the packet, first bit first, a 0 after every six 1s."""
    bits, ones = [], 0
    for byte in [0x80] + list(packet):
        for i in range(8):
            bit = (byte >> i) & 1
            bits.append(bit)
            ones = ones + 1 if bit else 0
            if ones == 6:
                bits.append(0)
                ones = 0
    return bits


def record(packet):
    """The line bits less one, then the line bits sixteen to a word, first bit lowest."""
    bits = line_bits(packet)
    words = [0] * ((len(bits) + 15) // 16)
    for n, bit in enumerate(bits):
        words[n >> 4] |= bit << (n & 15)
    return [len(bits) - 1] + words


def in_token(address, endpoint):
    """The word a reply for an IN to this address and endpoint waits behind."""
    return 0x69 | (address << 8) | ((endpoint & 1) << 15)


def chunks(data, length):
    """A control read's data packets for a request of length, DATA1 first, with an empty
    one where a short answer ends on a full packet."""
    data = data[:length]
    out = [data[i:i + MAX_PACKET] for i in range(0, len(data), MAX_PACKET)]
    if len(data) < length and len(data) % MAX_PACKET == 0:
        out.append([])
    return [data_packet(DATA1 if n % 2 == 0 else DATA0, c) for n, c in enumerate(out)]


class Board:
    def __init__(self, descriptors, reports=()):
        """descriptors maps (type, index) to bytes; reports are payloads for endpoint 1,
        sent in turn once the host has read the report descriptor."""
        self.descriptors = descriptors
        packets = [data_packet(DATA1, []), data_packet(DATA0, []), [STALL]]
        for data in descriptors.values():
            for length in LENGTHS + (len(data),):
                packets += chunks(data, length)
        for payload in reports:
            packets += [data_packet(DATA0, payload), data_packet(DATA1, payload)]
        memory = [0] * firmware.FIRST_RECORD
        memory[firmware.NAK_RECORD:firmware.NAK_RECORD + 2] = record([NAK])
        memory[firmware.ACK_RECORD:firmware.ACK_RECORD + 2] = record([ACK])
        self.records = {}
        for packet in packets:
            key = bytes(packet)
            if key not in self.records:
                self.records[key] = len(memory)
                memory += record(packet)
        self.certificate_base = len(memory)
        memory += firmware.CERTIFICATE
        if len(memory) > 512:
            raise ValueError(f"the records and the certificate need {len(memory)} words")
        self.memory = memory
        self.reports = list(reports)
        self.reset()

    def reset(self):
        """A bus reset: address 0 again, unconfigured, nothing in flight."""
        self.address = 0
        self.configured = False
        self.described = False
        self.collect = None
        self.chunks = []
        self.inflight = None
        self.out = []
        self.report_toggle = DATA0
        self.next_report = 0
        self.log = []

    def _send(self, endpoint, packet, then=()):
        words = [in_token(self.address, endpoint), self.records[bytes(packet)]]
        self.inflight = (endpoint, packet, list(then))
        self.out.append(words + list(then))

    def feed(self, word):
        if self.collect is not None:
            self.collect.append(word)
            if len(self.collect) == 5:
                w = self.collect
                self.collect = None
                b = [w[0] >> 8]
                for x in w[1:]:
                    b += [x & 0xFF, x >> 8]
                self._setup(b[:8])
        elif word & 0xFF in (DATA0, DATA1):
            self.collect = [word]
        elif word == TAG_ACKED and self.inflight is not None:
            endpoint, packet, _ = self.inflight
            self.inflight = None
            if endpoint == 1:
                self.report_toggle = DATA1 if self.report_toggle == DATA0 else DATA0
                self.next_report += 1
            elif self.chunks:
                self._send(0, self.chunks.pop(0))
        elif word == TAG_NOACK and self.inflight is not None:
            endpoint, packet, then = self.inflight
            self.inflight = None
            if packet != [STALL]:
                self._send(endpoint, packet, then)
        self._report()

    def _setup(self, b):
        request_type, request = b[0], b[1]
        value, index, length = b[2] | (b[3] << 8), b[4] | (b[5] << 8), b[6] | (b[7] << 8)
        self.log.append((request_type, request, value, index, length))
        self.chunks = []
        if request == 6:  # GET_DESCRIPTOR
            if value >> 8 == REPORT:
                self.described = True
            data = self.descriptors.get((value >> 8, value & 0xFF))
            packets = [] if data is None else chunks(data, length)
            if packets and all(bytes(p) in self.records for p in packets):
                self.chunks = packets[1:]
                self._send(0, packets[0])
            else:
                self._send(0, [STALL])
        elif request_type & 0x80:
            self._send(0, [STALL])
        elif request == 5:  # SET_ADDRESS, from the status stage's ACK on
            self._send(0, data_packet(DATA1, []), [in_token(value, 0)])
            self.address = value
        else:
            if request == 9:  # SET_CONFIGURATION
                self.configured = value != 0
            self._send(0, data_packet(DATA1, []))

    def _report(self):
        if (self.inflight is None and not self.chunks and self.described
                and self.next_report < len(self.reports)):
            payload = self.reports[self.next_report]
            self._send(1, data_packet(self.report_toggle, payload))


def load(host, board):
    """Every engine halted, engine 0 loaded with the device and checked against its
    certificate, the receiver armed for good on D+ and D-, and engine 0 started."""
    for engine in (1, 0):
        host.select(engine)
        host.stop()
        host.flush()
    host.configure(firmware.CONFIG)
    host.load(firmware.WORDS)
    host.load_line_table(firmware.LINE_TABLE)
    host.load_data(board.memory)
    host.check(board.certificate_base)
    host.arm_usb(firmware.DP_PIN, base=firmware.RX_BASE, owner=0, rearm=True)
    restart(host, board)


def restart(host, board):
    """After a bus reset: engine 0 again from address 0, its program, certificate and the
    data memory as they were, so the check still holds."""
    host.stop()
    host.flush()
    board.reset()
    host.push([in_token(0, 0)])
    host.start()


def service(host, board, depth=15):
    """One round: the engine's words to the board, then the board's to the tx fifo, a
    list at a time as there is room. Returns the status word."""
    status = host.read(STATUS)[0]
    level = (status >> 10) & 15
    if level:
        for word in host.pop(level):
            board.feed(word)
    queued = (status >> 6) & 15
    while board.out and queued + len(board.out[0]) <= depth:
        words = board.out.pop(0)
        host.push(words)
        queued += len(words)
    return status
