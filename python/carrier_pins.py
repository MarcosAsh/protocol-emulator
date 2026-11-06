# SPDX-License-Identifier: Apache-2.0
# Self-test for the bench carrier, run on its Picos (MicroPython and CPython). Pins drives
# and reads the Icepi's header through icepi/carrier_check.v over Pico A's host port, and
# bit-bangs a flash JEDEC ID, an I2C address, a 1-Wire ROM and an SWD DPIDR through it, one
# frame per step. Gpio is a Pico's own pins. demo/carrier_check.py runs both over the REPL.

SIGNATURE = b"pin"
FRAME = 11
# header pin for each of carrier_check.v's pins, in order
HEADER = (3, 5, 7, 11, 13, 8, 10, 12, 18, 22, 26, 28, 29, 31, 35, 33, 37, 36, 38, 40, 15)
PIN = {h: i for i, h in enumerate(HEADER)}
# carrier_check.v's idle state: header 10 (CAN's D) and 28 (the flash's CS) driven high
IDLE = (1 << PIN[10]) | (1 << PIN[28])
# the parts' pins, by header number
SDA, SCL, DQ = 33, 35, 37
FLASH_CS, FLASH_CLK, FLASH_DI, FLASH_DO = 28, 26, 22, 3
SWCLK, SWDIO = 12, 36


def encode(oe, out, slot=None):
    """Build a frame: oe and out are pin masks, slot is (header, level, length, sample)
    with times in microseconds from the end of the frame."""
    words = [oe >> 16, oe >> 8, oe, out >> 16, out >> 8, out, 0, 0, 0, 0, 0]
    if slot:
        header, level, length, sample = slot
        words[6] = 0x40 | (level << 7) | PIN[header]
        words[7:11] = [length >> 8, length, sample >> 8, sample]
    return bytes(w & 0xFF for w in words)


def decode(reply):
    """Return the signature, the pins as they were when the frame began, and the last
    slot's sample (None until it's taken)."""
    levels = (reply[3] << 16) | (reply[4] << 8) | reply[5]
    sample = reply[6] & 1 if reply[6] & 2 else None
    return bytes(reply[0:3]), levels, sample


def bit(levels, header):
    return (levels >> PIN[header]) & 1


def _wait_us():
    try:
        import time

        return time.sleep_us
    except (ImportError, AttributeError):
        return lambda us: None


