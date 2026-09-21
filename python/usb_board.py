# SPDX-License-Identifier: Apache-2.0
"""The demo board's half of the USB device.

The core answers inside the bus's turnaround time: it matches tokens, takes data and
checks its CRC, sends ACK, and sends NAK for as long as nothing is queued. Everything
that can wait is here: what a SETUP means, which descriptor goes back, the data toggles,
and loading the core again when the address changes. Runs on MicroPython and CPython.

`Board` does no I/O. `feed` takes the words the core pushed, `replies` are the word lists
to write to its tx fifo, one whole list at a time, and `reload` is the address to load the
core for. `service` is one round of that I/O over a `protocol_emulator.Host`.
"""

import usb_device_firmware as firmware

DATA0 = 0xC3
DATA1 = 0x4B
MAX_PACKET = 8

TAG_DATA0 = 1  # a SETUP's eight bytes and their CRC follow, six words
TAG_DATA1 = 2  # an OUT's data: only status packets are expected, two words
TAG_ACK = 3  # the host acknowledged what we sent
TAG_DROPPED = 4  # a reply was queued for the other endpoint and is gone


def _reverse(byte):
    return sum(((byte >> i) & 1) << (7 - i) for i in range(8))


def word_bytes(word):
    """The first bit the core received is the top bit of a word."""
    return [_reverse(word >> 8), _reverse(word & 0xFF)]


def reply(endpoint, pid, payload):
    """What the core sends for the next IN on this endpoint."""
    data = [payload[i] | (payload[i + 1] << 8 if i + 1 < len(payload) else 0)
            for i in range(0, len(payload), 2)]
    return [endpoint | (pid << 8), (8 * len(payload)) | (len(data) << 8)] + data


class Board:
    def __init__(self, descriptors):
        self.descriptors = descriptors  # by descriptor type
        self.reset()

    def reset(self):
        """A bus reset: address 0 again and nothing pending."""
        self.expect = 0
        self.tag = None
        self.words = []
        self.chunks = []
        self.toggle = DATA1
        self.report_toggle = DATA0
        self.replies = []
        self.new_address = None
        self.reload = 0
        self.pending_report = None
        self.dropped = False

    def report(self, payload):
        """A report for the interrupt endpoint; kept until the host has taken it."""
        self.pending_report = payload
        self.replies.append(reply(1, self.report_toggle, payload))

    def feed(self, word):
        if self.expect:
            self.words.append(word)
            self.expect -= 1
            if self.expect == 0 and self.tag == TAG_DATA0:
                data = [b for w in self.words for b in word_bytes(w)]
                self._setup(data[:8])
        elif word == TAG_DATA0:
            self.tag, self.expect, self.words = word, 6, []
        elif word == TAG_DATA1:
            self.tag, self.expect, self.words = word, 2, []
        elif word == TAG_ACK:
            self._acked()
        elif word == TAG_DROPPED:
            self.dropped = True
        self._requeue()

    def _next_chunk(self):
        if self.chunks:
            self.replies.append(reply(0, self.toggle, self.chunks.pop(0)))
            self.toggle = DATA0 if self.toggle == DATA1 else DATA1

    def _setup(self, b):
        request, value, length = b[1], b[2] | (b[3] << 8), b[6] | (b[7] << 8)
        self.toggle = DATA1
        if request == 6:  # GET_DESCRIPTOR
            data = self.descriptors.get(value >> 8, [])[:length]
            self.chunks = [data[i:i + MAX_PACKET] for i in range(0, len(data), MAX_PACKET)]
            # stopping short of what was asked on a full packet takes an empty one
            if len(data) < length and len(data) % MAX_PACKET == 0:
                self.chunks.append([])
        else:
            if request == 5:  # SET_ADDRESS takes effect after its status stage
                self.new_address = value
            self.chunks = [[]]
        self._next_chunk()

    def _acked(self):
        if self.chunks:
            self._next_chunk()
        elif self.pending_report is not None and not self.dropped and self.new_address is None:
            self.pending_report = None
            self.report_toggle = DATA1 if self.report_toggle == DATA0 else DATA0
        elif self.new_address is not None:
            self.reload, self.new_address = self.new_address, None

    def _requeue(self):
        if self.dropped and self.pending_report is not None and not self.chunks and not self.replies:
            self.dropped = False
            self.replies.append(reply(1, self.report_toggle, self.pending_report))


def load(host, address):
    """Halt the core and start it again with the firmware for this address."""
    host.stop()
    host.configure(firmware.CONFIG)
    host.load(firmware.words(address))
    # the program's first instruction pulls the bit period, so it has to be there already
    host.push([firmware.BIT_PERIOD])
    host.start()


def service(host, board, fifo_depth=8):
    """One round: hand the core's words to the board, then do what the board wants."""
    status = host.status()
    if status["rx_level"]:
        for word in host.pop(status["rx_level"]):
            board.feed(word)
    if board.reload is not None:
        address, board.reload = board.reload, None
        load(host, address)
    elif board.replies and status["tx_level"] + len(board.replies[0]) <= fifo_depth:
        host.push(board.replies.pop(0))
    return status
