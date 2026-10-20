# SPDX-License-Identifier: Apache-2.0
# One point of a margin sweep on the bench (MicroPython, Pico A): the point's firmware from
# demo/margins.py, run REPEATS times against the part, each repeat judged by what the part
# does, beside a reference at the library's timing. Each run returns a dict of what it saw;
# demo/margins.py judges it and labels the point in spec or OUT OF SPEC. Needs bench.py,
# bench_firmware.py, protocol_emulator.py, pico_board.py and the parts' demos.

import bench
import bench_firmware
import demo_ds18b20
import demo_eeprom
import demo_neopixel
import protocol_emulator as pe

# a pixel a frame, a byte a word from the top bit: green, red, blue
WHITE = [0xFF00, 0xFF00, 0xFF00]
BLACK = [0, 0, 0]
# the stick settles in microseconds; this lets the ADC's reading settle behind it
SETTLE_MS = 20
REFERENCES = 4
# the last page, the eeprom demo's, where any write a broken read turns into lands
EEPROM_PAGE = 0x7FC0
EEPROM_DEVICE = 0x50
EEPROM_BYTES = 8
# the scratchpad bytes written: TH, TL and the configuration, both bit values in each
# byte, and every repeat the other pattern so a write that does not land shows
PATTERNS = [(0x0F, 0xF0, 0x7F), (0xF0, 0x0F, 0x1F)]
# the configuration's resolution bits, the only ones it takes
CONFIG_BITS = 0x60
SKIP_ROM = 0xCC
WRITE_SCRATCHPAD = 0x4E


def run_point(host, point):
    """Loads a point's firmware halted, so words pushed next are all in before it starts."""
    bench.load(host, point)
    if point["load"] is not None:
        host.start()
        host.push([point["load"]])


def sk6812(host, pause_ms, vsys, point, repeats, pair):
    """Each repeat a white pixel, then a black one, or with pair a white one and a black
    one back to back, each frame's words in while the core is halted, then vsys(). The
    references after, at the library's timing, also leave the stick dark."""
    lit, dark = [], []
    bench.load(host, point)
    for _ in range(repeats):
        for frame in (WHITE, WHITE + BLACK if pair else BLACK):
            host.stop()
            host.push(frame)
            host.start()
            pause_ms(SETTLE_MS)
            (lit if frame is WHITE else dark).append(vsys())
    faults = bench.faults(host)
    ref_lit, ref_dark = [], []
    for _ in range(REFERENCES):
        for pixels, into in (([(0xFF, 0xFF, 0xFF)] + [(0, 0, 0)] * 7, ref_lit),
                             ([(0, 0, 0)] * 8, ref_dark)):
            demo_neopixel.show(host, [pixels], pause_ms)
            pause_ms(SETTLE_MS)
            into.append(vsys())
    return {"lit": lit, "dark": dark, "ref_lit": ref_lit, "ref_dark": ref_dark,
            "faults": faults, "ref_faults": bench.faults(host)}


def eeprom_reference(host):
    """The page's first bytes at the eeprom demo's timing, with each ACK."""
    bench.load(host, bench_firmware.I2C_MASTER)
    host.start()
    host.push([demo_eeprom.QUARTER])
    eeprom = demo_eeprom.Eeprom(host, EEPROM_DEVICE)
    return eeprom.read(EEPROM_PAGE, EEPROM_BYTES)


def eeprom(host, pause_ms, point, words, repeats):
    """The point's words, an address probe and a random read of the page, each repeat,
    with a read at the eeprom demo's timing before and after."""
    if not demo_eeprom.bus_free(host, pause_ms):
        raise RuntimeError("Pico B is mastering the bus: load MicroPython or can_node")
    before = eeprom_reference(host)
    run_point(host, point)
    replies = []
    stopped = None
    for _ in range(repeats):
        try:
            replies.append(bench.exchange(host, words, polls=2000))
        except RuntimeError as e:
            stopped = str(e)
            break
    faults = bench.faults(host)
    after = eeprom_reference(host)
    return {"before": before, "after": after, "replies": replies, "stopped": stopped,
            "faults": faults, "ref_faults": bench.faults(host)}


