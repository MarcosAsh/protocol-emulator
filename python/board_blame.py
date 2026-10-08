# SPDX-License-Identifier: Apache-2.0
# The board-blame meter (CPython and MicroPython). Engine 0 runs test/i2c_master_marked,
# whose every SCL release is a proved cycle it copies onto wire 20; engine 1 runs
# test/scl_rise and pushes, per release, the cycles until the SCL pad reads high. What is
# left after the chip's own fixed latency is the pull-up charging the bus: the board.

import math

from protocol_emulator import DEFAULT_CONFIG

SCL = 18  # IO6, uio[6]
SDA = 19  # IO7, uio[7]
QUARTER = 30  # set p, 30 in the firmware: 400 kHz at 48 MHz

MASTER_CONFIG = dict(
    DEFAULT_CONFIG, side_set_count=1, side_set_base=SCL, side_set_pindirs=1, in_base=SDA,
    out_base=SDA, out_count=1, set_base=SDA, set_count=2, in_shift_right=0, out_shift_right=0,
)
METER_CONFIG = dict(DEFAULT_CONFIG, capture_pin=SCL, capture_rising=1, autopush=1)

# What a line that rises at once reads: the pad's synchroniser less the issue [mov x, now]
# waits after the wire. Measured in RTL simulation (test/test_board_blame.py).
ZERO_LOAD = 1

# The high time is two quarters; a rise that takes longer is not seen before SCL is
# driven low again.
HIGH = 2 * QUARTER

# rise time limits, 30 % to 70 % of VDD, from the I2C specification (UM10204 table 10)
LIMITS_NS = {"standard": 1000, "fast": 300, "fast_plus": 120}


def i2c_word(data, start=False, read=False, stop=False):
    return (int(start) << 15) | (int(read) << 14) | (data << 6) | (int(stop) << 5)


def releases(asm):
    """{pc: edge} from the '; release: edge' comments of i2c_master_marked.asm."""
    names, pc = {}, 0
    for line in asm.split("\n"):
        code, _, comment = line.partition(";")
        code = code.strip()
        if not code or code.endswith(":") or code.startswith("."):
            continue
        comment = comment.strip()
        if comment.startswith("release:"):
            names[pc] = comment[len("release:"):].strip()
        pc += 1
    return names


def release_pcs(words, names):
    """The pc of each SCL release the master makes for these host words, in order."""
    pc_of = {name: pc for pc, name in names.items()}
    pcs, idle = [], True
    for w in words:
        if w >> 15 & 1 and not idle:
            pcs.append(pc_of["restart"])
        if w >> 14 & 1:
            pcs += [pc_of["read bit"]] * 8 + [pc_of["ack or nack we send"]]
        else:
            pcs += [pc_of["write bit"]] * 8 + [pc_of["ack"]]
        idle = bool(w >> 5 & 1)
        if idle:
            pcs.append(pc_of["stop"])
    return pcs


def verdict(cycles, clock_hz=48_000_000, mode="fast", threshold=0.5, pull_up=None):
    """One release, from engine 1's word. [cycles] counts sync flop samples, so the pad
    crossed the input threshold in [n, n + 1) cycles after the release, n = cycles less
    ZERO_LOAD; in silicon metastability can add one more at the low end. The 30-70 % rise
    time and R C follow from an exponential charge through [threshold] (VIH / VDD), which
    is the part not proved."""
    period = 1e9 / clock_hz
    n = cycles - ZERO_LOAD
    v = {"cycles": cycles, "n": n, "limit_ns": LIMITS_NS[mode]}
    if n < 0 or n >= HIGH:
        v.update(rose=False, board=True)
        return v
    low, high = n * period, (n + 1) * period
    rc = (low + high) / 2 / -math.log(1 - threshold)
    v.update(
        rose=True, low_ns=low, high_ns=high, rc_ns=rc, tr_ns=rc * math.log(7 / 3),
        board=rc * math.log(7 / 3) > LIMITS_NS[mode],
    )
    if pull_up:
        v["bus_pf"] = rc / pull_up * 1000
    return v


def describe(pc, edge, v):
    where = f"SCL release at pc {pc} ({edge})"
    if not v["rose"]:
        return f"{where}: no rise within the high time; board"
    text = (
        f"{where}: threshold at {v['low_ns']:.0f}-{v['high_ns']:.0f} ns,"
        f" tr ~{v['tr_ns']:.0f} ns"
    )
    if "bus_pf" in v:
        text += f", bus ~{v['bus_pf']:.0f} pF"
    if v["board"]:
        text += f" > {v['limit_ns']} ns; firmware proved, so the board"
    return text


def load(host, engine, config, words, certificate):
    host.select(engine)
    host.configure(config)
    host.load(words)
    host.certify(certificate)


def start(host, master, meter):
    """master and meter are (words, certificate). Both halted for the certificates' writes;
    then engine 0 first: its first instruction releases SCL, which the meter must not see."""
    for engine in (1, 0):
        host.select(engine)
        host.stop()
    load(host, 0, MASTER_CONFIG, *master)
    load(host, 1, METER_CONFIG, *meter)
    host.select(0)
    host.start()
    host.select(1)
    host.start()


def hex_file(path):
    with open(path) as f:
        return [int(line, 16) for line in f.read().split() if line]


def run(host, words, names, tries=200, **kwargs):
    """Sends [words] to the master and, once it has pushed a word per byte, prints a line
    per release the meter measured: the first eight. Returns the verdicts."""
    host.select(0)
    host.push(words)
    for _ in range(tries):
        if host.status()["rx_level"] == len(words):
            break
    host.pop(len(words))
    host.select(1)
    stamps = host.pop(host.status()["rx_level"])
    verdicts = []
    for pc, cycles in zip(release_pcs(words, names), stamps):
        v = verdict(cycles, **kwargs)
        print(describe(pc, names[pc], v))
        verdicts.append(v)
        if not v["rose"]:
            print("the pulses after it up to the next rise have no word")
            break
    return verdicts


def pico(pull_up=47_000, mode="fast", clock_hz=48_000_000):
    """On the bare-Pico bench: the host port on GP2-5 (python/pico_board.py), and
    i2c_master_marked.asm, .hex, .cert.hex and scl_rise.hex, .cert.hex copied to the Pico."""
    import pico_board

    host = pico_board.host()
    with open("i2c_master_marked.asm") as f:
        names = releases(f.read())
    start(
        host,
        (hex_file("i2c_master_marked.hex"), hex_file("i2c_master_marked.cert.hex")),
        (hex_file("scl_rise.hex"), hex_file("scl_rise.cert.hex")),
    )
    words = [i2c_word(0xA0, start=True), i2c_word(0x5A, stop=True)]
    return run(host, words, names, clock_hz=clock_hz, mode=mode, pull_up=pull_up)
