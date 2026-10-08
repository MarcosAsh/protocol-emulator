# SPDX-License-Identifier: Apache-2.0
# Act 3's mouse draws the die: demo/outline.py's pen path as HID mouse reports, which the
# chip sends from python/demo_draw.py on Pico A. Renders the reports as a flat-profile host
# adds them up, beside the die, and fails if that strays from the path. Ctrl-C releases.
# Usage: python3 demo/draw.py --dry-run [--out DIR]        render and check only
#        python3 demo/draw.py --pico id:<serial of Pico A>  the bench, after BRINGUP's act 3
import argparse
import math
import os
import struct
import subprocess
import sys
import tempfile
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
sys.path[:0] = [HERE, os.path.join(REPO, "python")]
import demo_draw  # noqa: E402
import outline  # noqa: E402

# the endpoint's bInterval, demo_usb.CONFIGURATION's last byte
POLL_MS = 10
# what Pico A needs beside draw.bin
PICO_FILES = [
    "python/protocol_emulator.py",
    "python/pico_board.py",
    "python/usb_board.py",
    "python/usb_device_firmware.py",
    "python/demo_usb.py",
    "python/demo_draw.py",
    "test/uart_tx_host_rate.hex",
    "test/uart_tx_host_rate.cert.hex",
]
# said when Pico A cannot tell how its run ended
UNKNOWN = ("no word from Pico A on the button: if it is still down, unplug the Icepi's first"
           " USB port")
# the chip's vendor and product, which name its input devices on Linux
DEVICE = "1209:0001"
MARGIN = 12
INK = (11, 11, 11)
PLANNED = (250, 190, 190)
LIFTED = (195, 194, 188)
SILICON = (236, 234, 228)
SURFACE = (252, 252, 251)


