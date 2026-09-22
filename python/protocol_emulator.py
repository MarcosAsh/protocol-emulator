# SPDX-License-Identifier: Apache-2.0
# Host side of the core over SPI. Works on CPython and MicroPython.

CONTROL = 0x00
STATUS = 0x01
PC = 0x02
NOW_LO = 0x03
NOW_HI = 0x04
CAPTURE_LO = 0x05
CAPTURE_HI = 0x06
TX = 0x07
RX = 0x08
PROGRAM_ADDR = 0x09
PROGRAM = 0x0A
SELECT = 0x0B
CONFIG = 0x10

CONFIG_FIELDS = [
    "side_set_count", "side_set_base", "side_set_pindirs", "in_base", "in_count", "out_base",
    "out_count", "set_base", "set_count", "jmp_pin", "capture_pin", "capture_rising",
    "in_shift_right", "out_shift_right", "autopush", "push_threshold", "autopull",
    "pull_threshold", "crc_width", "crc_poly", "crc_init", "crc_reflect",
    "stuff_threshold", "stuff_level", "wrap_bottom", "wrap_top", "period_fraction",
]

DEFAULT_CONFIG = {
    "side_set_base": 5, "in_count": 16, "out_base": 5, "out_count": 1, "set_base": 5, "set_count": 1,
    "in_shift_right": 1, "out_shift_right": 1, "push_threshold": 16, "pull_threshold": 16,
    "crc_width": 16, "crc_poly": 0xA001, "crc_init": 0xFFFF, "crc_reflect": 1,
    "stuff_level": 1, "wrap_top": 511,
}


class Host:
    """transfer(data) exchanges one CS-framed list of bytes and returns the replies."""

    def __init__(self, transfer):
        self.transfer = transfer

    def write(self, reg, words):
        data = [0x80 | reg]
        for w in words:
            data += [(w >> 8) & 0xFF, w & 0xFF]
        self.transfer(data)

    def read(self, reg, count=1):
        reply = self.transfer([reg] + [0] * (2 * count))[1:]
        return [(reply[i] << 8) | reply[i + 1] for i in range(0, 2 * count, 2)]

    def select(self, engine):
        """Every call after this reaches that engine; a chip with one engine ignores it."""
        self.write(SELECT, [engine])

    def configure(self, config):
        """Only while the core is halted: a running core ignores it."""
        for n, name in enumerate(CONFIG_FIELDS):
            self.write(CONFIG + n, [int(config.get(name, 0))])

    def load(self, words, address=0):
        self.write(PROGRAM_ADDR, [address])
        self.write(PROGRAM, words)

    def start(self):
        self.write(CONTROL, [1])

    def stop(self):
        """Halt the core; the program can only be written while it is halted."""
        self.write(CONTROL, [4])

    def flush(self):
        """Empty both fifos; ignored unless the core is halted."""
        self.write(CONTROL, [8])

    def clear_irq(self):
        self.write(CONTROL, [2])

    def push(self, words):
        self.write(TX, words)

    def pop(self, count=1):
        return self.read(RX, count)

    def status(self):
        s = self.read(STATUS)[0]
        return {
            "halted": s & 1, "irq": (s >> 1) & 1, "underflow": (s >> 2) & 1,
            "overflow": (s >> 3) & 1, "missed_deadline": (s >> 4) & 1,
            "decode": (s >> 5) & 1, "tx_level": (s >> 6) & 15, "rx_level": (s >> 10) & 15,
            "other_irq": (s >> 15) & 1,
        }

    def now(self):
        lo = self.read(NOW_LO)[0]
        hi = self.read(NOW_HI)[0]
        return (hi << 16) | lo


def hex_words(text):
    """Words from the assembler's output, one hex word per line."""
    return [int(line, 16) for line in text.split() if line]
