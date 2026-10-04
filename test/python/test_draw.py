# SPDX-License-Identifier: Apache-2.0
# demo/outline.py on a small made up die and on pages/die/die.bin, python/demo_draw.py's
# reports and its queue, and demo/draw.py's replay, which must catch a clamped move.
import os
import sys
import tempfile

sys.path[:0] = sys.argv[1:3]
import demo_draw  # noqa: E402
import draw  # noqa: E402
import outline  # noqa: E402


def test_small_die():
    # an L of engine 0 beside a square of host FIFOs, a macro and a stray glue cell, on a
    # 4 x 4 step grid with no blur
    cells = [(x, y, 4, 4, "engine 0") for x, y in ((0, 0), (4, 0), (8, 0), (0, 4), (0, 8))]
    cells += [(x, y, 4, 4, "host FIFOs") for x in (12, 16) for y in (8, 12)]
    cells += [(16, 0, 4, 4, outline.SRAM), (12, 16, 4, 4, "glue")]
    found = outline.regions((20, 20), cells, grid=4, blur=0)
    assert found == [
        ("tile", [(0, 0), (20, 0), (20, 20), (0, 20)]),
        (outline.SRAM, [(16, 0), (20, 0), (20, 4), (16, 4)]),
        ("engine 0", [(0, 0), (12, 0), (12, 4), (4, 4), (4, 12), (0, 12)]),
        ("host FIFOs", [(12, 8), (20, 8), (20, 16), (12, 16)]),
    ], found
    assert found == outline.regions((20, 20), cells, grid=4, blur=0), "deterministic"
    # every corner is more than SMOOTH off a line that skips it
    assert outline.outlines(found, 18, grid=4) == found
    rings = outline.outlines(found, 16, grid=4)
    assert rings[2:] == [
        ("engine 0", [(0, 0), (12, 4), (4, 4), (0, 12)]),
        ("host FIFOs", [(12, 8), (20, 8), (20, 16), (12, 16)]),
    ], rings
    try:
        outline.outlines(found, 13, grid=4)
        raise AssertionError("four outlines in 13 segments")
    except ValueError:
        pass
    # y down, the tile from the pointer's start, then the nearest corner each time
    assert outline.pen_path(rings, (20, 20), 40) == [
        [(0, 0), (0, 40), (40, 40), (40, 0), (0, 0)],
        [(0, 16), (0, 40), (24, 32), (8, 32), (0, 16)],
        [(24, 24), (40, 24), (40, 8), (24, 8), (24, 24)],
        [(32, 32), (32, 40), (40, 40), (40, 32), (32, 32)],
    ]


def test_corner_touching_squares_stay_apart():
    # two squares touching at a corner are two pieces, and an 8-connected gap is no hole
    labels = [["engine 0", None], [None, "engine 0"]]
    assert outline.pieces(labels, "engine 0") == [{(0, 0)}, {(1, 1)}]
    ring = [["engine 0"] * 3, ["engine 0", None, "engine 0"], ["engine 0"] * 3]
    (part,) = outline.pieces(ring, "engine 0")
    assert (1, 1) in part and outline.trace(part) == [(0, 0), (3, 0), (3, 3), (0, 3)]


