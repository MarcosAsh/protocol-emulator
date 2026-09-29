# SPDX-License-Identifier: Apache-2.0
# Draws every edge of a logic analyser capture against the interval the analyser proved
# for it. Rows come from `generate.exe assemble -rows`; each edge's phase there is to the
# deadline t, which moves only by p within a frame, so its offset from the frame's first
# edge is the sum of those moves plus the two phases. Assumes an idle-high line whose
# frames start with a falling edge, as a UART's do.
# Usage: uv run demo/overlay.py edges CAPTURE --rows ROWS --frame 6,9*8,12 -o out.png
#        uv run demo/overlay.py histogram CAPTURE --rows ROWS --frame 6,9*8,12 -o out.png
#        uv run demo/overlay.py compare CAPTURE --rows ROWS --frame 6,9*8,12 \
#            --against PICO.sr --baud 9600 -o out.png
#
# /// script
# dependencies = ["matplotlib", "numpy"]
# ///
import argparse
import re

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402

import sigrok  # noqa: E402

SURFACE = "#1a1a19"
TEXT = "#ffffff"
MUTED = "#c3c2b7"
GRID = "#3a3a38"
CHIP = "#3987e5"
PICO = "#d95926"
PROOF = "#199e70"

ROW = re.compile(r"^\s*(\d+)\s+(.*?)\s+phase (\S+)(.*)$")


def interval(text):
    lo, _, hi = text.partition("..")
    hi = hi or lo
    if "?" in (lo, hi):
        return None
    return int(lo), int(hi)


def read_rows(path):
    rows = {}
    for line in open(path):
        m = ROW.match(line)
        if not m:
            continue
        pc, instruction, _phase, rest = m.groups()
        edge = re.search(r"  edge (\S+)", rest)
        rows[int(pc)] = (instruction, interval(edge.group(1)) if edge else None)
    return rows


def parse_frame(text):
    pcs = []
    for part in text.split(","):
        pc, _, times = part.partition("*")
        pcs += [int(pc)] * int(times or 1)
    return pcs


def moves_t(instruction):
    """How many periods an instruction moves the deadline by."""
    if instruction == "add t, p" or instruction.startswith("wait t+"):
        return 1
    if re.match(r"(mov|add|sub|set) t\b", instruction) or instruction.startswith("mov t,"):
        raise ValueError("%r moves t other than by p inside the frame" % instruction)
    return 0


def next_pc(rows, pc, want):
    """Where control goes from pc on the way to want: a conditional jump back is taken
    while want lies in the loop it closes."""
    m = re.match(r"jmp (?:(.*), )?(\d+)$", rows[pc][0])
    if not m:
        return pc + 1
    target = int(m.group(2))
    if m.group(1) is None or target <= want <= pc:
        return target
    return pc + 1


def predicted(rows, frame, period):
    """Each frame edge's offset from the first, as a cycle interval."""
    moved = [0]
    for a, b in zip(frame, frame[1:]):
        pc, n = a, 0
        for _ in range(10_000):
            n += moves_t(rows[pc][0]) if pc != a else 0
            pc = next_pc(rows, pc, b)
            if pc == b:
                break
        else:
            raise ValueError("no way from pc %d to pc %d" % (a, b))
        moved.append(moved[-1] + n)
    edges = []
    for pc in frame:
        if rows[pc][1] is None:
            raise ValueError("pc %d has no bounded edge in the rows" % pc)
        edges.append(rows[pc][1])
    lo0, hi0 = edges[0]
    return [(m * period + lo - hi0, m * period + hi - lo0) for m, (lo, hi) in zip(moved, edges)]


def period_of(rows):
    for instruction, _ in rows.values():
        m = re.match(r"set p, (\d+)$", instruction)
        if m:
            return int(m.group(1))
    raise ValueError("the rows set no period; pass --period")


def residuals(path, channel, slots_ns):
    """Per frame, each edge's slot and its distance from the slot's centre in ns."""
    rate, names, samples = sigrok.read(path)
    bit = {name: b for b, name in names.items()}[channel]
    at, level = sigrok.edges(samples, bit)
    t_ns = at / rate * 1e9
    centres = np.array([(lo + hi) / 2 for lo, hi in slots_ns])
    window = centres[-1] + (centres[-1] - centres[-2]) / 2
    slot, off = [], []
    i = 0
    while i < len(t_ns):
        if level[i] != 0:
            i += 1
            continue
        start = t_ns[i]
        j = i
        while j < len(t_ns) and t_ns[j] - start < window:
            d = t_ns[j] - start
            k = int(np.argmin(np.abs(centres - d)))
            slot.append(k)
            off.append(d - centres[k])
            j += 1
        i = j
    return rate, np.array(slot), np.array(off)


