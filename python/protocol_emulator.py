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
DATA_ADDR = 0x0C
DATA = 0x0D
CONFIG = 0x10
CHECK_BASE = 0x40
CHECK_LOADED = 0x41
CHECK_FLAGS = 0x42
CHECK_STATUS = 0x43
REJECT_PC = 0x44
REJECT_REASON = 0x45
PROGRAM_WORDS = 512
# 0x46 and 0x47 are reserved and read as zero.

# STATUS: bit 0 halted, 1 irq, 2-5 the faults, 6-9 the tx level, 10-13 the rx level,
# 15 the other engine's irq
HALTED = 0x0001
IRQ = 0x0002
# underflow, overflow, missed deadline, bad decode; they hold until reset
FAULTS = 0x003C
# the first wire between the engines, after the 20 pins
WIRE = 20


def tx_level(status):
    return (status >> 6) & 15


def rx_level(status):
    return (status >> 10) & 15


class Refused(Exception):
    """The chip's load check refused the program: the pc and the reason it gives."""

# Engine.Config order, the nth at CONFIG + n. None is a reserved register, kept so later
# fields stay where existing hosts write them.
CONFIG_FIELDS = [
    "side_set_count", "side_set_base", "side_set_pindirs", "in_base", "in_count", "out_base",
    "out_count", "set_base", "set_count", "jmp_pin", "capture_pin", "capture_rising",
    "in_shift_right", "out_shift_right", "autopush", "push_threshold", "autopull",
    "pull_threshold", "crc_width", "crc_poly", "crc_init", "crc_reflect",
    "stuff_threshold", "stuff_level", "wrap_bottom", "wrap_top", "period_fraction",
    None, None, "autopull_data", "manchester",
]

DEFAULT_CONFIG = {
    "side_set_base": 5, "in_count": 16, "out_base": 5, "out_count": 1, "set_base": 5, "set_count": 1,
    "in_shift_right": 1, "out_shift_right": 1, "push_threshold": 16, "pull_threshold": 16,
    "crc_width": 16, "crc_poly": 0xA001, "crc_init": 0xFFFF, "crc_reflect": 1,
    "stuff_level": 1, "wrap_top": 511,
}


def check_writes(base=0, loaded=None, single_edge=False):
    """(register, words) that start the chip's check against the certificate at base."""
    return [
        (CHECK_BASE, [base]),
        (CHECK_LOADED, [0 if loaded is None else loaded]),
        (CHECK_FLAGS, [(loaded is not None) | (bool(single_edge) << 1)]),
        (CONTROL, [0x10]),
    ]


def certify_writes(certificate, base=0, loaded=None, single_edge=False):
    """check_writes after writing the certificate at base."""
    return [(DATA_ADDR, [base]), (DATA, list(certificate))] + check_writes(base, loaded, single_edge)


def config_writes(config):
    """(register, word) for every config field, 0 for a field config leaves out."""
    return [(CONFIG + n, int(config.get(name, 0))) for n, name in enumerate(CONFIG_FIELDS) if name]


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
        for reg, word in config_writes(config):
            self.write(reg, [word])

    def load(self, words, address=0):
        """Zeros fill the memory after the program: the kernel reads it as zero, and the
        SRAM powers up with arbitrary contents."""
        self.write(PROGRAM_ADDR, [address])
        self.write(PROGRAM, list(words) + [0] * (PROGRAM_WORDS - address - len(words)))

    def load_data(self, words, address=0):
        """Fill the shared data memory; words land only while every core is halted."""
        self.write(DATA_ADDR, [address])
        self.write(DATA, words)

    def certify(self, certificate, base=0, loaded=None, single_edge=False):
        """Write the selected engine's certificate at base and have the chip check its
        program against it, as it must before a start counts. Every core has to be halted
        for the write; certification lasts until the program or configuration changes,
        whatever the data memory holds later. loaded is the period every run-time load of
        p is assumed to carry, the floor where the firmware has one."""
        self.load_data(certificate, base)
        self.check(base, loaded, single_edge)

    def check(self, base=0, loaded=None, single_edge=False):
        """certify against a certificate the data memory already holds, as after a patch
        while another core runs and no data write lands."""
        for reg, words in check_writes(base, loaded, single_edge):
            self.write(reg, words)
        status = self.read(CHECK_STATUS)[0]
        while status & 1:
            status = self.read(CHECK_STATUS)[0]
        if not status & 4:
            raise Refused(self.read(REJECT_PC)[0], self.read(REJECT_REASON)[0])

    def start(self):
        """Counts only once the program is certified; otherwise the core stays halted and
        check_status shows it refused."""
        self.write(CONTROL, [1])

    def stop(self):
        """Halt the core, as program writes need. It resumes only from a start, at 0."""
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

    def read_status(self):
        """The selected engine's STATUS word."""
        return self.read(STATUS)[0]

    def faults(self):
        """The selected engine's fault bits."""
        return self.read_status() & FAULTS

    def status(self):
        s = self.read_status()
        return {
            "halted": s & HALTED, "irq": (s >> 1) & 1, "underflow": (s >> 2) & 1,
            "overflow": (s >> 3) & 1, "missed_deadline": (s >> 4) & 1,
            "decode": (s >> 5) & 1, "tx_level": tx_level(s), "rx_level": rx_level(s),
            "other_irq": (s >> 15) & 1,
        }

    def now(self):
        """The halves come in separate frames, so the high one is read either side of the
        low and the read retried if it moved."""
        hi = self.read(NOW_HI)[0]
        while True:
            lo = self.read(NOW_LO)[0]
            again = self.read(NOW_HI)[0]
            if again == hi:
                return (hi << 16) | lo
            hi = again


def hex_words(text):
    """Words from the assembler's output, one hex word per line."""
    return [int(line, 16) for line in text.split() if line]
