# SPDX-License-Identifier: Apache-2.0
# The self-check on the host Pico (MicroPython): engine 0 sends UART frames over wire 20,
# engine 1 checks every edge against the certificate's rows and raises its irq and halts
# at the first that leaves its cycle. Quiet over every byte value, then the same restart
# with the bit period a cycle long and a cycle short, then quiet again. The wire stays
# inside the chip, so Pico B and the analyser see nothing. Needs protocol_emulator.py,
# pico_board.py and the three .hex files on the Pico.

import protocol_emulator as pe

WIRE = 20
# The rows certify uart_tx_host_rate at 434 cycles a bit, 9 us at 48 MHz. A checked frame
# ends inside 2^14 cycles, so act 2's 5000 cannot be checked.
PERIOD = 434
# the rows' base, as test_two_engines loads them
BASE = 256
TRANSMITTER = dict(pe.DEFAULT_CONFIG, set_base=WIRE, out_base=WIRE)
# Self_check.checker_config
CHECKER = dict(
    pe.DEFAULT_CONFIG, in_base=WIRE, in_count=1, jmp_pin=WIRE, capture_pin=WIRE,
    in_shift_right=0, autopull=1, pull_threshold=16, autopull_data=1,
)
FAULTS = 0x3C
# wait 0 pin 20, as the assembler encodes it
WAIT_FALL = 0x2000 | WIRE
# uart_tx_host_rate's wait for a byte between frames
IDLE = 4
# every byte value ten times
FRAMES = 2560
# A cycle long, then a cycle short. Engine 0's own kernel accepts both, so it meets every
# deadline it is given; only the rows say 434.
GLITCHES = (PERIOD + 1, PERIOD - 1)
# its one move is the start bit's end
GLITCH_BYTE = 0xFF


def words(name):
    with open(name + ".hex") as f:
        return pe.hex_words(f.read())


def certified(rows):
    """Each write's cycle after a frame's first edge, then the least to the next frame's,
    from Self_check.rows' words: the first gap less 12, each later gap over a 1, the
    least's gap less 3 over a 0, then the base."""
    at = rows[0] + 12
    edges = [at]
    for row in rows[1:-1]:
        at += (row >> 1) if row & 1 else (row >> 1) + 3
        edges.append(at)
    return edges


def moves(byte, period):
    """The cycles after its start bit at which a frame of byte at period moves the line."""
    levels = [0] + [(byte >> i) & 1 for i in range(8)] + [1]
    return [bit * period for bit in range(1, 10) if levels[bit] != levels[bit - 1]]


def caught_by(edges, byte, period):
    """The first move off a write's cycle, and the check that must see it: the first edge
    or least at or after it, as the checker looks at the line only there."""
    for at in moves(byte, period):
        if at not in edges[:-1]:
            return at, min(e for e in edges if e >= at)
    return None


def tracking(program):
    """Where the checker waits for each frame's first edge after the first frame: its last
    wait 0 pin 20."""
    return max(pc for pc, word in enumerate(program) if word == WAIT_FALL)


def load(host, engine, config, program):
    host.select(engine)
    host.stop()
    host.flush()
    host.clear_irq()
    host.configure(config)
    host.load(program)


def setup(host, rows, program):
    """The rows in while both are halted, the checker running, the transmitter halted."""
    for engine in (0, 1):
        host.select(engine)
        host.stop()
    host.load_data(rows, BASE)
    load(host, 1, CHECKER, program)
    host.start()
    load(host, 0, TRANSMITTER, words("uart_tx_host_rate"))


def restart(host, period, data):
    """Engine 0 from its first instruction with the bit period and bytes queued, so a frame
    starts no sooner than the rows allow; only while it is idle."""
    host.stop()
    host.flush()
    host.push([period] + list(data))
    host.start()


def idle(host, pause=None, polls=10_000):
    """Returns once engine 0 has sent all it was given and waits for more, the stop bit
    over. Nothing waits on the host, so the poll need not be fast."""
    for _ in range(polls):
        s = host.read(pe.STATUS)[0]
        if s & 1:
            raise RuntimeError("engine 0 halted, status 0x%04x" % s)
        if (s >> 6) & 15 == 0 and host.read(pe.PC)[0] == IDLE:
            return
        if pause:
            pause()
    raise RuntimeError("engine 0 never went idle")