def style(ax):
    ax.set_facecolor(SURFACE)
    ax.tick_params(colors=MUTED, labelsize=13)
    for side in ("top", "right"):
        ax.spines[side].set_visible(False)
    for side in ("left", "bottom"):
        ax.spines[side].set_color(GRID)
    ax.grid(color=GRID, linewidth=0.8)
    ax.set_axisbelow(True)


def figure(title, subtitle, rows=1):
    fig, axes = plt.subplots(rows, 1, figsize=(16, 9), dpi=120, sharex=True, squeeze=False)
    fig.patch.set_facecolor(SURFACE)
    fig.text(0.06, 0.94, title, color=TEXT, fontsize=26, weight="bold")
    fig.text(0.06, 0.905, subtitle, color=MUTED, fontsize=14)
    for ax in axes[:, 0]:
        style(ax)
    fig.subplots_adjust(left=0.08, right=0.92, top=0.82, bottom=0.1, hspace=0.3)
    return fig, axes[:, 0]


def slot_names(n):
    if n == 10:
        return ["start", "b0", "b1", "b2", "b3", "b4", "b5", "b6", "b7", "stop"]
    return [str(k) for k in range(n)]


def chip(args):
    rows = read_rows(args.rows)
    period = args.period or period_of(rows)
    cycle_ns = 1e3 / args.clock_mhz
    slots = predicted(rows, parse_frame(args.frame), period)
    slots_ns = [(lo * cycle_ns, hi * cycle_ns) for lo, hi in slots]
    rate, slot, off = residuals(args.capture, args.channel, slots_ns)
    return period, cycle_ns, slots_ns, rate, slot, off


def describe(args, period, rate, frames):
    source = "simulated capture" if args.simulated else "capture"
    return (
        "%s, %d cycles a bit at %g MHz  ·  %d frames, %s at %g MHz (one sample is %.1f ns, %.1f cycles)"
        % (
            args.name,
            period,
            args.clock_mhz,
            frames,
            source,
            rate / 1e6,
            1e9 / rate,
            args.clock_mhz * 1e6 / rate,
        )
    )


def cycles_axis(ax, cycle_ns, which="y"):
    """The same axis in core cycles, on the far side."""
    convert = (lambda ns: ns / cycle_ns, lambda c: c * cycle_ns)
    if which == "y":
        extra = ax.secondary_yaxis("right", functions=convert)
        extra.set_ylabel("core cycles", color=MUTED, fontsize=13)
    else:
        extra = ax.secondary_xaxis("top", functions=convert)
        extra.set_xlabel("core cycles", color=MUTED, fontsize=13)
    extra.tick_params(colors=MUTED, labelsize=12)
    for spine in extra.spines.values():
        spine.set_color(GRID)


def plot_edges(args):
    period, cycle_ns, slots_ns, rate, slot, off = chip(args)
    frames = int(np.sum(slot == 0))
    sample_ns = 1e9 / rate
    fig, (ax,) = figure("Every edge inside its proof", describe(args, period, rate, frames))
    n = len(slots_ns)
    centres = [(lo + hi) / 2 for lo, hi in slots_ns]
    for k, (lo, hi) in enumerate(slots_ns):
        ax.add_patch(
            plt.Rectangle(
                (k - 0.4, -sample_ns),
                0.8,
                2 * sample_ns + hi - lo,
                color=MUTED,
                alpha=0.12,
                linewidth=0,
            )
        )
        floor = 0.05 * sample_ns
        ax.add_patch(
            plt.Rectangle(
                (k - 0.4, lo - centres[k] - floor),
                0.8,
                hi - lo + 2 * floor,
                facecolor="none",
                edgecolor=PROOF,
                linewidth=2.5,
                zorder=4,
            )
        )
    rng = np.random.default_rng(0)
    jitter = rng.uniform(-0.3, 0.3, len(slot))
    ax.scatter(slot + jitter, off, s=18, color=CHIP, alpha=0.35, linewidths=0, zorder=3)
    ax.set_xticks(range(n), slot_names(n))
    ax.set_xlim(-0.6, n - 0.4)
    span = max(3 * sample_ns, np.max(np.abs(off)) * 1.3 if len(off) else 0)
    ax.set_ylim(-span, span)
    ax.set_ylabel("measured - proved edge time (ns)", color=MUTED, fontsize=14)
    cycles_axis(ax, cycle_ns)
    exact = all(hi == lo for lo, hi in slots_ns)
    proof = "proved: exactly on the cycle" if exact else "proved interval"
    ax.text(
        n - 0.45,
        0.2 * sample_ns,
        proof,
        color=PROOF,
        fontsize=14,
        ha="right",
        va="bottom",
        weight="bold",
    )
    ax.text(
        n - 0.45,
        -sample_ns * 0.95,
        "analyser resolution: ±1 sample",
        color=MUTED,
        fontsize=13,
        ha="right",
        va="bottom",
    )
    fig.savefig(args.output, facecolor=SURFACE)


