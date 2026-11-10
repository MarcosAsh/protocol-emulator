# SPDX-License-Identifier: Apache-2.0
# A finger thermometer (MicroPython, Pico A). Engine 0 reads the DS18B20 on IO4 as the
# 1-Wire master while engine 1 drives the NeoPixel stick on OUT3. The stick lights one more
# pixel, blue through to red, for each half degree above the first reading.
# demo/thermometer.sh runs it.

import bench
import bench_firmware
import demo_ds18b20 as sensor
import demo_neopixel as stick
import protocol_emulator as pe

PIXELS = 8
OFF = (0, 0, 0)
# sixteenths of a degree a pixel
STEP = 8
WRITE_SCRATCHPAD = 0x4E
# 10 bits, a quarter degree in 187.5 ms, and the power-on 12
FAST = 0x3F
SLOW = 0x7F


def colour(n):
    """Blue at the first pixel, green in the middle, red at the last."""
    top = PIXELS - 1
    return (0x20 * n // top, 0x20 - 0x20 * abs(2 * n - top) // top, 0x20 * (top - n) // top)


def bar(raw, base):
    """One pixel at the first reading and one more for each STEP above it. The next one up
    is lit by how far into its step the reading is."""
    above = max(0, raw - base)
    lit = min(PIXELS, 1 + above // STEP)
    frame = [colour(n) for n in range(lit)]
    if lit < PIXELS:
        frame.append(tuple(c * (above % STEP) // STEP for c in colour(lit)))
    return frame + [OFF] * (PIXELS - len(frame))


def fit(host, firmware, engine):
    """Loads engine without stopping the other, which bench.load would."""
    host.select(engine)
    host.configure(firmware["config"])
    host.load(firmware["words"])
    host.certify(firmware["certificate"], loaded=firmware["loaded"], floor=firmware["floor"],
                 single_edge=firmware["single_edge"])


class Thermometer:
    def __init__(self, transfer, pause_ms):
        self.host = pe.Host(transfer)
        self.pause_ms = pause_ms
        bench.load(self.host, bench_firmware.SK6812, 1)
        fit(self.host, bench_firmware.ONE_WIRE, 0)
        self.host.select(1)
        self.host.start()
        self.host.select(0)
        self.host.start()
        # the unit comes first and is not answered
        self.host.push([sensor.UNIT])
        self.wire = sensor.Wire(self.host)

    def scratchpad(self):
        self.wire.reset()
        self.wire.write([sensor.SKIP_ROM, sensor.READ_SCRATCHPAD])
        pad = self.wire.read(9)
        return pad if sensor.crc8(pad) == 0 and any(pad) else None

    def resolution(self, config):
        """Sets the conversion's bits and keeps the alarm bytes. False if nothing answers."""
        pad = self.scratchpad()
        if pad is None:
            return False
        self.wire.reset()
        self.wire.write([sensor.SKIP_ROM, WRITE_SCRATCHPAD, pad[2], pad[3], config])
        return True

    def read(self):
        """Converts and returns sixteenths of a degree, or None on a bad CRC."""
        self.wire.reset()
        self.wire.write([sensor.SKIP_ROM, sensor.CONVERT_T])
        for _ in range(sensor.POLLS):
            if self.wire.read(1)[0]:
                break
        pad = self.scratchpad()
        return None if pad is None else sensor.temperature(pad)

    def show(self, frame):
        self.host.select(1)
        self.host.push(stick.words(frame))
        self.host.select(0)
        self.pause_ms(stick.LATCH_MS)

    def faults(self):
        found = []
        for engine in (1, 0):
            self.host.select(engine)
            found.append(bench.faults(self.host))
        return found


def run(transfer, pause_ms, ticks_ms, seconds, log=print):
    t = Thermometer(transfer, pause_ms)
    if not t.resolution(FAST):
        log("no DS18B20 answers on DQ")
        return False
    base = bad = readings = 0
    start = ticks_ms()
    while ticks_ms() - start < seconds * 1000:
        raw = t.read()
        if raw is None:
            bad += 1
            continue
        if not readings:
            base = raw
        readings += 1
        frame = bar(raw, base)
        t.show(frame)
        log("%7.2f C  %+5.2f  %s" % (raw / 16, (raw - base) / 16,
                                    "#" * sum(1 for p in frame if p != OFF)))
    t.show([OFF] * PIXELS)
    t.resolution(SLOW)
    found = t.faults()
    log("%d readings, %d with a bad CRC, faults 0x%x 0x%x" % (readings, bad, found[1], found[0]))
    return readings > 0 and not bad and not any(found)


def main(seconds=60):
    import time

    import pico_board

    # the stick needs this rate and the 1-Wire master takes any
    spi = pico_board.PicoSpi(baudrate=stick.SPI_HZ)
    print("hold the DS18B20 between two fingers")
    ok = run(spi.transfer, time.sleep_ms, time.ticks_ms, seconds)
    print("PASS" if ok else "FAIL")