def test_line_splits_at_127():
    for dx, dy in ((0, 0), (127, -127), (128, 0), (-800, 3), (441, -1), (-255, -254)):
        steps = demo_draw.line(dx, dy, 1)
        moves = [(demo_draw.signed(x), demo_draw.signed(y)) for _, x, y in steps]
        assert all(max(abs(x), abs(y)) <= 127 for x, y in moves), moves
        assert (sum(x for x, _ in moves), sum(y for _, y in moves)) == (dx, dy), moves
        assert len(steps) == max(1, -(-max(abs(dx), abs(dy)) // 127))


def test_replay_catches_a_clamp():
    strokes = [[(0, 0), (300, 0), (300, 200), (0, 0)], [(10, 10), (-20, 15), (10, 10)]]
    data = demo_draw.encode(strokes, 5)
    assert data[0] == 5
    drawn, lifted, end = draw.replay(data)
    # a split move's points round to the nearest pixel
    assert draw.drift(strokes, drawn, end) <= 0.5 and end == (0, 0)
    assert lifted == [[(0, 0), (10, 10)], [(10, 10), (0, 0)]], lifted

    def clamped(dx, dy, buttons):
        return [(buttons, max(-127, min(127, dx)) & 0xFF, max(-127, min(127, dy)) & 0xFF)]

    line, demo_draw.line = demo_draw.line, clamped
    try:
        bad = demo_draw.encode(strokes, 5)
    finally:
        demo_draw.line = line
    assert draw.drift(strokes, *draw.replay(bad)[::2]) > 100


class Board:
    def __init__(self):
        self.pending_report = None


def test_reports_queue_and_stop():
    now = [0]
    data = demo_draw.encode([[(0, 0), (5, 0), (0, 0)]], 2)
    queue = demo_draw.Reports(data, lambda: now[0])
    assert not queue and len(queue) == 0
    queue.start(2000)
    queue.start(9000)
    now[0] = 1999
    assert not queue
    now[0] = 2000
    assert len(queue) == 4
    press = queue.pop(0)
    assert press == [2, 1, 0, 0] and queue.held == 1
    # a bus reset puts it back, ahead of the rest
    queue.insert(0, press)
    assert queue.pop(0) == press and len(queue) == 3
    assert queue.pop(0) == [2, 1, 5, 0]

    board, ctrl_c = Board(), [False]
    check = demo_draw.stopping(lambda: False, board, queue, lambda: ctrl_c[0], lambda: now[0])
    assert check() is False
    ctrl_c[0] = True
    now[0] += demo_draw.POLL_MS
    board.pending_report = [2, 1, 5, 0]
    assert check() is False and queue.pop(0) == [2, 0, 0, 0] and not queue
    assert check() is False, "stopped with a report out"
    board.pending_report = None
    try:
        check()
        raise AssertionError("not stopped")
    except demo_draw.Stopped as stopped:
        assert stopped.args == (True,)

    # nothing held: nothing more is sent, and a report never taken stops it anyway
    queue = demo_draw.Reports(data, lambda: now[0])
    queue.start(0)
    queue.stop()
    assert not queue
    board.pending_report = [2, 0, 1, 0]
    check = demo_draw.stopping(lambda: False, board, queue, lambda: True, lambda: now[0])
    check()
    now[0] += demo_draw.RELEASE_MS + 1
    try:
        check()
        raise AssertionError("not stopped")
    except demo_draw.Stopped as stopped:
        assert stopped.args == (False,)


def test_the_die():
    die, cells, colours = outline.read()
    found = outline.regions(die, cells)
    assert [name for name, _ in found].count(outline.SRAM) == 3
    assert {name for name, _ in found} == set(outline.DRAWN) | {"tile", outline.SRAM}
    rings = outline.outlines(found)
    strokes = outline.pen_path(rings, die, 800)
    data = demo_draw.encode(strokes, 10)
    drawn, lifted, end = draw.replay(data)
    summary = (len(strokes), sum(len(s) - 1 for s in strokes), (len(data) - 1) // 3)
    assert summary == (13, 1492, 1562), summary
    assert draw.drift(strokes, drawn, end) <= 0.5
    with tempfile.TemporaryDirectory() as out:
        png, svg = os.path.join(out, "draw.png"), os.path.join(out, "draw.svg")
        draw.render(die, cells, colours, found, strokes, drawn, lifted, 800, png, svg)
        assert open(png, "rb").read(8) == b"\x89PNG\r\n\x1a\n"
        assert open(svg).read().count("<polyline") == 2 * len(strokes) + len(lifted)


test_small_die()
test_corner_touching_squares_stay_apart()
test_line_splits_at_127()
test_replay_catches_a_clamp()
test_reports_queue_and_stop()
test_the_die()