def checker(host):
    """Engine 1's status and pc, back on engine 0."""
    host.select(1)
    s = host.read(pe.STATUS)[0]
    pc = host.read(pe.PC)[0]
    host.select(0)
    return s, pc


def send(host, frames, track, pause=None, first=0):
    """Every byte value in turn from first, seven to a restart at the certified period, back
    to back within one, until a restart leaves engine 1 halted or anywhere but its wait at
    track: the frames sent, and engine 1's status and pc after the last restart."""
    sent = 0
    while sent < frames:
        data = [(first + sent + i) & 0xFF for i in range(min(7, frames - sent))]
        restart(host, PERIOD, data)
        sent += len(data)
        idle(host, pause)
        s, pc = checker(host)
        if s & 3 or pc != track:
            break
    return sent, s, pc


def quiet(host, label, frames, track, pause=None):
    """Whether frames went out with no irq, engine 1 waiting at track for the next frame
    after every restart, so it checked them all."""
    sent, s, pc = send(host, frames, track, pause)
    if s & 3:
        seen = "ALARM, engine 1 status 0x%04x pc %d" % (s, pc)
    elif pc != track:
        seen = "NOT CHECKING, engine 1 at pc %d, not its wait at %d" % (pc, track)
    else:
        seen = "no alarm"
    print("\n%s: %d frames at %d cycles a bit, %d restarts: %s" % (
        label, sent, PERIOD, (sent + 6) // 7, seen))
    return s & 3 == 0 and pc == track


def arm(host):
    """Engine 1 checking again from its first instruction with its irq clear, back on
    engine 0. Only while the line idles high."""
    host.select(1)
    host.clear_irq()
    host.start()
    host.select(0)


def glitch(host, period, pause=None):
    """Engine 1 armed afresh, so an alarm from before cannot show here, then the quiet
    restart at period with one frame: engine 1's status and pc once the frame is out."""
    arm(host)
    restart(host, period, [GLITCH_BYTE])
    idle(host, pause)
    return checker(host)


def faults(host):
    """Each engine's fault bits: underflow, overflow, missed deadline, bad decode."""
    found = []
    for engine in (0, 1):
        host.select(engine)
        found.append(host.read(pe.STATUS)[0] & FAULTS)
    host.select(0)
    return found


def begin(host, log=print):
    """The rows and the checker read from their .hex files and set up, once no fault holds
    from an earlier run: the rows, the checker, its wait at each frame and the edges."""
    found = faults(host)
    if any(found):
        raise RuntimeError("faults %s hold from an earlier run: reset the chip" % found)
    rows = words("uart_tx_host_rate_rows")
    program = words("self_check_wire")
    edges = certified(rows)
    writes = " ".join("%d" % e for e in edges[:-1])
    log("rows: writes at %s, the next frame from %d" % (writes, edges[-1]))
    setup(host, rows, program)
    return rows, program, tracking(program), edges


def run(transfer, frames=FRAMES, pause=None):
    """Quiet, each glitch, then quiet again: whether the quiet frames raised no alarm,
    every glitch raised one, and nothing faulted."""
    host = pe.Host(transfer)
    _, _, track, edges = begin(host)

    ok = quiet(host, "quiet", frames, track, pause)
    for period in GLITCHES:
        moved, check = caught_by(edges, GLITCH_BYTE, period)
        print("\nglitch: the same restart at %d: 0x%02x's start bit ends at cycle %d, not %d" % (
            period, GLITCH_BYTE, moved, PERIOD))
        s, pc = glitch(host, period, pause)
        caught = s & 3 == 3
        ok = ok and caught
        if caught:
            print("alarm: engine 1 raised its irq and halted, the rows put the catch at cycle %d"
                  % check)
        else:
            print("NO ALARM: engine 1 status 0x%04x pc %d" % (s, pc))

    # started again on a line already high, as after act 2
    arm(host)
    ok = quiet(host, "re-armed", min(frames, 256), track, pause) and ok
    found = faults(host)
    print("\nfaults %s" % found)
    return ok and not any(found)


if __name__ == "__main__":
    import pico_board

    ok = run(pico_board.PicoSpi().transfer)
    print("PASS" if ok else "FAIL")
