# Draws the carrier board's surprised cat in Metal4 over the hardened design.
#
# Same face as the carrier PCB silkscreen (~/.local/share/protocol-emulator/pcb/carrier/gen.py),
# rasterised on a 0.25 um grid so every edge is Manhattan. Pixels within CLEARANCE of
# existing Metal4 are dropped, so the stripes cut through the art and nothing shorts.
# Usage: python3 die_art.py IN.gds OUT.gds --box X0 Y0 X1 Y1
import argparse
import math

import klayout.db as kdb

# Cat geometry in mm, origin top left, y down: the head is 15 x 9.2 and the whiskers
# reach 1.6 past each side.
HEAD = [(1.2, 7.2), (2.4, 8.3), (4.2, 8.85), (7.5, 9.05), (10.8, 8.85), (12.6, 8.3), (13.8, 7.2),
        (14.4, 5.6), (14.3, 4.0), (13.6, 2.6), (12.6, 0.25), (10.2, 1.85), (7.5, 1.55), (4.8, 1.85),
        (2.4, 0.25), (1.4, 2.6), (0.7, 4.0), (0.6, 5.6), (1.2, 7.2)]
FILLED = [[(2.65, 1.05), (4.05, 2.15), (2.15, 2.75)],
          [(12.35, 1.05), (10.95, 2.15), (12.85, 2.75)],
          [(6.95, 5.7), (8.05, 5.7), (7.5, 6.3)]]
EYES = [(4.9, 4.3), (10.1, 4.3)]
EYE_R, PUPIL_R = 1.5, 0.6
MOUTH, MOUTH_R = (7.5, 7.4), 0.55
WHISKERS = [((3.4, 6.2), (-1.5, 5.5)), ((3.4, 6.75), (-1.6, 6.85)), ((3.4, 7.3), (-1.3, 8.1)),
            ((11.6, 6.2), (16.5, 5.5)), ((11.6, 6.75), (16.6, 6.85)), ((11.6, 7.3), (16.3, 8.1))]
HEAD_W, RING_W, WHISKER_W = 0.3, 0.25, 0.2
X_MIN, X_MAX, Y_MIN, Y_MAX = -1.75, 16.75, 0.0, 9.25

METAL4 = (50, 0)
PIXEL = 0.25
CLEARANCE = 1.0
# Mn.a is 0.20 and Mn.e 0.24: open and close by more than half of each.
MIN_FEATURE = 0.3


def segment_distance(p, a, b):
    (px, py), (ax, ay), (bx, by) = p, a, b
    dx, dy = bx - ax, by - ay
    t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
    return math.hypot(px - ax - t * dx, py - ay - t * dy)


def in_triangle(p, tri):
    (px, py), ((ax, ay), (bx, by), (cx, cy)) = p, tri
    d1 = (px - bx) * (ay - by) - (ax - bx) * (py - by)
    d2 = (px - cx) * (by - cy) - (bx - cx) * (py - cy)
    d3 = (px - ax) * (cy - ay) - (cx - ax) * (py - ay)
    negative = d1 < 0 or d2 < 0 or d3 < 0
    positive = d1 > 0 or d2 > 0 or d3 > 0
    return not (negative and positive)


def inked(p):
    strokes = [(a, b, HEAD_W) for a, b in zip(HEAD, HEAD[1:])]
    strokes += [(a, b, WHISKER_W) for a, b in WHISKERS]
    if any(segment_distance(p, a, b) <= w / 2 for a, b, w in strokes):
        return True
    if any(in_triangle(p, tri) for tri in FILLED):
        return True
    for (cx, cy), r in [(e, EYE_R) for e in EYES] + [(MOUTH, MOUTH_R)]:
        if abs(math.hypot(p[0] - cx, p[1] - cy) - r) <= RING_W / 2:
            return True
    return any(math.hypot(p[0] - cx, p[1] - cy) <= PUPIL_R for cx, cy in EYES)


def cat(box, dbu):
    """The cat scaled to fit [box] (um), centred, as merged Manhattan polygons."""
    x0, y0, x1, y1 = box
    scale = min((x1 - x0) / (X_MAX - X_MIN), (y1 - y0) / (Y_MAX - Y_MIN))
    columns = int((X_MAX - X_MIN) * scale / PIXEL)
    rows = int((Y_MAX - Y_MIN) * scale / PIXEL)
    left = x0 + round(((x1 - x0) - columns * PIXEL) / 2 / PIXEL) * PIXEL
    bottom = y0 + round(((y1 - y0) - rows * PIXEL) / 2 / PIXEL) * PIXEL
    art = kdb.Region()
    for row in range(rows):
        y_mm = Y_MIN + (row + 0.5) * PIXEL / scale
        top = bottom + (rows - row) * PIXEL
        start = None
        for column in range(columns + 1):
            on = column < columns and inked((X_MIN + (column + 0.5) * PIXEL / scale, y_mm))
            if on and start is None:
                start = column
            elif not on and start is not None:
                art.insert(kdb.DBox(left + start * PIXEL, top - PIXEL, left + column * PIXEL, top).to_itype(dbu))
                start = None
    return art.merged()


def clean(region, dbu):
    half = int(MIN_FEATURE / 2 / dbu)
    return region.sized(half).sized(-half).sized(-half).sized(half)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("input")
    parser.add_argument("output")
    parser.add_argument("--box", type=float, nargs=4, required=True, metavar=("X0", "Y0", "X1", "Y1"))
    args = parser.parse_args()

    layout = kdb.Layout()
    layout.read(args.input)
    top = layout.top_cell()
    metal4 = layout.layer(*METAL4)
    taken = kdb.Region(top.begin_shapes_rec(metal4)).sized(int(CLEARANCE / layout.dbu))
    art = clean(clean(cat(args.box, layout.dbu), layout.dbu) - taken, layout.dbu)

    art_cell = layout.create_cell(f"{top.name}_cat")
    art_cell.shapes(metal4).insert(art)
    top.insert(kdb.CellInstArray(art_cell.cell_index(), kdb.Trans()))
    layout.write(args.output)
    print(f"die art: {art.count()} polygons, {art.area() * layout.dbu ** 2:.1f} um2 of Metal4")


if __name__ == "__main__":
    main()
