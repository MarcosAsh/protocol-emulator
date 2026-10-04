# SPDX-License-Identifier: Apache-2.0
# One outline per block of the hardened die, from pages/die/die.bin's cells, as a pen path
# for python/demo_draw.py. Each block's cells are rasterised, blurred and traced, the
# traces simplified together to a budget of segments; the SRAM macros and the tile are
# their own rectangles. Pure Python, and the same path for the same die.bin.
import gzip
import json
import os
import struct

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIE_BIN = os.path.join(REPO, "pages", "die", "die.bin")
# the blocks that get an outline; glue is a scatter of cells all over
DRAWN = ["engine 0", "engine 1", "host FIFOs", "host port", "data memory"]
SRAM = "SRAM macros"
# a raster square's side in die.bin's steps (20 nm), the blur's radius in squares, the
# blurred cell cover a square needs to be inside a block, the smallest piece of a block
# drawn, as a share of its largest, and the least tolerance in squares, which takes the
# stairs out of a trace
GRID = 100
BLUR = 8
COVER = 0.25
PIECE = 0.2
SMOOTH = 0.75
SEGMENTS = 1500


def read(path=DIE_BIN):
    """The die's size, its cells as (x, y, w, h, block) in steps from its corner, and each
    block's colour."""
    blob = gzip.decompress(open(path, "rb").read())
    if blob[:4] != b"DIE1":
        raise ValueError("%s is not demo/live_die.py's output" % path)
    (length,) = struct.unpack_from("<I", blob, 4)
    header = json.loads(blob[8 : 8 + length])
    at = 8 + length
    at += -at % 4
    count = header["cells"]
    blocks = [name for name, _ in header["blocks"]]
    cells = [
        (*struct.unpack_from("<4H", blob, at + 8 * n), blocks[blob[at + 8 * count + n]])
        for n in range(count)
    ]
    return tuple(header["die"]), cells, dict(header["blocks"])


