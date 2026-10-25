# SPDX-License-Identifier: Apache-2.0
# A capture of a bench copy held to its prediction: test/measure/predict.exe's run at the
# chip's clock, with every edge each datasheet limit bounds. Aligns the capture's first edge
# at or after --from (a trigger's sample) on the first predicted edge of that pin and level,
# matches each later edge to the nearest of its level, following the analyser's drift, then
# fits an offset and the drift. A line an edge: predicted, measured, the error, and the margin
# to each limit the edge ends. A margin within a sample either way can't tell.
# Exits 1 if a limit fails, or an edge is missing or off by more than --tolerance.
# Usage: dune exec --root . test/measure/predict.exe -- i2c_standard > i2c.predicted
#        python3 demo/hold_capture.py i2c.predicted CAPTURE.csv --rate 100M IO2=1 IO3=2 -o i2c.png
#        python3 demo/hold_capture.py uart.predicted CAPTURE.sr OUT0=D4

import argparse
import bisect
import sys

import edges
import logic_analyzer
import sigrok


class Edge:
    def __init__(self, pin, cycle, level, ns):
        self.pin, self.cycle, self.level, self.ns = pin, cycle, level, ns
        self.measured = None
        self.error = None
        self.state = "unmatched"


def read_prediction(path):
    """The firmware, the clock, each pin's first level and edges, the limits as (side, ns,
    parameter), and each limit's (edge, from) pairs as (pin, cycle)."""
    p = {"lines": {}, "limits": [], "applies": []}
    for line in open(path):
        word, _, rest = line.strip().partition(" ")
        if word == "firmware":
            p["firmware"] = rest
        elif word == "rate":
            p["rate"] = int(rest)
        elif word == "pin":
            pin, first, *at = map(int, rest.split())
            p["lines"][pin] = (first, at)
        elif word == "limit":
            _, side, ns, parameter = rest.split(" ", 3)
            p["limits"].append((side, float(ns), parameter))
        elif word == "apply":
            k, pin, at, from_pin, from_at = map(int, rest.split())
            p["applies"].append((k, (pin, at), (from_pin, from_at)))
    return p


def pin_name(pin):
    first, kind = max((first, kind) for kind, first in edges.FIRST.items() if first <= pin)
    return "%s%d" % (kind, pin - first)


def channel(names, wanted):
    """A capture channel by its name, or by its number from 1."""
    by_name = {name: bit for bit, name in names.items()}
    if wanted in by_name:
        return by_name[wanted]
    if wanted.isdigit() and 0 < int(wanted) <= len(names):
        return int(wanted) - 1
    raise SystemExit("the capture has no channel %s: it has %s" % (
        wanted, ", ".join(names[b] for b in sorted(names))))


def predicted_edges(prediction):
    cycle_ns = 1e9 / prediction["rate"]
    out = []
    for pin, (first, at) in prediction["lines"].items():
        out += [Edge(pin, c, (first + i + 1) % 2, c * cycle_ns) for i, c in enumerate(at)]
    return sorted(out, key=lambda e: (e.cycle, e.pin))


def measured_edges(samples, rate_hz, bits):
    """Each probed pin's edges as (ns, level)."""
    out = {}
    for pin, bit in bits.items():
        at, level = sigrok.edges(samples, bit)
        out[pin] = ([a * 1e9 / rate_hz for a in at], [int(v) for v in level])
    return out


