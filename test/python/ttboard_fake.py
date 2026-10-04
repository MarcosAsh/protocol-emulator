# SPDX-License-Identifier: Apache-2.0
# The demo board's RP2 under CPython: the machine, rp2, micropython, time and ttboard calls
# python/demo_board.py and demo_board_check.py make, a PIO interpreter and the pads. Names
# follow tt-micropython-firmware v3.1.1 and MicroPython's rp2 module. A chip backend has
# run(board, ticks, stop), which elapses each wait board.events yields, drive and pads.

import collections
import importlib
import sys
import types
from fractions import Fraction

# GPIOs of ui_in, uo_out and uio, the system clock at boot, and whether a PIO has a GPIO
# base: the RP2350B DB v3 of SDK v3, the RP2040 TT06 board of SDK v2
BOARDS = {
    "dbv3": (range(17, 25), range(33, 41), range(25, 33), 150_000_000, True),
    "tt06": ([9, 10, 11, 12, 17, 18, 19, 20], [5, 6, 7, 8, 13, 14, 15, 16], range(21, 29),
             125_000_000, False),
}
# what a MicroPython call costs, roughly, so time passes between pin moves
CALL_US = 2
# a blocking call that waits this long on a fake would hang the real board
HANG_S = Fraction(1, 50)
FIFO = 4
# MicroPython's rp2.PIO and machine.Pin constants
OUT_LOW, OUT_HIGH, SHIFT_LEFT, SHIFT_RIGHT = 2, 3, 0, 1
IN, OUT, PULL_UP, PULL_DOWN = 0, 1, 1, 2


class Instr:
    def __init__(self, op, *args):
        self.op, self.args, self.sideset, self.delay = op, args, None, 0

    def side(self, value):
        self.sideset = value
        return self

    def __getitem__(self, delay):
        self.delay = delay
        return self


class Program:
    """What @rp2.asm_pio makes: the body run once with the assembler's names as globals."""

    def __init__(self, body, config):
        self.code, self.labels, self.config = [], {}, config
        self.wrap_target, self.wrap = 0, None

        def emit(op):
            return lambda *args: self.code.append(Instr(op, *args)) or self.code[-1]

        names = {op: emit(op) for op in ("out", "set", "jmp", "wait", "nop", "pull", "push", "mov")}
        names["in_"] = emit("in")
        names["label"] = lambda name: self.labels.__setitem__(name, len(self.code))
        names["wrap_target"] = lambda: setattr(self, "wrap_target", len(self.code))
        names["wrap"] = lambda: setattr(self, "wrap", len(self.code) - 1)
        for name in ("pins", "x", "y", "osr", "isr", "null", "pin", "gpio", "pindirs", "x_dec",
                     "y_dec", "not_x", "not_y", "x_not_y", "not_osre"):
            names[name] = name
        types.FunctionType(body.__code__, names)()
        if self.wrap is None:
            self.wrap = len(self.code) - 1


def asm_pio(**config):
    return lambda body: Program(body, config)


