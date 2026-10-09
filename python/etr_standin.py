# SPDX-License-Identifier: Apache-2.0
# The ttboard SDK calls demo_board.py makes, on a bare Pico wired as Pico A (BRINGUP.md):
# GP2 SCK -> ui[0], GP3 MOSI -> ui[1], GP5 CS_N -> ui[2], GP4 MISO <- uo[0]. The chip keeps
# its own clock and is reset by hand, and selecting another design powers nothing down.
# demo/etr_standin.sh copies it as ttboard/demoboard.py and ttboard/mode.py, then runs main.

import machine
from machine import Pin

GPIOS = {"ui_in0": 2, "ui_in1": 3, "ui_in2": 5, "uo_out0": 4}


class RPMode:
    SAFE, ASIC_RP_CONTROL, ASIC_MANUAL_INPUTS = 0, 1, 2


class StandardPin:
    def __init__(self, gpio):
        self.gpio_num = gpio
        self.mode = Pin.IN

    @property
    def mode(self):
        return self._mode

    @mode.setter
    def mode(self, mode):
        self._mode = mode
        Pin(self.gpio_num, mode, Pin.PULL_DOWN if mode == Pin.IN else None)


class Pins:
    def __init__(self):
        for name, gpio in GPIOS.items():
            setattr(self, name, StandardPin(gpio))


class Port:
    value = 0


class Design:
    def __init__(self, mux, name):
        self.mux, self.name = mux, name

    def enable(self, force=False):
        self.mux.disable()
        self.mux.enabled = self
        if self.mux.design_enabled_callback is not None:
            self.mux.design_enabled_callback(self)
        return True


class ProjectMux:
    def __init__(self):
        self.enabled, self.design_enabled_callback = None, None

    def has(self, name):
        return True

    def get(self, name):
        return Design(self, name)

    def disable(self):
        self.enabled = None


class DemoBoard:
    _instance = None
    manual_project_clock = None

    @classmethod
    def get(cls):
        if cls._instance is None:
            cls._instance = cls()
        return cls._instance

    def __init__(self):
        self.pins = Pins()
        self.shuttle = ProjectMux()
        self.uio_oe_pico = Port()
        self.mode = RPMode.SAFE

    @property
    def mode(self):
        return self._mode

    @mode.setter
    def mode(self, mode):
        """No DIP switches here, so the host port's ui pins are outputs in RP control."""
        self._mode = mode
        for bit in range(3):
            pin = getattr(self.pins, "ui_in%d" % bit)
            pin.mode = Pin.OUT if mode == RPMode.ASIC_RP_CONTROL else Pin.IN

    def clock_project_PWM(self, hz):
        """No clock pin: the system clock at twice it, as the SDK sets for the PWM."""
        machine.freq(2 * hz)

    def clock_project_stop(self):
        pass

    def reset_project(self, held):
        pass


def main(clock_hz=48_000_000, say=print):
    """demo_board's transport at a sixteenth, a twelfth and an eighth of the clock, then a
    reselect, which here only runs the reload path."""
    import demo_board
    import demo_board_check as check
    import protocol_emulator as pe

    ok = True
    words = [(i * 0x9E37) & 0xFFFF for i in range(512)]
    for divide in (16, 12, 8):
        host = demo_board.host(clock_hz=clock_hz, sck_hz=clock_hz // divide)
        say("SCK %d Hz, 1/%d of the clock" % (host.spi.sck_hz, divide))
        ok = check.status(host, say) and ok
        ok = check.readback(host, say) and ok
        ok = check.clock(host, clock_hz, check.WINDOW_MS, say) and ok
        host.load(words)
        wrapped = host.read(pe.PROGRAM_ADDR)[0]
        ok = check.report(
            say, "load", wrapped == 0, "program address 0x%03x after 512 words" % wrapped) and ok
    host.spi.tt.shuttle.get("tt_um_another").enable()
    stale = not host.spi.selected()
    reloaded = host.ensure()
    ok = check.report(
        say, "reselect", stale and reloaded and host.spi.selected(),
        "stale %s, reloaded %s" % (stale, reloaded)) and ok
    ok = check.status(host, say) and ok
    say("PASS" if ok else "FAIL")
    return ok