def match(predicted, measured, start_ns, end_ns, window_ns=None):
    """Aligns and matches in place; returns the anchor edge and the measured edges no
    prediction took."""
    firsts = [(t[i], pin, lv[i]) for pin, (t, lv) in measured.items()
              for i in [bisect.bisect_left(t, start_ns)] if i < len(t)]
    if not firsts:
        raise SystemExit("no edge on a probed pin at or after the start")
    t0, pin0, level0 = min(firsts)
    anchor = next((e for e in predicted if e.pin == pin0 and e.level == level0), None)
    if anchor is None:
        raise SystemExit("the prediction has no %s %s to align on" % (
            pin_name(pin0), "rise" if level0 else "fall"))
    window = {}
    for pin in measured:
        times = [e.ns for e in predicted if e.pin == pin and e.cycle >= anchor.cycle]
        gaps = [b - a for a, b in zip(times, times[1:])]
        window[pin] = 0.45 * min(gaps) if gaps else 10_000.0
        if window_ns:
            window[pin] = min(window[pin], window_ns)
    used = {pin: set() for pin in measured}
    offset = t0 - anchor.ns
    for e in predicted:
        if e.pin not in measured:
            e.state = "not probed"
            continue
        if e.cycle < anchor.cycle:
            e.state = "before the anchor"
            continue
        want = e.ns + offset
        if want > end_ns:
            e.state = "after the capture"
            continue
        t, lv = measured[e.pin]
        lo = bisect.bisect_left(t, want - window[e.pin])
        hi = bisect.bisect_right(t, want + window[e.pin])
        near = [i for i in range(lo, hi) if lv[i] == e.level and i not in used[e.pin]]
        if not near:
            e.state = "missing"
            continue
        i = min(near, key=lambda i: abs(t[i] - want))
        used[e.pin].add(i)
        e.measured, e.state = t[i], "matched"
        offset = t[i] - e.ns
    last = max((e.measured for e in predicted if e.measured is not None), default=t0)
    extra = [(pin, t[i]) for pin, (t, _) in measured.items() for i in range(len(t))
             if t0 <= t[i] <= last and i not in used[pin]]
    return anchor, extra


def fit(predicted, tolerance_ns, drift=True):
    """Fits measured - predicted as an offset and, with drift, a slope over the matched
    edges, twice more without the edges off by more than tolerance_ns. Sets each edge's
    error; returns the slope in ppm and where the fit puts a predicted ns in the capture."""
    matched = [e for e in predicted if e.measured is not None]
    keep = matched
    t0 = matched[0].ns
    offset = slope = 0.0
    for _ in range(3):
        xs = [e.ns - t0 for e in keep]
        ys = [e.measured - e.ns for e in keep]
        n = len(keep)
        mx, my = sum(xs) / n, sum(ys) / n
        sxx = sum((x - mx) ** 2 for x in xs)
        slope = (sum((x - mx) * (y - my) for x, y in zip(xs, ys)) / sxx
                 if drift and sxx > 0 else 0.0)
        offset = my - slope * mx
        for e in matched:
            e.error = e.measured - e.ns - offset - slope * (e.ns - t0)
        kept = [e for e in matched if abs(e.error) <= tolerance_ns] or matched
        if len(kept) == len(keep):
            break
        keep = kept
    return slope * 1e6, lambda ns: ns + offset + slope * (ns - t0)


def verdict(margin, sample_ns):
    """As test/measured_limits.ml: within a sample either way can't tell."""
    if margin >= sample_ns:
        return "pass"
    return "fail" if margin < -sample_ns else "can't tell"


def margins(prediction, by_key, sample_ns):
    """Each application as (limit, edge, from, predicted spacing, measured spacing or None,
    margin or None, verdict)."""
    cycle_ns = 1e9 / prediction["rate"]
    out = []
    for k, edge_key, from_key in prediction["applies"]:
        side, ns, _ = prediction["limits"][k]
        edge, start = by_key.get(edge_key), by_key.get(from_key)
        predicted = (edge_key[1] - from_key[1]) * cycle_ns
        measured = margin = None
        result = "unmeasured"
        if edge and start and edge.measured is not None and start.measured is not None:
            measured = edge.measured - start.measured
            margin = measured - ns if side == ">=" else ns - measured
            result = verdict(margin, sample_ns)
        out.append((k, edge, start, predicted, measured, margin, result))
    return out


