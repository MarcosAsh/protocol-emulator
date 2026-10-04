# SPDX-License-Identifier: Apache-2.0
# Transport for the Tiny Tapeout demo board (MicroPython, ttboard SDK v3.1.1 on the RP2350B
# DB v3, v2 on the RP2040 boards). A PIO state machine runs SPI mode 0 on ui[0] SCK, ui[1]
# MOSI and uo[0] MISO, which no hardware SPI pins match; ui[2] CS_N is a plain pin. Every ui
# DIP switch off. Untested on a board; test/test_demo_board.py runs it on the RTL.

import micropython
import rp2
import time
from machine import Pin
from ttboard.demoboard import DemoBoard
from ttboard.mode import RPMode

from protocol_emulator import Host

PROJECT = "tt_um_marcosash_protocol_emulator"
# PIO 1's first, on either RP2: the SDK's slow clock takes PIO 0
STATE_MACHINE = 4
# a FIFO's depth, so a chunk out and its replies back never stall either side
CHUNK = 4
# the chip moves MISO 3 clocks after SCK falls, and the PIO reads it 2 system clocks late,
# past the pads and mux both ways: at 48 MHz a twelfth leaves a clock to spare
SCK_DIVIDE = 12


@rp2.asm_pio(
    out_init=rp2.PIO.OUT_LOW, sideset_init=rp2.PIO.OUT_LOW,
    out_shiftdir=rp2.PIO.SHIFT_LEFT, in_shiftdir=rp2.PIO.SHIFT_LEFT,
    autopull=True, pull_thresh=8, autopush=True, push_thresh=8,
)
def spi_mode0():
    # four cycles a bit, MISO sampled as SCK rises; an empty FIFO stalls here with SCK low
    out(pins, 1).side(0)[1]  # noqa: F821
    in_(pins, 1).side(1)[1]  # noqa: F821


def gpio(tt, name):
    return getattr(tt.pins, name).gpio_num


def claim_pio(index, gpios):
    """Stop PIO index's state machines and clear its programs, so a second instance in the
    same session starts clean. On the RP2350B a PIO sees 32 GPIOs from 0 or from 16."""
    for n in range(4):
        rp2.StateMachine(4 * index + n).active(0)
    pio = rp2.PIO(index)
    pio.remove_program()
    if max(gpios) >= 32:
        if not hasattr(pio, "gpio_base"):
            raise RuntimeError("this MicroPython's PIO cannot reach GPIO %d" % max(gpios))
        pio.gpio_base(Pin(16))
    return pio


class DemoBoardSpi:
    """SCK at most a twelfth of the chip's clock (SCK_DIVIDE), by default a sixteenth.
    Build another to change the clock: the PIO's divider is set from the system clock the
    PWM chose."""

    def __init__(self, project=PROJECT, clock_hz=48_000_000, sck_hz=None):
        sck_hz = sck_hz or clock_hz // 16
        if SCK_DIVIDE * sck_hz > clock_hz:
            raise ValueError("SCK %d Hz is over 1/%d of the clock" % (sck_hz, SCK_DIVIDE))
        self.tt = tt = DemoBoard.get()
        tt.mode = RPMode.ASIC_RP_CONTROL
        if not tt.shuttle.has(project):
            raise RuntimeError("%s is not on this chip" % project)
        tt.shuttle.get(project).enable()
        # DB v3.3's button would clock the project once, over the PWM
        if getattr(tt, "manual_project_clock", None) is not None:
            tt.manual_project_clock.monitoring = False
        # config.ini or info.yaml's clock_hz may have started one at enable
        tt.clock_project_stop()
        tt.uio_oe_pico.value = 0
        for bit in range(3):
            if getattr(tt.pins, "ui_in%d" % bit).mode != Pin.OUT:
                raise RuntimeError("ui[%d] reads high: turn its DIP switch off" % bit)
        sck, mosi, cs_n, miso = (gpio(tt, n) for n in ("ui_in0", "ui_in1", "ui_in2", "uo_out0"))
        self.cs_n = Pin(cs_n, Pin.OUT, value=1)
        tt.clock_project_PWM(clock_hz)
        tt.reset_project(True)
        time.sleep_ms(1)
        tt.reset_project(False)
        self.clock_hz = clock_hz
        self.pio = claim_pio(STATE_MACHINE // 4, (sck, mosi, miso))
        self.sm = rp2.StateMachine(
            STATE_MACHINE, spi_mode0, freq=4 * sck_hz,
            sideset_base=Pin(sck), out_base=Pin(mosi), in_base=Pin(miso),
        )
        self.sm.active(1)
        self.sck_hz = sck_hz
        self.buffers = {}

    def _buffers(self, n):
        out, reply = bytearray(n), bytearray(n)
        o, r = memoryview(out), memoryview(reply)
        chunks = [(o[i:i + CHUNK], r[i:i + CHUNK]) for i in range(0, n, CHUNK)]
        self.buffers[n] = (out, reply, chunks)
        return self.buffers[n]

    @micropython.native
    def transfer(self, data):
        n = len(data)
        out, reply, chunks = self.buffers.get(n) or self._buffers(n)
        for i in range(n):
            out[i] = data[i]
        sm = self.sm
        self.cs_n(0)
        for o, r in chunks:
            sm.put(o, 24)
            sm.get(r)
        self.cs_n(1)
        return bytes(reply)


def host(**kwargs):
    return Host(DemoBoardSpi(**kwargs).transfer)
