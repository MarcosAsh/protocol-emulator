# SPDX-License-Identifier: Apache-2.0
# Host SPI for the Tiny Tapeout demo board (MicroPython, ttboard SDK v3.1.1 on DB v3, v2 on
# RP2040 boards). SPI mode 0 runs in PIO because SCK/MOSI/MISO (ui[0], ui[1], uo[0]) don't
# sit on hardware SPI pins. Turn every ui DIP switch off. Not tried on a real board yet,
# only on the RTL (test/test_demo_board.py).

import micropython
import rp2
import time
from machine import Pin
from ttboard.demoboard import DemoBoard
from ttboard.mode import RPMode

from protocol_emulator import Host

PROJECT = "tt_um_marcosash_protocol_emulator"
# first SM of PIO 1, since the SDK's slow clock uses PIO 0
STATE_MACHINE = 4
# one FIFO deep, so neither side stalls
CHUNK = 4
# SCK <= clock / 8 (see host_spi.mli): MISO changes 3 clocks after SCK falls, which leaves
# 5 clocks for the pads, mux and synchroniser before we sample it
SCK_DIVIDE = 8
# bumped on every design enable; a deselected design loses power, so if this moved since
# select() the chip has lost its program
ENABLES = [0]
WATCHERS = []


@rp2.asm_pio(
    out_init=rp2.PIO.OUT_LOW, sideset_init=rp2.PIO.OUT_LOW,
    out_shiftdir=rp2.PIO.SHIFT_LEFT, in_shiftdir=rp2.PIO.SHIFT_LEFT,
    autopull=True, pull_thresh=8, autopush=True, push_thresh=8,
)
def spi_mode0():
    # 4 cycles per bit, sample MISO as SCK falls; an empty FIFO stalls with SCK low
    out(pins, 1).side(0)  # noqa: F821
    nop().side(1)[1]  # noqa: F821
    in_(pins, 1).side(0)  # noqa: F821


def gpio(tt, name):
    return getattr(tt.pins, name).gpio_num


def watch_enables(mux):
    """Wrap the SDK's enable callback so it bumps ENABLES first."""
    callback = mux.design_enabled_callback
    if callback in WATCHERS:
        return

    def enabled(design):
        ENABLES[0] += 1
        if callback is not None:
            callback(design)

    WATCHERS.append(enabled)
    mux.design_enabled_callback = enabled


def claim_pio(index, gpios, programs):
    """Stop the PIO's state machines and unload its programs so a second instance starts
    clean. remove_program(p) is the only way to reset p's stored offset, but rp2_pio.c
    doesn't complain about one that was never loaded, so we check the offsets ourselves.
    On the RP2350B a PIO only sees 32 GPIOs, starting at 0 or 16."""
    for n in range(4):
        rp2.StateMachine(4 * index + n).active(0)
    pio = rp2.PIO(index)
    for program in programs:
        if program[1 + index] >= 0:
            pio.remove_program(program)
    pio.remove_program()
    if max(gpios) >= 32:
        if not hasattr(pio, "gpio_base"):
            raise RuntimeError("this MicroPython's PIO cannot reach GPIO %d" % max(gpios))
        pio.gpio_base(Pin(16))
    return pio