def limit_text(prediction, k):
    side, ns, parameter = prediction["limits"][k]
    return "%s %s %g" % (parameter, side, ns)


def report(prediction, predicted, applied, anchor, extra, ppm, rate_hz, tolerance_ns, name):
    sample_ns = 1e9 / rate_hz
    lines = []
    matched = [e for e in predicted if e.measured is not None]
    expected = [e for e in predicted if e.state in ("matched", "missing")]
    off = [e for e in matched if abs(e.error) > tolerance_ns]
    lines.append("%s at %g MHz against %s, %g MHz, %.2f ns a sample" % (
        prediction["firmware"], prediction["rate"] / 1e6, name, rate_hz / 1e6, sample_ns))
    lines.append("aligned on %s %s, predicted cycle %d; the analyser's clock %+.1f ppm of the "
                 "chip's, fitted with an offset" % (
                     pin_name(anchor.pin), "rise" if anchor.level else "fall",
                     anchor.cycle, ppm))
    lines.append("edges: %d of %d matched, %d missing, %d extra, %d off by more than %.1f ns"
                 % (len(matched), len(expected), len(expected) - len(matched), len(extra),
                    len(off), tolerance_ns))
    ends = {}
    for a in applied:
        if a[1] is not None:
            ends.setdefault(id(a[1]), []).append(a)
    lines.append("")
    lines.append("%5s  %-5s %-4s %8s %13s %13s %9s  margins, ns" % (
        "edge", "pin", "", "cycle", "predicted ns", "measured ns", "error ns"))
    for n, e in enumerate(expected, 1):
        flag = ""
        if e.state == "missing":
            flag = "  MISSING"
        elif abs(e.error) > tolerance_ns:
            flag = "  LATE" if e.error > 0 else "  EARLY"
        text = []
        for k, _, _, _, _, margin, result in ends.get(id(e), []):
            mark = {"fail": " FAIL", "can't tell": " ~"}.get(result, "")
            text.append("%s: %s%s" % (limit_text(prediction, k),
                                      "%+.1f" % margin if margin is not None else "-", mark))
        lines.append("%5d  %-5s %-4s %8d %13.1f %13s %9s  %s%s" % (
            n, pin_name(e.pin), "rise" if e.level else "fall", e.cycle, e.ns - anchor.ns,
            "%.1f" % (e.measured - anchor.measured) if e.measured is not None else "-",
            "%+.1f" % e.error if e.error is not None else "-", "; ".join(text) or "-", flag))
    lines.append("")
    for k in range(len(prediction["limits"])):
        mine = [a for a in applied if a[0] == k]
        got = [a for a in mine if a[5] is not None]
        if not mine:
            lines.append("  %-28s no edge in the prediction" % limit_text(prediction, k))
            continue
        if not got:
            lines.append("  %-28s %d edges, none measured" % (limit_text(prediction, k),
                                                             len(mine)))
            continue
        worst = min(got, key=lambda a: a[5])
        side = prediction["limits"][k][0]
        predicted_margin = (worst[3] - prediction["limits"][k][1] if side == ">="
                            else prediction["limits"][k][1] - worst[3])
        count = {v: sum(a[6] == v for a in got) for v in ("pass", "fail", "can't tell")}
        lines.append("  %-28s %-10s n=%-4d least margin %+.1f ns (predicted %+.1f), "
                     "fail %d, pass %d, within a sample %d" % (
                         limit_text(prediction, k),
                         "FAIL" if count["fail"] else "can't tell" if count["can't tell"]
                         else "PASS", len(got), worst[5], predicted_margin, count["fail"],
                         count["pass"], count["can't tell"]))
    return "\n".join(lines)