class Pins:
    """Talk to carrier_check.v through transfer: send a frame of bytes, get a reply. A
    header pin is driven to 0 or 1, or released (None). Levels are a mask of PIN."""

    def __init__(self, transfer, wait_us=None):
        self.transfer = transfer
        self.wait_us = wait_us or _wait_us()
        self.oe = self.out = IDLE

    def frame(self, slot=None):
        signature, levels, sample = decode(self.transfer(encode(self.oe, self.out, slot)))
        if signature != SIGNATURE:
            raise RuntimeError("no carrier_check bitstream: the host port read %s" % signature)
        return levels, sample

    def signature(self):
        return decode(self.transfer(encode(self.oe, self.out)))[0]

    def put(self, changes):
        """Send one frame applying changes ({header: 0, 1 or None}). The levels returned
        are from before the changes."""
        for header, level in changes.items():
            mask = 1 << PIN[header]
            self.oe = self.oe | mask if level is not None else self.oe & ~mask
            self.out = self.out | mask if level else self.out & ~mask
        return self.frame()[0]

    def apply(self, changes):
        """Return the levels a millisecond after changes, once they've settled."""
        self.put(changes)
        self.wait_us(1000)
        return self.frame()[0]

    def idle(self):
        self.oe = self.out = IDLE
        return self.apply({})

    def slot(self, header, level, length, sample, after=0):
        """Drive header to level for length us, then restore it, and read its level at
        sample us. The next frame waits for both, plus a bit more."""
        self.frame((header, level, length, sample))
        self.wait_us(max(length, sample) + after + 2)
        return self.frame()[1]

    def pulses(self, plan, trains=1, gap_us=0):
        """Send trains of pulses, gap_us apart. Each (header, count, level) gives count
        20 us pulses to level, one frame per pulse."""
        for train in range(trains):
            if train:
                self.wait_us(gap_us)
            for header, count, level in plan:
                for _ in range(count):
                    self.slot(header, level, 20, 0, 40)

    # SPI mode 0 on the flash's pins, all driven from the chip's side
    def spi(self, data, read=0):
        self.put({FLASH_CS: 0, FLASH_CLK: 0})
        got = []
        for byte in list(data) + [0] * read:
            value = 0
            for i in range(8):
                self.put({FLASH_DI: (byte >> (7 - i)) & 1, FLASH_CLK: 0})
                self.put({FLASH_CLK: 1})
                value = (value << 1) | bit(self.put({FLASH_CLK: 0}), FLASH_DO)
            got.append(value)
        self.put({FLASH_CS: 1, FLASH_DI: None})
        return got[len(data):]

    def jedec(self):
        """Wake the flash from power-down, then read its JEDEC ID."""
        self.spi([0xAB])
        self.wait_us(5)
        return self.spi([0x9F], 3)

    # I2C, open drain: 0 drives low, None lets the pull-up have it
    def i2c_probe(self, address):
        """Send START, the write address and STOP. Returns whether the address was ACKed."""
        self.put({SDA: None, SCL: None})
        self.put({SDA: 0})
        self.put({SCL: 0})
        byte = address << 1
        for i in range(8):
            self.put({SDA: None if (byte >> (7 - i)) & 1 else 0})
            self.put({SCL: None})
            self.put({SCL: 0})
        self.put({SDA: None})
        self.put({SCL: None})
        acked = not bit(self.put({SCL: 0}), SDA)
        self.put({SDA: 0})
        self.put({SCL: None})
        self.put({SDA: None})
        return acked

    # 1-Wire on DQ, with slot times set by carrier_check.v (DS18B20 datasheet numbers)
    def one_wire_reset(self):
        """Send a 480 us reset. Returns True if a presence pulse answered."""
        return self.slot(DQ, 0, 480, 550, 410) == 0

    def one_wire_write(self, byte):
        for i in range(8):
            self.slot(DQ, 0, 6 if (byte >> i) & 1 else 60, 61, 5)

    def one_wire_read(self):
        return sum(self.slot(DQ, 0, 2, 12, 50) << i for i in range(8))

    def read_rom(self):
        """Return READ ROM's eight bytes, or None if there's no presence pulse."""
        self.put({DQ: None})
        if not self.one_wire_reset():
            return None
        self.one_wire_write(0x33)
        return [self.one_wire_read() for _ in range(8)]

    # SWD: the host changes SWDIO while SWCLK is low, the target after SWCLK rises
    def swd_write(self, bits):
        for b in bits:
            self.put({SWDIO: b, SWCLK: 0})
            self.put({SWCLK: 1})

    def swd_read(self, n):
        """Read n bits as the target drives them, each after the clock rises."""
        got = []
        self.put({SWDIO: None, SWCLK: 0})
        for _ in range(n):
            self.put({SWCLK: 1})
            got.append(bit(self.put({SWCLK: 0}), SWDIO))
        return got

    def swd_dpidr(self, wake, line_reset, targetsel, target):
        """Return DPIDR's ACK, value and parity bit. Sends the wake and line_reset words
        (LSB first) and a TARGETSEL write of target, using demo_swd's words for an RP2040.
        Leaves SWCLK low and releases SWDIO."""
        words = lambda ws: [(w >> i) & 1 for w in ws for i in range(16)]  # noqa: E731
        self.swd_write(words(wake) + words(line_reset))
        self.swd_write([(targetsel >> i) & 1 for i in range(8)])
        self.swd_read(5)
        self.swd_write([(target >> i) & 1 for i in range(32)] + [bin(target).count("1") & 1])
        self.swd_write([1, 0, 1, 0, 0, 1, 0, 1])
        bits = self.swd_read(3 + 33)
        # turnaround back to the host
        self.swd_read(1)
        self.swd_write([0] * 8)
        self.put({SWDIO: None, SWCLK: 0})
        ack = sum(b << i for i, b in enumerate(bits[:3]))
        value = sum(b << i for i, b in enumerate(bits[3:35]))
        return ack, value, bits[35]


def pico_a(baudrate=1_000_000):
    """Pins over Pico A's host port: SPI0 with GP2 SCK, GP3 MOSI, GP4 MISO, GP5 CS_N."""
    from machine import SPI, Pin

    spi = SPI(0, baudrate=baudrate, polarity=0, phase=0, bits=8, firstbit=SPI.MSB,
              sck=Pin(2), mosi=Pin(3), miso=Pin(4))
    cs_n = Pin(5, Pin.OUT, value=1)
    reply = bytearray(FRAME)

    def transfer(data):
        cs_n(0)
        spi.write_readinto(data, reply)
        cs_n(1)
        return bytes(reply)

    return Pins(transfer)


class Gpio:
    """A Pico's own pins, by GP number."""

    def __init__(self, pin=None):
        if pin is None:
            from machine import Pin as pin
        self.pin = pin

    def drive(self, gp, level):
        self.pin(gp, self.pin.OUT, value=level)

    def let_go(self, gp, pull=None):
        """pull: None, "up" or "down"."""
        pulls = {None: None, "up": self.pin.PULL_UP, "down": self.pin.PULL_DOWN}
        self.pin(gp, self.pin.IN, pulls[pull])

    def read(self, gp):
        return self.pin(gp).value()

    def pressed(self, gp, ms):
        """True if gp, pulled up, is low now or goes low within ms (a button to ground)."""
        import time

        self.let_go(gp, "up")
        time.sleep_ms(1)
        start = time.ticks_ms()
        while self.read(gp):
            if time.ticks_diff(time.ticks_ms(), start) >= ms:
                return False
            time.sleep_ms(5)
        return True

    def vsys(self):
        """VSYS in volts, read as a third of it on GP29 (ADC 3). Averages eight reads after
        discarding the first, which reads low after boot."""
        from machine import ADC

        adc = ADC(29)
        adc.read_u16()
        return round(sum(adc.read_u16() for _ in range(8)) / 8 * 3 * 3.3 / 65535, 2)

    def i2c_scan(self, sda, scl):
        """Return the addresses that ACK on I2C1 at 100 kHz, then release the pins."""
        from machine import I2C

        found = I2C(1, sda=self.pin(sda), scl=self.pin(scl), freq=100_000).scan()
        self.let_go(sda)
        self.let_go(scl)
        return found
