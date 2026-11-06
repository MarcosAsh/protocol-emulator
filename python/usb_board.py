# SPDX-License-Identifier: Apache-2.0
"""The demo board's half of the USB device.

The core handles everything with a turnaround deadline (tokens, CRC, ACK, NAK). This
handles the rest: SETUPs, descriptors, data toggles and reloading on a new address.

`Board` does no I/O. `feed` takes the words the core pushed, `reload` is the address to
load the core for (then call `flushed`), and each list in `replies` must be written to the
tx fifo whole and in order. `service` does one round of that I/O over a
`protocol_emulator.Host`.
"""

import gc

import usb_device_firmware as firmware
from protocol_emulator import PROGRAM, PROGRAM_ADDR, STATUS

DATA0 = 0xC3
DATA1 = 0x4B
MAX_PACKET = 8

TAG_DATA0 = 1  # a SETUP's eight bytes and their CRC follow, six words
TAG_DATA1 = 2  # an OUT's data: only status packets are expected, two words
TAG_ACK = 3  # the host acknowledged what we sent
TAG_DROPPED = 4  # a reply was queued for the other endpoint and is gone

# number of status reads in a row that must find the rx fifo empty before its words are
# fed, and the most words one round pops, so a bus that never goes quiet still gets reset
# checks
QUIET = 5
DRAIN_LIMIT = 64


# each byte bit-reversed, as a table because summing per bit took 2 ms per SETUP on the Pico
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
        # address whose program the core holds; None until `service` first loads it
        self.loaded = None
        # SETUPs parsed so far
        self.setups = 0
        self.reset()

    def reset(self):
        """A bus reset: address 0 again, unconfigured, and nothing pending."""
        self.address = 0
        self.configured = False
        # the laptop has asked for the report descriptor, which a HID driver does once bound
        # and before it polls endpoint 1
        self.described = False
        self.expect = 0
        self.tag = None
        self.words = []
        self.chunks = []
        self.toggle = DATA1
        self.report_toggle = DATA0
        self.replies = []
        # (endpoint, words) of each queued reply, oldest first; the core answers each with
        # one ACK or DROPPED tag, in that order
        self.queued = []
        self.new_address = None
        self.reload = 0
        self.pending_report = None
        self.dropped = False

    def report(self, payload):
        """Queue a report for the interrupt endpoint; it is kept until the host takes it."""
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
            self._acked(self.queued.pop(0)[0])
        elif word == TAG_DROPPED and self.queued:
            endpoint, words = self.queued.pop(0)
            if endpoint == 1:
                self.dropped = True
            else:
                # an IN on endpoint 1 got there first, so send it again behind what the fifo holds
                in_fifo = len(self.queued) - len(self.replies)
                self.replies.insert(0, words)
                self.queued.insert(in_fifo, (0, words))
        self._requeue()

    def _queue(self, endpoint, pid, payload):
        words = reply(endpoint, pid, payload)
        self.replies.append(words)
        self.queued.append((endpoint, words))

    def _next_chunk(self):
        if self.chunks:
            self._queue(0, self.toggle, self.chunks.pop(0))
            self.toggle = DATA0 if self.toggle == DATA1 else DATA1

    def _setup(self, b):
        request, value, length = b[1], b[2] | (b[3] << 8), b[6] | (b[7] << 8)
        self.setups += 1
        self.toggle = DATA1
        if request == 6:  # GET_DESCRIPTOR
            self.described = self.described or value >> 8 == 0x22
            data = self.descriptors.get(value >> 8, [])[:length]
            self.chunks = [data[i:i + MAX_PACKET] for i in range(0, len(data), MAX_PACKET)]
            # a short answer that ends on a full packet needs an empty packet after it
            if len(data) < length and len(data) % MAX_PACKET == 0:
                self.chunks.append([])
        else:
            if request == 5:  # SET_ADDRESS takes effect after its status stage
                self.new_address = value
            elif request == 9:  # SET_CONFIGURATION; the status packet goes ahead of a report
                self.configured = value != 0
                self.report_toggle = DATA0  # USB 2.0 9.4.5: the endpoint starts over
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
        """The core was reloaded. What it held is lost unanswered, and a report is put back."""
        lost = len(self.queued) - len(self.replies)
        if any(endpoint == 1 for endpoint, _ in self.queued[:lost]):
            self.dropped = True
        self.queued = self.queued[lost:]
        self._requeue()

    def _requeue(self):
        if self.dropped and self.pending_report is not None and not self.chunks and not self.replies:
            self.dropped = False
            self._queue(1, self.report_toggle, self.pending_report)


# where write_certificate puts the device's certificate, which covers every address
CERTIFICATE_BASE = 0


def write_certificate(host):
    """Write the certificate that load checks against. Needs every core halted, since no
    data write lands once the other core runs."""
    host.load_data(firmware.CERTIFICATE, CERTIFICATE_BASE)


def load(host, address, loaded=None):
    """Halt the core and restart it with the firmware for this address. If it already holds
    the program for `loaded`, only the words that differ are written, because a full load
    takes the core off the bus for 20 ms and SET_ADDRESS allows 2 ms."""
    # work this out before the stop, since the core is off the bus from there to the start
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
    # checked against the certificate write_certificate left in the data memory
    host.check(CERTIFICATE_BASE, loaded=firmware.BIT_PERIOD, single_edge=True)
    # the first instruction pulls the bit period, so queue it before the start
    host.push([firmware.BIT_PERIOD])
    host.start()


def drain(host, words):
    """Pop the core's words into words until QUIET status reads in a row find none, in one
    native call where the host has one. Returns the last status word read."""
    fast = getattr(host, "drain_quiet", None)
    if fast is not None:
        return fast(words, QUIET, DRAIN_LIMIT)
    idle = 0
    while idle < QUIET and len(words) < DRAIN_LIMIT:
        status = host.read(STATUS)[0]
        level = (status >> 10) & 15
        if level:
            words += host.pop(level)
            idle = 0
        else:
            idle += 1
    return status


def service(host, board, fifo_depth=8):
    """One round: hand the core's words to the board, then do what the board wants.
    Returns the status word.

    The laptop's ACK, status OUT and next SETUP arrive back to back, eleven words for an
    eight word fifo, and feeding them one by one on the Pico is too slow to keep up. So we
    drain the fifo until quiet, then feed."""
    words = []
    status = drain(host, words)
    setups = board.setups
    for word in words:
        board.feed(word)
    # the laptop NAKs its IN until the reply is queued, so no word arrives meanwhile; a
    # 5 to 11 ms collection among its words would overflow the fifo
    if board.setups != setups:
        gc.collect()
    if board.reload is not None:
        address, board.reload = board.reload, None
        # a halted core may have lost its configuration to a reset or a new bitstream
        load(host, address, None if status & 1 else board.loaded)
        board.loaded = address
        board.flushed()
    elif board.replies and ((status >> 6) & 15) + len(board.replies[0]) <= fifo_depth:
        host.push(board.replies.pop(0))
    return status