class StateMachine:
    """One PIO state machine, a cycle per step. A side-set lands after the instruction's
    reads, as the input synchronisers have it, and on every stalled cycle too."""

    def __init__(self, board, number):
        self.board, self.number, self.pio = board, number, board.pios[number // 4]
        self.running, self.program = False, None
        self.tx, self.rx = collections.deque(), collections.deque()

    def init(self, program, freq, in_base=None, out_base=None, set_base=None,
             sideset_base=None, jmp_pin=None):
        board, config = self.board, program.config
        self.program, self.config = program, config
        self.in_base = in_base and in_base.id
        self.jmp_pin = jmp_pin and jmp_pin.id
        self.outs = {}
        for kind, base in (("out", out_base), ("set", set_base), ("sideset", sideset_base)):
            init = config.get(kind + "_init")
            if base is None:
                continue
            count = len(init) if isinstance(init, tuple) else 1
            self.outs[kind] = (base.id, count)
            if init is not None:
                for i, value in enumerate(init if isinstance(init, tuple) else (init,)):
                    board.claim(base.id + i, self.pio, value & 1)
        for gpio in [self.in_base] + [b + c - 1 for b, c in self.outs.values()]:
            if gpio is not None and not 0 <= gpio - self.pio.base < 32:
                raise ValueError("GPIO %d not within gpio_base range" % gpio)
        self.pio.loaded = True
        self.div = int(board.sys_hz * 256 / freq)
        assert self.div >= 256, "freq above the system clock"
        self.pc, self.x, self.y, self.delay = 0, 0, 0, 0
        self.osr, self.osr_count, self.isr, self.isr_count = 0, 32, 0, 0
        self.tx.clear()
        self.rx.clear()
        self.blocked = False

    # the steps fall at origin + floor(k * div / 256) ticks, as the fractional divider has them
    def _align(self):
        k = -(-((self.board.ticks - self.origin) * 256) // self.div)
        self.k = k
        self.next_at = self.origin + k * self.div // 256

    def active(self, value=None):
        if value is None:
            return int(self.running)
        self.running = bool(value) and self.program is not None
        if self.running:
            self.origin = self.board.ticks
            self._align()

    def _wake(self):
        if self.blocked:
            self.blocked = False
            self._align()

    def put(self, value, shift=0):
        self.board.call()
        for word in value if hasattr(value, "__len__") else [value]:
            self.board.wait(lambda: len(self.tx) < FIFO)
            self.tx.append((word << shift) & 0xFFFFFFFF)
            self._wake()

    def get(self, buf=None, shift=0):
        self.board.call()
        for i in range(len(buf) if buf is not None else 1):
            self.board.wait(lambda: self.rx)
            value = self.rx.popleft() >> shift
            self._wake()
            if buf is None:
                return value
            buf[i] = value & 0xFF
        return buf

    def rx_fifo(self):
        self.board.call()
        return len(self.rx)

    def tx_fifo(self):
        self.board.call()
        return len(self.tx)

    def _pins(self, kind, value, count):
        base, _ = self.outs[kind]
        for i in range(count):
            self.board.pio_level(base + i, (value >> i) & 1)

    def step(self):
        self.k += 1
        self.next_at = self.origin + self.k * self.div // 256
        if self.delay:
            self.delay -= 1
            return
        instr = self.program.code[self.pc]
        jumped = self._execute(instr)
        if instr.sideset is not None:
            self._pins("sideset", instr.sideset, self.outs["sideset"][1])
        if jumped is None:
            return
        self.delay = instr.delay
        if jumped is not True:
            self.pc = self.program.wrap_target if self.pc == self.program.wrap else self.pc + 1

    def _execute(self, instr):
        """False when done, True when it jumped, None when it stalled."""
        config, op, args = self.config, instr.op, instr.args
        if op == "out":
            dest, n = args
            if config.get("autopull") and self.osr_count >= config.get("pull_thresh", 32):
                if not self.tx:
                    self.blocked = True
                    return None
                self.osr, self.osr_count = self.tx.popleft(), 0
            mask = (1 << n) - 1
            if config.get("out_shiftdir", SHIFT_RIGHT) == SHIFT_LEFT:
                value = (self.osr >> (32 - n)) & mask
                self.osr = (self.osr << n) & 0xFFFFFFFF
            else:
                value = self.osr & mask
                self.osr >>= n
            self.osr_count += n
            assert dest == "pins", dest
            self._pins("out", value, n)
        elif op == "in":
            src, n = args
            assert src == "pins", src
            bits = sum(self.board.level(self.in_base + i) << i for i in range(n))
            if config.get("in_shiftdir", SHIFT_RIGHT) == SHIFT_LEFT:
                isr = ((self.isr << n) | bits) & 0xFFFFFFFF
            else:
                isr = (self.isr >> n) | (bits << (32 - n))
            count = self.isr_count + n
            if config.get("autopush") and count >= config.get("push_thresh", 32):
                if len(self.rx) >= FIFO:
                    self.blocked = True
                    return None
                self.rx.append(isr)
                isr, count = 0, 0
            self.isr, self.isr_count = isr, count
        elif op == "set":
            dest, value = args
            if dest == "pins":
                self._pins("set", value, self.outs["set"][1])
            else:
                setattr(self, dest, value)
        elif op == "wait":
            polarity, src, index = args
            gpio = self.in_base + index if src == "pin" else self.pio.base + index
            if self.board.level(gpio) != polarity:
                return None
        elif op == "jmp":
            cond, label = args if len(args) == 2 else (None, args[0])
            take = {
                None: True, "not_x": not self.x, "not_y": not self.y, "x_dec": self.x != 0,
                "y_dec": self.y != 0, "x_not_y": self.x != self.y,
                "pin": self.jmp_pin is not None and self.board.level(self.jmp_pin) == 1,
            }[cond]
            if cond == "x_dec":
                self.x = (self.x - 1) & 0xFFFFFFFF
            if cond == "y_dec":
                self.y = (self.y - 1) & 0xFFFFFFFF
            if take:
                self.pc = self.program.labels[label]
                return True
        else:
            assert op == "nop", op
        return False


class Pio:
    def __init__(self, board, index):
        self.board, self.index, self.base, self.loaded = board, index, 0, False

    def remove_program(self, program=None):
        self.loaded = False

    def gpio_base(self, pin=None):
        """Only with no program loaded, as the pico-sdk refuses it otherwise."""
        if pin is not None:
            if pin.id not in (0, 16):
                raise ValueError("invalid GPIO base")
            if self.loaded:
                raise OSError(22)
            self.base = pin.id
        return self.base


class Pin:
    """machine.Pin. Init takes the pad back from a PIO, as gpio_set_function does; a
    bare Pin(n) changes nothing, as MicroPython's does."""

    IN, OUT, PULL_UP, PULL_DOWN = IN, OUT, PULL_UP, PULL_DOWN
    board = None

    def __init__(self, id, mode=None, pull=None, value=None):
        self.id = id
        if mode is not None or value is not None:
            self.init(mode, pull, value)

    def init(self, mode=None, pull=None, value=None):
        board = self.board
        board.pio_pins.pop(self.id, None)
        if value is not None:
            board.sio[self.id] = value
        if mode == OUT:
            board.outputs.add(self.id)
        elif mode == IN:
            board.outputs.discard(self.id)

    def value(self, value=None):
        self.board.call()
        if value is None:
            return self.board.level(self.id, cached=True)
        self.board.sio[self.id] = 1 if value else 0

    __call__ = value


class Port:
    """ttboard's VerilogIOPort: value packs or unpacks its eight pads."""

    def __init__(self, board, gpios, writable=False):
        self.board, self.gpios, self.writable = board, list(gpios), writable

    @property
    def value(self):
        self.board.call()
        return sum(self.board.level(g, cached=True) << i for i, g in enumerate(self.gpios))

    @value.setter
    def value(self, byte):
        self.board.call()
        if self.writable:
            for i, g in enumerate(self.gpios):
                self.board.sio[g] = (byte >> i) & 1


class DemoBoard:
    """The SDK calls demo_board makes. Enable starts info.yaml's clock, as a project with
    no config.ini section gets; RP control turns the DB v3.3 button's monitor on."""

    def __init__(self, board):
        self.board = board
        self.pins = types.SimpleNamespace()
        # StandardPin's GPIO and direction
        for port, gpios in (("ui_in", board.ui), ("uo_out", board.uo)):
            for i, g in enumerate(gpios):
                setattr(self.pins, "%s%d" % (port, i), types.SimpleNamespace(gpio_num=g, mode=IN))
        self.ui_in = Port(board, board.ui, writable=True)
        self.uo_out = Port(board, board.uo)
        self.uio_out = Port(board, board.uio)
        self.uio_oe_pico = types.SimpleNamespace(value=0xFF)
        self.manual_project_clock = None
        if board.kind == "dbv3":
            self.manual_project_clock = types.SimpleNamespace(monitoring=False)
        self.shuttle = Shuttle(board)
        self._mode = 0

    @property
    def mode(self):
        return self._mode

    @mode.setter
    def mode(self, mode):
        """ui pads become RP outputs, but not one a DIP switch holds high."""
        board = self.board
        board.note("mode", mode)
        if mode != self._mode:
            board.clock_hz = 0
        self._mode = mode
        for i, g in enumerate(board.ui):
            pin = getattr(self.pins, "ui_in%d" % i)
            high = mode == 1 and (board.switches >> i) & 1
            pin.mode = OUT if mode == 1 and not high else IN
            Pin(g, pin.mode, value=0)
        if self.manual_project_clock is not None:
            self.manual_project_clock.monitoring = mode == 1

    def clock_project_PWM(self, hz):
        self.board.set_clock(hz)

    def clock_project_stop(self):
        self.board.set_clock(0)

    def reset_project(self, held):
        self.board.call()
        self.board.note("reset", held)
        self.board.rst_n = 0 if held else 1


class Design:
    def __init__(self, board, name):
        self.board, self.name = board, name

    def enable(self):
        board = self.board
        board.note("enable", self.name)
        board.enabled = self.name
        board.set_clock(50_000_000)


class Shuttle:
    def __init__(self, board):
        self.board = board

    def has(self, name):
        return name in self.board.projects

    def get(self, name):
        return Design(self.board, name)


class Board:
    """Pads, time and PIO. The system clock is the largest multiple of twice the PWM's
    under 133 MHz, as the SDK finds when it divides exactly. CPU reads see the pads as the
    last run left them, so a chip in another thread is only touched inside run."""

    def __init__(self, chip, kind="dbv3", switches=0,
                 projects=("tt_um_marcosash_protocol_emulator",)):
        self.chip, self.kind, self.switches, self.projects = chip, kind, switches, projects
        ui, uo, uio, self.sys_hz, self.has_gpio_base = BOARDS[kind]
        self.ui, self.uo, self.uio = list(ui), list(uo), list(uio)
        self.ticks, self.before = 0, Fraction(0)
        self.sio, self.outputs, self.pio_pins, self.pio_levels = {}, set(), {}, {}
        self.pios = [Pio(self, n) for n in range(3 if self.has_gpio_base else 2)]
        self.sms = {}
        self.clock_hz, self.rst_n, self.enabled = 0, 1, None
        self.pads = (0, 0)
        self.driven = None
        self.log, self.trace = [], []

    def seconds(self):
        return self.before + Fraction(self.ticks, self.sys_hz)

    def note(self, what, value):
        self.log.append((self.seconds(), what, value))

    def set_clock(self, hz):
        self.call()
        self.note("clock", hz)
        if hz:
            sys_hz = 2 * hz if 2 * hz > 133_000_000 else 133_000_000 // (2 * hz) * 2 * hz
            self.before, self.ticks, self.sys_hz = self.seconds(), 0, sys_hz
            # a running state machine keeps its divider, so its rate moves with the clock
            for sm in self.sms.values():
                if sm.running:
                    sm.origin = 0
                    sm._align()
        self.clock_hz = hz

    # pads
    def claim(self, gpio, pio, level):
        self.pio_pins[gpio] = pio
        self.pio_levels[gpio] = level

    def pio_level(self, gpio, level):
        if gpio in self.pio_pins:
            self.pio_levels[gpio] = level

    def level(self, gpio, cached=False):
        if gpio in self.pio_pins:
            return self.pio_levels[gpio]
        if gpio in self.outputs:
            return self.sio.get(gpio, 0)
        if gpio in self.uo:
            uo = self.pads[0] if cached else self.chip.pads()[0]
            return (uo >> self.uo.index(gpio)) & 1
        if gpio in self.uio:
            uio = self.pads[1] if cached else self.chip.pads()[1]
            return (uio >> self.uio.index(gpio)) & 1
        if gpio in self.ui:
            return (self.switches >> self.ui.index(gpio)) & 1
        return 0

    def ui_byte(self):
        return sum(self.level(g) << i for i, g in enumerate(self.ui))

    def sync(self):
        driven = (self.ui_byte(), self.rst_n)
        if driven != self.driven:
            self.driven = driven
            self.trace.append((self.seconds(), driven[0]))
            self.chip.drive(*driven)

    # time
    def events(self, ticks, stop=None):
        """Each wait for the chip to elapse, with the PIO stepped between, until ticks pass
        or stop() holds. Pads go to the chip first and come back last."""
        end = self.ticks + ticks
        self.sync()
        while self.ticks < end and not (stop and stop()):
            due = [sm.next_at for sm in self.sms.values() if sm.running and not sm.blocked]
            at = min(due + [end])
            yield at - self.ticks
            self.ticks = at
            for sm in self.sms.values():
                if sm.running and not sm.blocked and sm.next_at == at:
                    sm.step()
            self.sync()
        self.pads = self.chip.pads()

    def spend(self, us):
        self.chip.run(self, us * self.sys_hz // 1_000_000)

    def call(self):
        self.spend(CALL_US)

    def wait(self, ready):
        if not ready():
            self.chip.run(self, int(HANG_S * self.sys_hz), ready)
            if not ready():
                raise TimeoutError("the board would hang here")

    def install(self):
        """machine, rp2, micropython and ttboard in sys.modules, and demo_board and
        demo_board_check imported fresh with this board's time."""
        board = self
        Pin.board = board
        tt = DemoBoard(board)

        def state_machine(number, program=None, freq=None, **pins):
            sm = board.sms.setdefault(number, StateMachine(board, number))
            if program is not None:
                sm.init(program, freq, **pins)
            return sm

        def pio(index):
            pio = board.pios[index]
            if not board.has_gpio_base:
                return types.SimpleNamespace(remove_program=pio.remove_program)
            return pio

        rp2 = types.ModuleType("rp2")
        rp2.asm_pio, rp2.StateMachine, rp2.PIO = asm_pio, state_machine, pio
        for name, value in (("OUT_LOW", OUT_LOW), ("OUT_HIGH", OUT_HIGH),
                            ("SHIFT_LEFT", SHIFT_LEFT), ("SHIFT_RIGHT", SHIFT_RIGHT)):
            setattr(pio, name, value)
        machine = types.ModuleType("machine")
        machine.Pin, machine.freq = Pin, lambda hz=None: board.sys_hz
        micropython = types.ModuleType("micropython")
        micropython.native = lambda f: f
        ttboard = types.ModuleType("ttboard")
        demoboard = types.ModuleType("ttboard.demoboard")
        demoboard.DemoBoard = types.SimpleNamespace(get=lambda: tt)
        mode = types.ModuleType("ttboard.mode")
        mode.RPMode = types.SimpleNamespace(SAFE=0, ASIC_RP_CONTROL=1, ASIC_MANUAL_INPUTS=2)
        self.saved = {name: sys.modules.get(name) for name in MODULES}
        sys.modules.update({
            "rp2": rp2, "machine": machine, "micropython": micropython, "ttboard": ttboard,
            "ttboard.demoboard": demoboard, "ttboard.mode": mode,
        })
        for name in ("demo_board", "demo_board_check"):
            sys.modules.pop(name, None)
        clock = types.SimpleNamespace(
            ticks_us=lambda: board.call() or int(board.seconds() * 1_000_000),
            ticks_ms=lambda: board.call() or int(board.seconds() * 1_000),
            ticks_diff=lambda a, b: a - b, ticks_add=lambda a, b: a + b,
            sleep_ms=lambda ms: board.spend(1000 * ms), sleep_us=board.spend,
        )
        loaded = types.SimpleNamespace(tt=tt)
        for name in ("demo_board", "demo_board_check"):
            module = importlib.import_module(name)
            module.time = clock
            setattr(loaded, name, module)
        return loaded

    def uninstall(self):
        for name, module in self.saved.items():
            if module is None:
                sys.modules.pop(name, None)
            else:
                sys.modules[name] = module


MODULES = ("rp2", "machine", "micropython", "ttboard", "ttboard.demoboard", "ttboard.mode",
           "demo_board", "demo_board_check")


def run_sync(chip, board, ticks, stop=None):
    """A chip backend's run, when elapse needs no await."""
    for wait in board.events(ticks, stop):
        if wait:
            chip.elapse(board, wait)