def bins_for(off, sample_ns):
    lo = np.floor(np.min(off) / sample_ns) - 1
    hi = np.ceil(np.max(off) / sample_ns) + 2
    return (np.arange(lo, hi) - 0.5) * sample_ns


def plot_histogram(args):
    period, cycle_ns, slots_ns, rate, slot, off = chip(args)
    sample_ns = 1e9 / rate
    frames = int(np.sum(slot == 0))
    fig, (ax,) = figure("Every edge in one bin", describe(args, period, rate, frames))
    counts, edges, _ = ax.hist(off, bins=bins_for(off, sample_ns), color=CHIP, rwidth=0.9)
    ax.set_xlabel(
        "measured - proved edge time (ns), bins one analyser sample wide", color=MUTED, fontsize=14
    )
    ax.set_ylabel("edges", color=MUTED, fontsize=14)
    # every slot's proved interval about its centre, as one band
    half = max(hi - lo for lo, hi in slots_ns) / 2 + 0.02 * sample_ns
    ax.axvspan(-half, half, color=PROOF, alpha=0.9)
    most = int(np.max(counts))
    note = "%d edges, %d in one bin" % (len(off), most)
    if most < len(off):
        note += "\n%d a sample off: the analyser's clock is not the chip's" % (len(off) - most)
    ax.text(0.98, 0.9, note, color=TEXT, fontsize=15, ha="right", va="top", transform=ax.transAxes)
    cycles_axis(ax, cycle_ns, "x")
    fig.savefig(args.output, facecolor=SURFACE)


def plot_compare(args):
    period, cycle_ns, slots_ns, rate, slot, off = chip(args)
    bit_ns = 1e9 / args.baud
    pico_rate, pico_slot, pico_off = residuals(
        args.against, args.against_channel, [(k * bit_ns, k * bit_ns) for k in range(10)]
    )
    sample_ns = 1e9 / min(rate, pico_rate)
    fig, (top, bottom) = figure(
        "The same analyser, the same bins",
        "edge time less where the frame puts it, bins one analyser sample (%.1f ns) wide"
        % sample_ns,
        rows=2,
    )
    both = np.concatenate([off, pico_off]) / 1e3
    bins = bins_for(both * 1e3, sample_ns) / 1e3
    for ax, data, color, label in (
        (
            top,
            off / 1e3,
            CHIP,
            "%s on the chip%s, %d cycles a bit at %g MHz, certified: %d edges, spread %.0f ns"
            % (
                args.name,
                " (simulated)" if args.simulated else "",
                period,
                args.clock_mhz,
                len(off),
                np.ptp(off),
            ),
        ),
        (
            bottom,
            pico_off / 1e3,
            PICO,
            "MicroPython on a Pico, %d baud from a ticks_us deadline loop: %d edges, spread %.1f us"
            % (args.baud, len(pico_off), np.ptp(pico_off) / 1e3),
        ),
    ):
        ax.hist(data, bins=bins, color=color)
        ax.set_title(label, color=TEXT, fontsize=15, loc="left")
    chip_counts, _ = np.histogram(off / 1e3, bins)
    top.annotate(
        "%d of %d edges in one bin" % (np.max(chip_counts), len(off)),
        xy=(bins[np.argmax(chip_counts) + 1], np.max(chip_counts) * 0.9),
        xytext=(0.15, 0.7),
        textcoords="axes fraction",
        color=TEXT,
        fontsize=15,
        arrowprops=dict(arrowstyle="->", color=MUTED, linewidth=1.5),
    )
    bottom.set_xlabel("us", color=MUTED, fontsize=14)
    fig.savefig(args.output, facecolor=SURFACE)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=["edges", "histogram", "compare"])
    parser.add_argument("capture", help="sigrok .sr of the chip's pin")
    parser.add_argument("--rows", required=True, help="output of generate.exe assemble -rows")
    parser.add_argument(
        "--frame", required=True, help="the pcs of a frame's pin writes, like 6,9*8,12"
    )
    parser.add_argument("--name", default="uart_tx")
    parser.add_argument("--period", type=int, help="cycles a bit, when the rows do not set p")
    parser.add_argument("--clock-mhz", type=float, default=48.0)
    parser.add_argument("--channel", default="D4", help="OUT0 is D4, OUT1 D5")
    parser.add_argument("--simulated", action="store_true", help="say so on the plot")
    parser.add_argument("--against", help="sigrok .sr of the comparison")
    parser.add_argument("--against-channel", default="D4")
    parser.add_argument("--baud", type=float, default=9600)
    parser.add_argument("-o", "--output", required=True, help=".png or .svg")
    args = parser.parse_args()
    if args.mode == "compare" and not args.against:
        parser.error("compare needs --against")
    {"edges": plot_edges, "histogram": plot_histogram, "compare": plot_compare}[args.mode](args)


if __name__ == "__main__":
    main()