def reset_word(swept):
    """Margins.Ds18b20's host words: reset[0], swept[1], byte[9:2]."""
    return 1 | (swept << 1)


def byte_word(b, swept):
    return ((b & 0xFF) << 2) | (swept << 1)


def ds18b20_reference(host):
    """The ROM and the scratchpad at the library's timing, each with its CRC."""
    bench.load(host, bench_firmware.ONE_WIRE)
    host.start()
    host.push([demo_ds18b20.UNIT])
    wire = demo_ds18b20.Wire(host)
    present = wire.reset()
    wire.write([demo_ds18b20.READ_ROM])
    rom = wire.read(8)
    wire.reset()
    wire.write([SKIP_ROM, demo_ds18b20.READ_SCRATCHPAD])
    pad = wire.read(9)
    return present, rom, pad


def ds18b20_words(kind, repeat):
    """A repeat's words, the swept timing where the point moves it: a reset then READ
    ROM, three scratchpad bytes written then read back, or READ ROM's read slots."""
    rom = [byte_word(demo_ds18b20.READ_ROM, 0)]
    if kind == "reset":
        return [reset_word(0), reset_word(1)] + rom + [byte_word(0xFF, 0)] * 8
    if kind == "write":
        written = PATTERNS[repeat % 2]
        return ([reset_word(0), byte_word(SKIP_ROM, 0), byte_word(WRITE_SCRATCHPAD, 0)]
                + [byte_word(b, 1) for b in written]
                + [reset_word(0), byte_word(SKIP_ROM, 0),
                   byte_word(demo_ds18b20.READ_SCRATCHPAD, 0)]
                + [byte_word(0xFF, 0)] * 9)
    if kind == "read":
        return [reset_word(0)] + rom + [byte_word(0xFF, 1)] * 8
    raise ValueError(kind)


def ds18b20(host, point, kind, repeats):
    """Each repeat's replies to ds18b20_words, a reference before and after, and the
    scratchpad put back as the reference found it."""
    before = ds18b20_reference(host)
    run_point(host, point)
    replies = []
    stopped = None
    for repeat in range(repeats):
        try:
            replies.append(bench.exchange(host, ds18b20_words(kind, repeat), polls=5000))
        except RuntimeError as e:
            stopped = str(e)
            break
    faults = bench.faults(host)
    if kind == "write":
        th, tl, config = before[2][2:5]
        bench.exchange(host, [reset_word(0), byte_word(SKIP_ROM, 0),
                              byte_word(WRITE_SCRATCHPAD, 0), byte_word(th, 0),
                              byte_word(tl, 0), byte_word(config, 0)])
    after = ds18b20_reference(host)
    return {"before": before, "after": after, "replies": replies, "stopped": stopped,
            "faults": faults, "ref_faults": bench.faults(host)}


def main(part, point, repeats, kind=None, words=None, path="margins.log"):
    """On Pico A, as demo/margins.py runs it: the run's dict saved as JSON to path, or
    what stopped it."""
    import json
    import time

    import machine
    import pico_board

    adc = machine.ADC(3)

    def vsys(n=2000):
        """ADC channel 3, the Pico's VSYS divider, scaled by three as for VSYS. On Pico A
        it reads about 1.26, not VSYS; it is used only for how the stick's current moves
        it."""
        total = 0
        for _ in range(n):
            total += adc.read_u16()
        return total / n * 3 * 3.3 / 65536

    spi = pico_board.PicoSpi(baudrate=demo_neopixel.SPI_HZ)
    host = pe.Host(spi.transfer)
    time.sleep_ms(bench.START_MS)
    try:
        if part == "SK6812":
            out = sk6812(host, time.sleep_ms, vsys, point, repeats, kind == "pair")
        elif part == "24LC256":
            out = eeprom(host, time.sleep_ms, point, words, repeats)
        else:
            out = ds18b20(host, point, kind, repeats)
    except Exception as e:
        out = {"error": str(e)}
    with open(path, "w") as f:
        json.dump(out, f)