def raster(die, cells, grid=GRID, blur=BLUR, cover=COVER):
    """Each square's block, or None: the drawn block with the most blurred cover there,
    where every block's together reaches cover and a drawn one has some. Squares a macro
    touches stay None."""
    columns, rows = -(-die[0] // grid), -(-die[1] // grid)
    area = {name: [[0.0] * columns for _ in range(rows)] for name in DRAWN + ["all"]}
    macro = set()
    for x, y, w, h, block in cells:
        for j in range(y // grid, min(rows, -(-(y + h) // grid))):
            for i in range(x // grid, min(columns, -(-(x + w) // grid))):
                if block == SRAM:
                    macro.add((i, j))
                    continue
                dx = min(x + w, (i + 1) * grid) - max(x, i * grid)
                dy = min(y + h, (j + 1) * grid) - max(y, j * grid)
                area["all"][j][i] += dx * dy
                if block in area:
                    area[block][j][i] += dx * dy
    blurred = {name: box_blur(a, blur) for name, a in area.items()}
    square = grid * grid * (2 * blur + 1) ** 2
    labels = [[None] * columns for _ in range(rows)]
    for j in range(rows):
        for i in range(columns):
            if (i, j) in macro or blurred["all"][j][i] < cover * square:
                continue
            best = max(DRAWN, key=lambda name: blurred[name][j][i])
            labels[j][i] = best if blurred[best][j][i] > 0 else None
    return labels


def box_blur(a, r):
    """Each entry the sum of the (2r + 1) square around it, the edges read as zero."""
    rows, columns = len(a), len(a[0])
    sums = [[0.0] * (columns + 1) for _ in range(rows + 1)]
    for j in range(rows):
        for i in range(columns):
            sums[j + 1][i + 1] = a[j][i] + sums[j][i + 1] + sums[j + 1][i] - sums[j][i]

    def total(j0, i0, j1, i1):
        j0, i0, j1, i1 = max(j0, 0), max(i0, 0), min(j1, rows), min(i1, columns)
        return sums[j1][i1] - sums[j0][i1] - sums[j1][i0] + sums[j0][i0]

    return [
        [total(j - r, i - r, j + r + 1, i + r + 1) for i in range(columns)] for j in range(rows)
    ]


def pieces(labels, name, piece=PIECE):
    """name's 4-connected pieces, as sets of (i, j), the largest first, each at least piece
    of the largest and with its holes filled."""
    rows, columns = len(labels), len(labels[0])
    seen, found = set(), []
    for j in range(rows):
        for i in range(columns):
            if labels[j][i] != name or (i, j) in seen:
                continue
            part, stack = set(), [(i, j)]
            seen.add((i, j))
            while stack:
                a, b = stack.pop()
                part.add((a, b))
                for c, d in ((a + 1, b), (a - 1, b), (a, b + 1), (a, b - 1)):
                    if 0 <= c < columns and 0 <= d < rows and labels[d][c] == name:
                        if (c, d) not in seen:
                            seen.add((c, d))
                            stack.append((c, d))
            found.append(part)
    found.sort(key=lambda part: (-len(part), min(part)))
    return [fill(part) for part in found if len(part) >= piece * len(found[0])]


def fill(part):
    """part with every square the outside cannot reach, 8-connected, added."""
    i0 = min(i for i, _ in part) - 1
    i1 = max(i for i, _ in part) + 1
    j0 = min(j for _, j in part) - 1
    j1 = max(j for _, j in part) + 1
    outside, stack = {(i0, j0)}, [(i0, j0)]
    while stack:
        a, b = stack.pop()
        for c in (a - 1, a, a + 1):
            for d in (b - 1, b, b + 1):
                if i0 <= c <= i1 and j0 <= d <= j1 and (c, d) not in part:
                    if (c, d) not in outside:
                        outside.add((c, d))
                        stack.append((c, d))
    return {
        (i, j) for i in range(i0, i1 + 1) for j in range(j0, j1 + 1) if (i, j) not in outside
    }


def trace(part):
    """part's boundary as a closed list of corners, counterclockwise with y up, a corner
    only where it turns. Where two squares touch at a corner it turns left, keeping them
    apart as 4-connectivity does."""
    edges = {}
    for i, j in part:
        corners = [(i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1)]
        for n, outward in enumerate(((0, -1), (1, 0), (0, 1), (-1, 0))):
            if (i + outward[0], j + outward[1]) not in part:
                edges.setdefault(corners[n], []).append(corners[(n + 1) % 4])
    start = min(edges)
    path, at, heading = [start], start, None
    while True:
        ends = edges[at]
        if heading is None or len(ends) == 1:
            end = ends[0]
        else:
            left = (-heading[1], heading[0])
            end = next((e for e in ends if (e[0] - at[0], e[1] - at[1]) == left), ends[0])
        ends.remove(end)
        if not ends:
            del edges[at]
        heading = (end[0] - at[0], end[1] - at[1])
        at = end
        if at == start:
            break
        path.append(at)
    return [
        p for n, p in enumerate(path) if not collinear(path[n - 1], p, path[(n + 1) % len(path)])
    ]


def collinear(a, b, c):
    return (b[0] - a[0]) * (c[1] - a[1]) == (b[1] - a[1]) * (c[0] - a[0])


def simplify(ring, epsilon):
    """Douglas-Peucker on a closed ring, split at its first corner and the corner farthest
    from it. At least three corners stay."""
    if len(ring) <= 3:
        return list(ring)
    far = max(range(len(ring)), key=lambda n: distance2(ring[0], ring[n]))
    keep = {0, far}
    for first, last in ((0, far), (far, len(ring))):
        stack = [(first, last)]
        while stack:
            a, b = stack.pop()
            p, q = ring[a], ring[b % len(ring)]
            best, at = -1.0, None
            for n in range(a + 1, b):
                d = segment_distance(ring[n], p, q)
                if d > best:
                    best, at = d, n
            if at is not None and best > epsilon:
                keep.add(at)
                stack += [(a, at), (at, b)]
    kept = [ring[n] for n in sorted(keep)]
    if len(kept) < 3:
        rest = sorted(set(range(len(ring))) - keep, key=lambda n: -segment_distance(
            ring[n], ring[0], ring[far]))
        kept = [ring[n] for n in sorted(keep | {rest[0]})]
    return kept


def distance2(a, b):
    return (a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2


def segment_distance(p, a, b):
    """p's distance from the segment a b."""
    dx, dy = b[0] - a[0], b[1] - a[1]
    length2 = dx * dx + dy * dy
    t = 0.0 if length2 == 0 else ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / length2
    t = min(1.0, max(0.0, t))
    return ((p[0] - a[0] - t * dx) ** 2 + (p[1] - a[1] - t * dy) ** 2) ** 0.5


def rectangle(x, y, w, h):
    return [(x, y), (x + w, y), (x + w, y + h), (x, y + h)]


def regions(die, cells, grid=GRID, blur=BLUR):
    """(name, ring) for every drawn piece, unsimplified, in steps with y up: the tile, the
    macros, then each block's pieces."""
    found = [("tile", rectangle(0, 0, *die))]
    macros = sorted((x, y, w, h) for x, y, w, h, block in cells if block == SRAM)
    found += [(SRAM, rectangle(*m)) for m in macros]
    labels = raster(die, cells, grid, blur)
    for name in DRAWN:
        for part in pieces(labels, name):
            found.append((name, [(i * grid, j * grid) for i, j in trace(part)]))
    return found


def outlines(found, segments=SEGMENTS, grid=GRID):
    """found's traces simplified with the smallest tolerance from SMOOTH, to a hundredth of
    a square, that leaves at most segments edges in all. The rectangles stay as they are."""
    fixed = sum(len(ring) for name, ring in found if not traced(name))
    if fixed + 3 * sum(1 for name, _ in found if traced(name)) > segments:
        raise ValueError("%d segments cannot hold %d outlines" % (segments, len(found)))

    def at(epsilon):
        return [
            (name, simplify(ring, epsilon * grid) if traced(name) else ring)
            for name, ring in found
        ]

    def count(rings):
        return sum(len(ring) for _, ring in rings)

    low = high = round(SMOOTH * 100)
    while count(at(high / 100)) > segments:
        high *= 2
    while low < high:
        middle = (low + high) // 2
        if count(at(middle / 100)) <= segments:
            high = middle
        else:
            low = middle + 1
    return at(high / 100)


def traced(name):
    return name not in ("tile", SRAM)


def pen_path(rings, die, width):
    """Closed polylines in screen pixels, x right and y down from the tile's top left
    corner, the tile first from that corner, then always the nearest ring next, from its
    nearest corner. Corners that round onto the one before are dropped."""
    scale = width / die[0]

    def screen(p):
        return (round(p[0] * scale), round((die[1] - p[1]) * scale))

    todo = []
    for _, ring in rings:
        points = []
        for p in map(screen, ring):
            if not points or p != points[-1]:
                points.append(p)
        while len(points) > 1 and points[-1] == points[0]:
            points.pop()
        if len(points) >= 2:
            todo.append(points)
    strokes, pen = [], (0, 0)
    while todo:
        n, k = min(
            ((n, k) for n, ring in enumerate(todo) for k in range(len(ring))),
            key=lambda nk: (distance2(pen, todo[nk[0]][nk[1]]), nk),
        )
        ring = todo.pop(n)
        ring = ring[k:] + ring[:k]
        strokes.append(ring + [ring[0]])
        pen = ring[0]
    return strokes