def zoom(ax, prediction, anchor, samples, bits, rate_hz, to_capture, centre, half, title):
    """The capture a step a sample around centre, ns, with the prediction where the fit
    puts it."""
    import overlay

    sample_ns = 1e9 / rate_hz
    cycle_ns = 1e9 / prediction["rate"]
    lo = max(0, int((centre - half) / sample_ns))
    hi = min(len(samples), int((centre + half) / sample_ns) + 1)
    xs = [i * sample_ns - anchor.measured for i in range(lo, hi)]
    for row, (pin, bit) in enumerate(sorted(bits.items())):
        base = 1.6 * row
        ys = [base + ((samples[i] >> bit) & 1) for i in range(lo, hi)]
        ax.step(xs, ys, where="post", color=overlay.CHIP, linewidth=2,
                label="measured, a step a sample" if row == 0 else None)
        ax.scatter(xs, ys, s=10, color=overlay.CHIP, zorder=3)
        first, at = prediction["lines"][pin]
        times = [to_capture(c * cycle_ns) - anchor.measured for c in at]
        level = (first + sum(t <= xs[0] for t in times)) % 2
        px, py = [xs[0]], [base + level]
        for t in times:
            if xs[0] < t < xs[-1]:
                level ^= 1
                px.append(t)
                py.append(base + level)
        px.append(xs[-1])
        py.append(py[-1])
        ax.step(px, py, where="post", color=overlay.PROOF, linewidth=2, linestyle="--",
                label="predicted, exact cycles" if row == 0 else None)
        ax.text(xs[0], base + 0.5, pin_name(pin) + " ", color=overlay.TEXT, fontsize=12,
                ha="right", va="center")
    ax.set_ylim(-0.3, 1.6 * len(bits))
    ax.set_yticks([])
    ax.set_xlabel("ns from the first edge", color=overlay.MUTED, fontsize=13)
    ax.set_title(title, color=overlay.TEXT, fontsize=14, loc="left")