class DemoBoardSpi:
    """SCK defaults to clock / 16 and can go up to clock / 8. To change the clock, make a
    new one (the PIO divider depends on the system clock the PWM picked). programs are the
    caller's own programs on PIO 1, unloaded along with ours. Set a bit in ui_inputs for
    each of ui[3..7] that should be left to the input Pmod."""

    def __init__(self, project=PROJECT, clock_hz=48_000_000, sck_hz=None, programs=(),
                 ui_inputs=0):
        sck_hz = sck_hz or clock_hz // 16
        if SCK_DIVIDE * sck_hz > clock_hz:
            raise ValueError("SCK %d Hz is over 1/%d of the clock" % (sck_hz, SCK_DIVIDE))
        if ui_inputs & ~0xF8:
            raise ValueError("ui[0] to ui[2] are the host port's")
        self.project, self.clock_hz, self.sck_hz = project, clock_hz, sck_hz
        self.programs, self.ui_inputs = tuple(programs), ui_inputs
        self.tt = DemoBoard.get()
        self.buffers = {}
        self.select()

    def select(self):
        """Enable, clock and reset the design, then start the PIO. Call it again after
        another design has run, since that may have changed the system clock."""
        tt = self.tt
        tt.mode = RPMode.ASIC_RP_CONTROL
        if not tt.shuttle.has(self.project):
            raise RuntimeError("%s is not on this chip" % self.project)
        watch_enables(tt.shuttle)
        if not tt.shuttle.get(self.project).enable():
            raise RuntimeError("the SDK would not enable %s: see its log" % self.project)
        self.enables = ENABLES[0]
        # on DB v3.3 the button would clock the project on top of the PWM
        if getattr(tt, "manual_project_clock", None) is not None:
            tt.manual_project_clock.monitoring = False
        # config.ini or info.yaml may have started a clock on enable
        tt.clock_project_stop()
        tt.uio_oe_pico.value = 0
        for bit in range(3):
            if getattr(tt.pins, "ui_in%d" % bit).mode != Pin.OUT:
                raise RuntimeError("ui[%d] reads high: turn its DIP switch off" % bit)
        for bit in range(3, 8):
            if self.ui_inputs >> bit & 1:
                getattr(tt.pins, "ui_in%d" % bit).mode = Pin.IN
        sck, mosi, cs_n, miso = (gpio(tt, n) for n in ("ui_in0", "ui_in1", "ui_in2", "uo_out0"))
        self.cs_n = Pin(cs_n, Pin.OUT, value=1)
        tt.clock_project_PWM(self.clock_hz)
        tt.reset_project(True)
        time.sleep_ms(1)
        tt.reset_project(False)
        self.pio = claim_pio(
            STATE_MACHINE // 4, (sck, mosi, miso), (spi_mode0,) + self.programs)
        self.sm = rp2.StateMachine(
            STATE_MACHINE, spi_mode0, freq=4 * self.sck_hz,
            sideset_base=Pin(sck), out_base=Pin(mosi), in_base=Pin(miso),
        )
        self.sm.active(1)

    def selected(self):
        """True if our design is still enabled and nothing else was enabled since select."""
        enabled = self.tt.shuttle.enabled
        return (ENABLES[0] == self.enables and enabled is not None
                and enabled.name == self.project)

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


class DemoBoardHost(Host):
    """Host that remembers configs and loads so reload() can restore them after a
    reselect. Engines come back halted with empty fifos; restarting them is up to you."""

    def __init__(self, spi):
        super().__init__(spi.transfer)
        self.spi, self.engine, self.engines, self.data = spi, 0, {}, []

    def _engine(self):
        return self.engines.setdefault(self.engine, {"config": None, "loads": []})

    def select(self, engine):
        self.engine = engine
        Host.select(self, engine)

    def configure(self, config):
        self._engine()["config"] = dict(config)
        Host.configure(self, config)

    def load(self, words, address=0):
        """A load at 0 zero-fills the rest, so it replaces every earlier load."""
        loads = self._engine()["loads"]
        if address == 0:
            loads.clear()
        loads.append((address, list(words)))
        Host.load(self, words, address)

    def load_data(self, words, address=0):
        self.data.append((address, list(words)))
        Host.load_data(self, words, address)

    def reload(self):
        for engine in sorted(self.engines):
            Host.select(self, engine)
            kept = self.engines[engine]
            if kept["config"] is not None:
                Host.configure(self, kept["config"])
            for address, words in kept["loads"]:
                Host.load(self, words, address)
        for address, words in self.data:
            Host.load_data(self, words, address)
        Host.select(self, self.engine)

    def reselect(self):
        self.spi.select()
        self.reload()

    def ensure(self):
        """Reselect and reload if another design ran since the last select; whether it did."""
        if self.spi.selected():
            return False
        self.reselect()
        return True


def host(**kwargs):
    return DemoBoardHost(DemoBoardSpi(**kwargs))