def replay(data):
    """What a host with a flat pointer profile makes of draw.bin from (0, 0): the polylines
    drawn with the button held, the moves with it up, and where the pointer ends."""
    x = y = held = 0
    drawn, lifted = [], []
    for at in range(1, len(data), 3):
        buttons, dx, dy = data[at : at + 3]
        if dx == 0x80 or dy == 0x80:
            raise ValueError("report %d moves -128, past the descriptor's -127" % (at // 3))
        nx, ny = x + demo_draw.signed(dx), y + demo_draw.signed(dy)
        if buttons & 1 and not held:
            drawn.append([(nx, ny)])
        elif buttons & 1:
            drawn[-1].append((nx, ny))
        elif (nx, ny) != (x, y):
            lifted.append([(x, y), (nx, ny)])
        x, y, held = nx, ny, buttons & 1
    return drawn, lifted, (x, y)


def polyline_distance(p, line):
    return min(outline.segment_distance(p, a, b) for a, b in zip(line, line[1:]))


def drift(strokes, drawn, end):
    """The farthest, in pixels, a drawn point is from its stroke or a stroke's corner from
    the drawing, or the pointer ends from where it began."""
    if len(drawn) != len(strokes):
        return math.inf
    worst = math.hypot(*end)
    for stroke, line in zip(strokes, drawn):
        line = line if len(line) > 1 else line * 2
        worst = max(worst, max(polyline_distance(p, stroke) for p in line))
        worst = max(worst, max(polyline_distance(p, line) for p in stroke))
    return worst


class Canvas:
    def __init__(self, width, height):
        self.width, self.height = width, height
        self.pixels = bytearray(bytes(SURFACE) * (width * height))

    def rect(self, x0, y0, x1, y1, colour):
        x0, y0 = max(0, int(x0)), max(0, int(y0))
        x1, y1 = min(self.width, int(math.ceil(x1))), min(self.height, int(math.ceil(y1)))
        row = bytes(colour) * max(0, x1 - x0)
        for y in range(y0, y1):
            at = 3 * (y * self.width + x0)
            self.pixels[at : at + len(row)] = row

    def line(self, a, b, colour, weight=1):
        """Bresenham's, with a square pen weight pixels wide."""
        (x0, y0), (x1, y1) = (tuple(map(round, p)) for p in (a, b))
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx, sy = (1 if x1 > x0 else -1), (1 if y1 > y0 else -1)
        error = dx + dy
        half = (weight - 1) // 2
        while True:
            self.rect(x0 - half, y0 - half, x0 - half + weight, y0 - half + weight, colour)
            if (x0, y0) == (x1, y1):
                return
            e2 = 2 * error
            if e2 >= dy:
                error += dy
                x0 += sx
            if e2 <= dx:
                error += dx
                y0 += sy

    def png(self, path):
        def chunk(kind, body):
            return struct.pack(">I", len(body)) + kind + body + struct.pack(
                ">I", zlib.crc32(kind + body))

        stride = 3 * self.width
        raw = b"".join(
            b"\0" + bytes(self.pixels[y * stride : (y + 1) * stride]) for y in range(self.height)
        )
        with open(path, "wb") as f:
            f.write(b"\x89PNG\r\n\x1a\n")
            f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", self.width, self.height, 8, 2, 0, 0, 0)))
            f.write(chunk(b"IDAT", zlib.compress(raw, 9)))
            f.write(chunk(b"IEND", b""))


def rgb(colour):
    return tuple(int(colour[i : i + 2], 16) for i in (1, 3, 5))


def render(die, cells, colours, found, strokes, drawn, lifted, width, png, svg):
    """Left the die, every cell in its block's colour under the outlines before simplifying,
    right the pen path pale under what the host draws, and the moves between in grey."""
    scale = width / die[0]
    height = round(die[1] * scale)
    panel = width + 2 * MARGIN

    def screen(p):
        return (MARGIN + p[0] * scale, MARGIN + (die[1] - p[1]) * scale)

    canvas = Canvas(2 * panel, height + 2 * MARGIN)
    canvas.rect(MARGIN, MARGIN, MARGIN + width, MARGIN + height, SILICON)
    for x, y, w, h, block in cells:
        (x0, y1), (x1, y0) = screen((x, y)), screen((x + w, y + h))
        canvas.rect(x0, y0, max(x1, x0 + 1), max(y1, y0 + 1), rgb(colours[block]))
    for _, ring in found:
        for a, b in zip(ring, ring[1:] + ring[:1]):
            canvas.line(screen(a), screen(b), INK)
    for stroke in strokes:
        for a, b in zip(stroke, stroke[1:]):
            canvas.line(*((panel + MARGIN + x, MARGIN + y) for x, y in (a, b)), PLANNED, 3)
    for a, b in lifted:
        canvas.line(*((panel + MARGIN + x, MARGIN + y) for x, y in (a, b)), LIFTED)
    for line in drawn:
        for a, b in zip(line, line[1:]):
            canvas.line(*((panel + MARGIN + x, MARGIN + y) for x, y in (a, b)), INK)
    canvas.png(png)

    def points(line, dx=0):
        return " ".join("%g,%g" % (round(x + dx, 2), round(y, 2)) for x, y in line)

    def colour(c):
        return "#%02x%02x%02x" % c

    body = ['<rect x="%d" y="%d" width="%d" height="%d" fill="%s"/>'
            % (MARGIN, MARGIN, width, height, colour(SILICON))]
    for name, ring in found:
        body.append('<polygon points="%s" fill="none" stroke="%s" stroke-width="1.5"/>'
                    % (points(map(screen, ring)),
                       colours.get(name, colour(INK)) if outline.traced(name) else colour(INK)))
    for stroke in strokes:
        body.append('<polyline points="%s" fill="none" stroke="%s" stroke-width="3"/>'
                    % (points(stroke, panel + MARGIN), colour(PLANNED)))
    for line in lifted:
        body.append('<polyline points="%s" fill="none" stroke="%s" stroke-dasharray="3 3"/>'
                    % (points(line, panel + MARGIN), colour(LIFTED)))
    for line in drawn:
        body.append('<polyline points="%s" fill="none" stroke="%s"/>'
                    % (points(line, panel + MARGIN), colour(INK)))
    with open(svg, "w") as f:
        f.write('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d">\n'
                % (2 * panel, height + 2 * MARGIN))
        f.write('<rect width="100%%" height="100%%" fill="%s"/>\n' % colour(SURFACE))
        f.write("\n".join(body) + "\n</svg>\n")


def gsetting(key):
    try:
        return subprocess.run(
            ["gsettings", "get", "org.gnome.desktop.peripherals.mouse", key],
            capture_output=True, text=True, check=True).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return None


def flat_profile():
    """The commands that make the chip's pointer flat, and undo it, for X11 and GNOME."""
    ids = ("$(xinput list | sed -n 's/.*%s.*id=\\([0-9]*\\).*slave  pointer.*/\\1/p')"
           % DEVICE)
    xinput = "for id in %s; do xinput set-prop $id 'libinput Accel Profile Enabled' %%s;" \
        " xinput set-prop $id 'libinput Accel Speed' 0; done" % ids
    gnome = "gsettings set org.gnome.desktop.peripherals.mouse"
    profile, speed = gsetting("accel-profile") or "'default'", gsetting("speed") or "0.0"
    return [
        "Pointer acceleration must be flat, or the drawing comes out bent.",
        "X11, once the chip has enumerated (a replug forgets it):",
        "  " + xinput % "0 1 0",
        "  restore: " + xinput % "1 0 0",
        "GNOME:",
        "  %s accel-profile 'flat'; %s speed 0" % (gnome, gnome),
        "  restore: %s accel-profile %s; %s speed %s" % (gnome, profile, gnome, speed),
    ]


def bench(pico, path):
    """Copies Pico A's files and runs demo_draw there. A Ctrl-C here ends mpremote but not
    the Pico's script, so a second mpremote sends the Ctrl-C that releases the button. It
    drops what the Pico prints meanwhile, so the outcome is read back from `ended`."""
    mpremote = ["mpremote", "connect", pico]
    files = [os.path.join(REPO, f) for f in PICO_FILES] + [path]
    subprocess.run(mpremote + ["cp"] + files + [":"], check=True)
    try:
        subprocess.run(mpremote + ["run", os.path.join(REPO, "python", "demo_draw.py")])
    except KeyboardInterrupt:
        print("\nreleasing the button")
        # resume keeps the run's globals until the read back, then the soft reset as before
        read_back = "print(globals().get('ended', %r))" % UNKNOWN
        if subprocess.run(mpremote + ["resume", "exec", read_back, "soft-reset"]).returncode:
            print(UNKNOWN)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--pico", help="Pico A, as mpremote connect takes it")
    parser.add_argument("--dry-run", action="store_true", help="render and check, no bench")
    parser.add_argument("--segments", type=int, default=outline.SEGMENTS)
    parser.add_argument("--width", type=int, default=800, help="the drawing's width in pixels")
    parser.add_argument("--wait", type=int, default=10, help="seconds from enumeration")
    parser.add_argument("--tolerance", type=float, default=2, help="pixels of drift allowed")
    parser.add_argument("--die", default=outline.DIE_BIN)
    parser.add_argument("--out", default=os.path.join(tempfile.gettempdir(), "draw"))
    args = parser.parse_args()
    if not args.dry_run and not args.pico:
        parser.error("--pico id:<serial of Pico A>, or --dry-run")
    if not 0 <= args.wait <= 255:
        parser.error("--wait is a byte of seconds")

    print("\n".join(flat_profile()))
    die, cells, colours = outline.read(args.die)
    found = outline.regions(die, cells)
    try:
        rings = outline.outlines(found, args.segments)
    except ValueError as e:
        sys.exit(str(e))
    strokes = outline.pen_path(rings, die, args.width)
    data = demo_draw.encode(strokes, args.wait)
    drawn, lifted, end = replay(data)
    worst = drift(strokes, drawn, end)

    os.makedirs(args.out, exist_ok=True)
    path, png, svg = (os.path.join(args.out, "draw" + e) for e in (".bin", ".png", ".svg"))
    with open(path, "wb") as f:
        f.write(data)
    render(die, cells, colours, found, strokes, drawn, lifted, args.width, png, svg)

    segments = sum(len(stroke) - 1 for stroke in strokes)
    reports = (len(data) - 1) // 3
    height = max(y for stroke in strokes for _, y in stroke)
    print("%d outlines, %d segments, %d reports, drift %.2f px" % (
        len(strokes), segments, reports, worst))
    print("%.1f s at a report each %d ms poll, after %d s from enumeration" % (
        reports * POLL_MS / 1000, POLL_MS, args.wait))
    print("a %d x %d px drawing from the pointer's start, its top left corner" % (
        args.width + 1, height + 1))
    print("rendered %s and %s" % (png, svg))
    if worst > args.tolerance:
        sys.exit("the host would draw %.2f px off the path, past %g" % (worst, args.tolerance))
    if args.dry_run:
        return
    print("Pico B prints each report engine 1 logs, its buttons, dx and dy:")
    print("  mpremote connect id:<B> exec 'import pico_listener; pico_listener.listen()'")
    bench(args.pico, path)


if __name__ == "__main__":
    main()