def plot(path, prediction, predicted, applied, anchor, samples, bits, rate_hz, tolerance_ns,
         ppm, to_capture, name):
    """The error of every edge, and below it the capture a step a sample against the
    prediction at both ends of the spacing with the least margin."""
    import matplotlib.pyplot as plt

    import overlay

    sample_ns = 1e9 / rate_hz
    fig = plt.figure(figsize=(16, 10), dpi=120)
    grid = fig.add_gridspec(2, 2, height_ratios=[1, 1.1])
    top = fig.add_subplot(grid[0, :])
    left, right = fig.add_subplot(grid[1, 0]), fig.add_subplot(grid[1, 1])
    fig.patch.set_facecolor(overlay.SURFACE)
    fig.text(0.06, 0.95, "%s, predicted over measured" % prediction["firmware"],
             color=overlay.TEXT, fontsize=24, weight="bold")
    fig.text(0.06, 0.915, "%s at %g MHz, one sample %.1f ns  ·  analyser clock %+.1f ppm "
             "of the chip's, removed" % (name, rate_hz / 1e6, sample_ns, ppm),
             color=overlay.MUTED, fontsize=13)
    for ax in (top, left, right):
        overlay.style(ax)
    matched = [e for e in predicted if e.measured is not None]
    us = [(e.ns - anchor.ns) / 1e3 for e in matched]
    err = [e.error for e in matched]
    top.axhspan(-sample_ns, sample_ns, color=overlay.MUTED, alpha=0.15, linewidth=0)
    top.scatter(us, err, s=16, color=overlay.CHIP, linewidths=0, zorder=3,
                label="measured edge")
    off = [(u, x) for u, x in zip(us, err) if abs(x) > tolerance_ns]
    if off:
        top.scatter(*zip(*off), s=60, marker="x", color=overlay.PICO, zorder=4,
                    label="off by more than %.0f ns" % tolerance_ns)
    top.axhline(0, color=overlay.PROOF, linewidth=2, label="predicted, exact cycles")
    top.set_xlabel("us from the first edge", color=overlay.MUTED, fontsize=13)
    top.set_ylabel("measured - predicted (ns)", color=overlay.MUTED, fontsize=13)
    span = max(3 * sample_ns, max((abs(x) for x in err), default=0) * 1.2)
    top.set_ylim(-span, span)
    top.text(0.995, 0.04, "band: one sample either way", color=overlay.MUTED, fontsize=12,
             ha="right", transform=top.transAxes)
    top.legend(facecolor=overlay.SURFACE, edgecolor=overlay.GRID, labelcolor=overlay.TEXT,
               fontsize=11, loc="upper left")
    got = [a for a in applied if a[5] is not None]
    ends = [(anchor, "the first edge")] * 2
    if got:
        k, edge, start, _, measured, margin, result = min(got, key=lambda a: a[5])
        what = "%s: %.1f ns, margin %+.1f%s" % (limit_text(prediction, k), measured, margin,
                                               "  FAIL" if result == "fail" else "")
        ends = [(start, "from, " + what), (edge, "to")]
    for ax, (e, title) in zip((left, right), ends):
        half = max(30 * sample_ns, abs(e.error or 0) + 15 * sample_ns)
        zoom(ax, prediction, anchor, samples, bits, rate_hz, to_capture, e.measured, half,
             title)
    right.legend(facecolor=overlay.SURFACE, edgecolor=overlay.GRID, labelcolor=overlay.TEXT,
                 fontsize=11, loc="upper right")
    fig.subplots_adjust(left=0.07, right=0.97, top=0.87, bottom=0.07, hspace=0.35,
                        wspace=0.12)
    fig.savefig(path, facecolor=overlay.SURFACE)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("prediction", help="test/measure/predict.exe's output")
    parser.add_argument("capture", help="a LogicAnalyzer .csv or a sigrok .sr")
    parser.add_argument("probes", nargs="+", help="PIN=CHANNEL, IO2=1 or OUT0=D4")
    parser.add_argument("--rate", help="the .csv's sample rate, 100M")
    parser.add_argument("--from", dest="start", type=int, default=0,
                        help="align on the first edge at or after this sample")
    parser.add_argument("--tolerance", type=float,
                        help="ns an edge may be off, three samples by default")
    parser.add_argument("--window", type=float, help="most ns to look for an edge either way")
    parser.add_argument("--no-drift", action="store_true", help="fit an offset only")
    parser.add_argument("-o", "--output", help=".png or .svg")
    args = parser.parse_args()
    prediction = read_prediction(args.prediction)
    rate_hz, names, samples = logic_analyzer.read_any(
        args.capture, sigrok.hz(args.rate) if args.rate else None)
    bits = {}
    for probe in args.probes:
        pin, _, wanted = probe.partition("=")
        bits[edges.pin(pin)] = channel(names, wanted)
    missing = {p for _, (pin, _), (from_pin, _) in prediction["applies"]
               for p in (pin, from_pin)} - set(bits)
    if missing:
        raise SystemExit("probe %s too: the limits read it" % ", ".join(
            pin_name(p) for p in sorted(missing)))
    sample_ns = 1e9 / rate_hz
    tolerance = args.tolerance or 3 * sample_ns
    predicted = predicted_edges(prediction)
    measured = measured_edges(samples, rate_hz, bits)
    anchor, extra = match(predicted, measured, args.start * sample_ns,
                          len(samples) * sample_ns, args.window)
    ppm, to_capture = fit(predicted, tolerance, drift=not args.no_drift)
    by_key = {(e.pin, e.cycle): e for e in predicted}
    applied = margins(prediction, by_key, sample_ns)
    print(report(prediction, predicted, applied, anchor, extra, ppm, rate_hz, tolerance,
                 args.capture))
    if args.output:
        plot(args.output, prediction, predicted, applied, anchor, samples, bits, rate_hz,
             tolerance, ppm, to_capture, args.capture)
    bad = (any(a[6] == "fail" for a in applied)
           or any(e.state == "missing" for e in predicted)
           or any(e.error is not None and abs(e.error) > tolerance for e in predicted))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
