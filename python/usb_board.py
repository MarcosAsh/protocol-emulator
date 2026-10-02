# SPDX-License-Identifier: Apache-2.0
"""The demo board's half of the USB device.

The core does what must meet the turnaround time (tokens, CRC, ACK, NAK); this does
the rest: SETUPs, descriptors, data toggles, reloading on a new address.

`Board` does no I/O: `feed` takes the words the core pushed, `reload` is the address to
load the core for (then call `flushed`), and each list in `replies` must be written to
the tx fifo whole and in order. `service` is one round of that I/O over a `protocol_emulator.Host`.
"""

import usb_device_firmware as firmware
from protocol_emulator import PROGRAM, PROGRAM_ADDR

DATA0 = 0xC3
DATA1 = 0x4B
MAX_PACKET = 8

TAG_DATA0 = 1  # a SETUP's eight bytes and their CRC follow, six words
TAG_DATA1 = 2  # an OUT's data: only status packets are expected, two words
TAG_ACK = 3  # the host acknowledged what we sent
TAG_DROPPED = 4  # a reply was queued for the other endpoint and is gone


# each byte bit reversed, a table as the per-bit sum took 2 ms a SETUP on the Pico
_REVERSED = bytes(sum(((byte >> i) & 1) << (7 - i) for i in range(8)) for byte in range(256))


def word_bytes(word):
    """The first bit the core received is the top bit of a word."""
    return [_REVERSED[word >> 8], _REVERSED[word & 0xFF]]


def reply(endpoint, pid, payload):
    """What the core sends for the next IN on this endpoint."""
    data = [payload[i] | (payload[i + 1] << 8 if i + 1 < len(payload) else 0)
            for i in range(0, len(payload), 2)]
    return [endpoint | (pid << 8), (8 * len(payload)) | (len(data) << 8)] + data


class Board:
    def __init__(self, descriptors):
        self.descriptors = descriptors  # by descriptor type
        # the address whose program the core holds, None until `service` first loads it
        self.loaded = None
        self.reset()

    def reset(self):
        """A bus reset: address 0 again, unconfigured, and nothing pending."""
        self.address = 0
        self.configured = False
        self.expect = 0
        self.tag = None
        self.words = []
        self.chunks = []
        self.toggle = DATA1
        self.report_toggle = DATA0
        self.replies = []
        # the endpoint of each reply queued, oldest first: the core answers each with one
        # ACK or DROPPED tag, in that order
        self.queued = []
        self.new_address = None
        self.reload = 0
        self.pending_report = None
        self.dropped = False

    def report(self, payload):
        """A report for the interrupt endpoint; kept until the host has taken it."""
        self.pending_report = payload
        self._queue(1, self.report_toggle, payload)

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
        elif word == TAG_ACK and self.queued:
            self._acked(self.queued.pop(0))
        elif word == TAG_DROPPED and self.queued:
            if self.queued.pop(0) == 1:
                self.dropped = True
        self._requeue()

    def _queue(self, endpoint, pid, payload):
        self.replies.append(reply(endpoint, pid, payload))
        self.queued.append(endpoint)

    def _next_chunk(self):
        if self.chunks:
            self._queue(0, self.toggle, self.chunks.pop(0))
            self.toggle = DATA0 if self.toggle == DATA1 else DATA1

    def _setup(self, b):
        request, value, length = b[1], b[2] | (b[3] << 8), b[6] | (b[7] << 8)
        self.toggle = DATA1
        if request == 6:  # GET_DESCRIPTOR
            data = self.descriptors.get(value >> 8, [])[:length]
            self.chunks = [data[i:i + MAX_PACKET] for i in range(0, len(data), MAX_PACKET)]
            # a short answer ending on a full packet needs an empty one
            if len(data) < length and len(data) % MAX_PACKET == 0:
                self.chunks.append([])
        else:
            if request == 5:  # SET_ADDRESS takes effect after its status stage
                self.new_address = value
            elif request == 9:  # SET_CONFIGURATION; the status packet goes ahead of a report
                self.configured = value != 0
            self.chunks = [[]]
        self._next_chunk()

    def _acked(self, endpoint):
        if endpoint == 1:
            self.pending_report = None
            self.report_toggle = DATA1 if self.report_toggle == DATA0 else DATA0
        elif self.chunks:
            self._next_chunk()
        elif self.new_address is not None:
            self.address = self.reload = self.new_address
            self.new_address = None

    def flushed(self):
        """The core was reloaded: what it held was lost unanswered, a report put back."""
        lost = len(self.queued) - len(self.replies)
        if 1 in self.queued[:lost]:
            self.dropped = True
        self.queued = self.queued[lost:]
        self._requeue()

    def _requeue(self):
        if self.dropped and self.pending_report is not None and not self.chunks and not self.replies:
            self.dropped = False
            self._queue(1, self.report_toggle, self.pending_report)


def load(host, address, loaded=None):
    """Halt the core and start it again with the firmware for this address. When it holds
    the program for `loaded`, only the words that differ are written: a full load takes
    the core off the bus for 20 ms, past the 2 ms SET_ADDRESS allows."""
    # worked out before the stop, as the core is off the bus from there to the start
    first, words = 0, None
    if loaded is None:
        words = firmware.words(address)
    elif loaded != address:
        first = firmware.PATCH_AT[0]
        words = firmware.WORDS[first:firmware.PATCH_AT[-1] + 1]
        for at, word in zip(firmware.PATCH_AT, firmware.PATCHES[address]):
            words[at - first] = word
    host.stop()
    # a reply still queued would be pulled by the new program as its bit period
    host.flush()
    if loaded is None:
        host.configure(firmware.CONFIG)
        host.load(words)
    elif words is not None:
        host.write(PROGRAM_ADDR, [first])
        host.write(PROGRAM, words)
    # the first instruction pulls the bit period, so it must be queued before start
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
        # a halted core may have lost its configuration to a reset or a new bitstream
        load(host, address, None if status["halted"] else board.loaded)
        board.loaded = address
        board.flushed()
    elif board.replies and status["tx_level"] + len(board.replies[0]) <= fifo_depth:
        host.push(board.replies.pop(0))
    return status
