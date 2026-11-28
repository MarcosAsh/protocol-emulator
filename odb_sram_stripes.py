# Rewrite the tile Metal4 PDN over the IHP SRAM so its rails become the PDN.
#
# From WilliamZhang20/protocol-emulator, modeled on ihp-um-janestreet-prism/
# odb_stripes.py (both Apache-2.0). The 1024x8 LEF only
# declares three Metal4 PIN rectangles (VSS! / VDD! / VDDARRAY!), but the
# Metal4 OBS leaves many repeating ~3.33 um corridors on a ~5.62 um pitch —
# the same legal supply columns allocate_sram() selects on larger IHP SRAMs.
# This step:
#
#   1. Discovers those corridors from the master OBS + declared PINs, assigns
#      VPWR/VGND polarity from the known pins and the 5.62 um alternation.
#   2. Clusters them into array L / band / array R (wide OBS gaps).
#   3. Runs PRISM allocate_sram(): map crossing tile stripes → nearest legal
#      column, then complete VPWR/VGND pairs within each region.
#   4. Removes every tile stripe through the footprint and draws full-height
#      replacements on the chosen columns, with M1↔M4 rail vias outside the
#      macro; tidy() leaves one full-height box + pin per stripe x.
import click
import odb
import os
import re
from reader import click_odb


SRAM_PINS = {
    "VPWR": ("VDD!", "VDDARRAY!"),
    "VGND": ("VSS!",),
}

# IHP SRAM Metal4 supply pitch between adjacent opposite-polarity columns.
PAIR_PITCH_UM = 5.62
MACRO_NAME = "RM_IHPSG13_1P_512x16_c2_bm_bist"
HERE = os.path.dirname(os.path.abspath(__file__))
LEF_PATH = os.path.join(HERE, "macro", MACRO_NAME, f"{MACRO_NAME}.lef")


def is_sram(master):
    return (
        master.findMTerm("VDD!") is not None
        and master.findMTerm("VSS!") is not None
    )


def lef_tall_metal4_obs():
    """Master-frame (x0, x1) for tall Metal4 OBS rects, from the LEF text.

    Parsing the LEF avoids depending on odb's getObstructions() polygon
    decomposition across LibreLane / OpenROAD versions.
    """
    if not os.path.isfile(LEF_PATH):
        raise click.ClickException(f"SRAM LEF not found: {LEF_PATH}")
    text = open(LEF_PATH, encoding="utf-8", errors="replace").read()
    match = re.search(r"LAYER Metal4 SPACING.*?(?=\n\s*END)", text, re.S)
    if match is None:
        return []  # the 512x16 abstract declares every supply column as a PIN
    tall = []
    for r in re.findall(
        r"RECT\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)", match.group(0)
    ):
        x0, y0, x1, y1 = map(float, r)
        if y1 - y0 > 50.0:
            tall.append((x0, x1))
    return sorted(set(tall))


@click.command()
@click.option("--layer", default="Metal4", help="Vertical PDN layer")
@click_odb
def extend(reader, layer):
    block = reader.block
    tech = reader.tech
    m = tech.findLayer(layer)
    if m is None:
        raise click.ClickException(f"tech layer {layer} not found")
    core = block.getCoreArea()
    ylo, yhi = core.yMin(), core.yMax()
    dbu = block.getDefUnits()

    rail_vias = []
    for prefix in ("via1_2_2100_440", "via2_3_2100_440", "via3_4_2100_440"):
        found = [v for v in block.getVias() if v.getName().startswith(prefix)]
        if found:
            rail_vias.append(found[0])

    pin_xs = []
    for bterm in block.getBTerms():
        if bterm.getSigType() in ("POWER", "GROUND"):
            continue
        for bpin in bterm.getBPins():
            for box in bpin.getBoxes():
                pin_xs.append((box.xMin(), box.xMax()))

    # Kept for allocate_sram / clear_of_rails parity (no CFGMEM here).
    macro_rails = {"VPWR": [], "VGND": []}
    for inst in block.getInsts():
        master = inst.getMaster()
        if not master.isBlock() or is_sram(master):
            continue
        ox = inst.getBBox().xMin()
        for nn in ("VPWR", "VGND"):
            mterm = master.findMTerm(nn)
            if mterm is None:
                continue
            for mpin in mterm.getMPins():
                for box in mpin.getGeometry():
                    if (
                        box.getTechLayer() is not None
                        and box.getTechLayer().getName() == layer
                    ):
                        macro_rails[nn].append(
                            (ox + box.xMin(), ox + box.xMax())
                        )

    clearance = int(0.24 * dbu)
    pair_gap = int(6.5 * dbu)
    pin_margin = int(0.5 * dbu)
    pair_pitch = int(PAIR_PITCH_UM * dbu)
    full_tol = int(1.0 * dbu)
    # Corridor wider than this is a region break (wide OBS), not a pin slot.
    max_corridor_um = 4.0
    region_break_um = 8.0

    def clear_of_rails(x0, x1, nn):
        other = "VGND" if nn == "VPWR" else "VPWR"
        return all(
            x1 + clearance <= r0 or x0 - clearance >= r1
            for (r0, r1) in macro_rails[other]
        )

    def clear_of_pins(x0, x1):
        return all(
            x1 + clearance <= px0 or x0 - clearance >= px1
            for (px0, px1) in pin_xs
        )

    def is_full(b):
        return b.yMin() <= ylo + full_tol and b.yMax() >= yhi - full_tol

    def xkey(b):
        return int(((b.xMin() + b.xMax()) // 2) // (0.01 * dbu))

    def vertical_m4(boxes):
        return [
            b for b in boxes
            if b.getTechLayer() is not None
            and b.getTechLayer().getName() == layer
            and (b.yMax() - b.yMin()) > (b.xMax() - b.xMin())
        ]

    def centre(c):
        return (c[0] + c[1]) // 2

    def declared_pins(inst):
        """Die-frame PIN rectangles, keyed by net polarity."""
        master = inst.getMaster()
        ox = inst.getBBox().xMin()
        h = master.getHeight()
        out = {
            "VPWR": {"full": set(), "rest": set()},
            "VGND": {"full": set(), "rest": set()},
        }
        for pin_name in ("VDD!", "VDDARRAY!", "VSS!"):
            mterm = master.findMTerm(pin_name)
            if mterm is None:
                continue
            nn = "VGND" if pin_name == "VSS!" else "VPWR"
            for mpin in mterm.getMPins():
                for box in mpin.getGeometry():
                    if (
                        box.getTechLayer() is None
                        or box.getTechLayer().getName() != layer
                    ):
                        continue
                    c = (ox + box.xMin(), ox + box.xMax())
                    if box.yMax() - box.yMin() >= 0.9 * h:
                        out[nn]["full"].add(c)
                    else:
                        out[nn]["rest"].add(c)
        return out

    def obs_corridors(inst):
        """Die-frame (x0, x1) for each Metal4 OBS gap that looks like a pin
        corridor (~pin width), plus the declared PIN boxes themselves."""
        ox = inst.getBBox().xMin()
        obs = lef_tall_metal4_obs()  # master um
        # Declared pin width (fallback 2.81 um) for synthetic corridors.
        pin_w_um = 2.81
        for nn_pins in declared_pins(inst).values():
            for c in nn_pins["full"] | nn_pins["rest"]:
                pin_w_um = min(pin_w_um, (c[1] - c[0]) / dbu)
        pin_w = int(pin_w_um * dbu)

        corridors = set()
        for i in range(len(obs) - 1):
            g0_um, g1_um = obs[i][1], obs[i + 1][0]
            if g1_um <= g0_um:
                continue
            width_um = g1_um - g0_um
            if width_um <= 0 or width_um > max_corridor_um:
                continue
            g0, g1 = int(g0_um * dbu), int(g1_um * dbu)
            cx = (g0 + g1) // 2
            half = pin_w // 2
            c0 = max(g0 + int(0.05 * dbu), cx - half)
            c1 = min(g1 - int(0.05 * dbu), cx + half)
            if c1 - c0 < int(1.0 * dbu):
                c0, c1 = g0, g1
            corridors.add((ox + c0, ox + c1))

        for nn_pins in declared_pins(inst).values():
            corridors |= nn_pins["full"] | nn_pins["rest"]
        if len(corridors) < 6:
            raise click.ClickException(
                f"{inst.getName()}: only {len(corridors)} Metal4 corridors "
                f"from OBS+PINs; expected the repeating ~5.62 um lattice"
            )
        return sorted(corridors)

    def assign_polarity(inst, corridors):
        """Label corridors VPWR/VGND from declared pins + alternation."""
        pins = declared_pins(inst)
        known = []  # (centre, net)
        for c in pins["VGND"]["full"] | pins["VGND"]["rest"]:
            known.append((centre(c), "VGND"))
        for c in pins["VPWR"]["full"] | pins["VPWR"]["rest"]:
            known.append((centre(c), "VPWR"))
        if not known:
            raise click.ClickException(
                f"{inst.getName()}: no Metal4 power PINs to seed polarity"
            )
        known.sort()

        def polarity_of(cx):
            for kx, nn in known:
                if abs(cx - kx) <= pin_margin:
                    return nn
            kx, base = min(known, key=lambda kn: abs(kn[0] - cx))
            steps = int(round((cx - kx) / float(pair_pitch)))
            if steps % 2 == 0:
                return base
            return "VGND" if base == "VPWR" else "VPWR"

        cols = {"VPWR": {}, "VGND": {}}
        for c in corridors:
            nn = polarity_of(centre(c))
            cols[nn][c] = None  # region filled below
        return cols

    def assign_regions(cols):
        """Cluster corridors into array L / band / array R at wide gaps."""
        all_c = sorted(
            set(cols["VPWR"]) | set(cols["VGND"]), key=centre
        )
        if not all_c:
            return cols
        clusters = [[all_c[0]]]
        for c in all_c[1:]:
            if centre(c) - centre(clusters[-1][-1]) > region_break_um * dbu:
                clusters.append([c])
            else:
                clusters[-1].append(c)
        names = []
        if len(clusters) == 1:
            names = ["band"]
        elif len(clusters) == 2:
            names = ["array L", "array R"]
        else:
            # First / last are arrays; everything in between is the band
            # (matches the three OBS-separated regions of the 1024x8).
            names = (
                ["array L"]
                + ["band"] * (len(clusters) - 2)
                + ["array R"]
            )
        region_of = {}
        for name, cluster in zip(names, clusters):
            for c in cluster:
                region_of[c] = name
        for nn in cols:
            cols[nn] = {c: region_of[c] for c in cols[nn]}
        return cols

    # Legal columns per instance (die frame), for on_sram_column / allocate.
    sram_cols = {"VPWR": [], "VGND": []}
    sram_boxes = []
    sram_legal = {}  # inst name → cols dict with regions

    for inst in block.getInsts():
        master = inst.getMaster()
        if not master.isBlock() or not is_sram(master):
            continue
        ib = inst.getBBox()
        sram_boxes.append((ib.xMin(), ib.xMax()))
        corridors = obs_corridors(inst)
        cols = assign_regions(assign_polarity(inst, corridors))
        sram_legal[inst.getName()] = cols
        for nn in ("VPWR", "VGND"):
            sram_cols[nn].extend(cols[nn].keys())
    for nn in sram_cols:
        sram_cols[nn] = sorted(set(sram_cols[nn]))

    def on_sram_column(x0, x1, nn):
        for sx0, sx1 in sram_boxes:
            if x1 <= sx0 or x0 >= sx1:
                continue
            if not any(
                c0 - 0.02 * dbu <= x0 and x1 <= c1 + 0.02 * dbu
                for (c0, c1) in sram_cols[nn]
            ):
                return False
        return True

    def tidy(net_name, swire, bpin, rails):
        boxes = vertical_m4(swire.getWires())
        vias = [b for b in swire.getWires() if b.getTechLayer() is None]
        pboxes = []
        if bpin is not None:
            pboxes = [
                p for p in bpin.getBoxes()
                if p.getTechLayer() is not None
                and p.getTechLayer().getName() == layer
                and (p.yMax() - p.yMin()) > (p.xMax() - p.xMin())
            ]
        groups, pgroups = {}, {}
        for b in boxes:
            groups.setdefault(xkey(b), []).append(b)
        for p in pboxes:
            pgroups.setdefault(xkey(p), []).append(p)
        dropped = extended = pins_dropped = orphans = 0
        for k, sb in sorted(groups.items()):
            x0 = min(b.xMin() for b in sb)
            x1 = max(b.xMax() for b in sb)
            cx = (x0 + x1) // 2
            full = [b for b in sb if is_full(b)]
            if full:
                keep = max(full, key=lambda b: b.yMax() - b.yMin())
                for b in sb:
                    if b is not keep:
                        odb.dbSBox_destroy(b)
                        dropped += 1
            else:
                if not (
                    on_sram_column(x0, x1, net_name)
                    and clear_of_rails(x0, x1, net_name)
                    and clear_of_pins(x0, x1)
                ):
                    print(
                        f"[WARNING] {net_name}: partial-height stripe at "
                        f"x={cx/dbu:.2f} um blocked from full height"
                    )
                    continue
                for b in sb:
                    odb.dbSBox_destroy(b)
                keep = odb.dbSBox_create(swire, m, x0, ylo, x1, yhi, "STRIPE")
                have = [
                    (v.yMin() + v.yMax()) // 2 for v in vias
                    if abs((v.xMin() + v.xMax()) // 2 - cx) < 0.5 * dbu
                ]
                new_vias = 0
                for r in rails:
                    if r.xMin() <= cx <= r.xMax():
                        ry = (r.yMin() + r.yMax()) // 2
                        if not any(abs(h - ry) < 0.3 * dbu for h in have):
                            for via in rail_vias:
                                odb.dbSBox_create(swire, via, cx, ry, "STRIPE")
                            new_vias += 1
                extended += 1
                print(
                    f"[INFO] {net_name}: {len(sb)} partial-height segments at "
                    f"x={cx/dbu:.2f} um → one full-height stripe "
                    f"(+{new_vias} rail via stacks)"
                )
            if bpin is not None:
                for p in pgroups.pop(k, []):
                    odb.dbBox_destroy(p)
                    pins_dropped += 1
                odb.dbBox_create(
                    bpin, m, keep.xMin(), keep.yMin(), keep.xMax(), keep.yMax()
                )
                pins_dropped -= 1
        for _k, ps in pgroups.items():
            for p in ps:
                odb.dbBox_destroy(p)
                orphans += 1
        print(
            f"[INFO] {net_name}: tidy: dropped {dropped} redundant segments, "
            f"extended {extended}, dropped {pins_dropped} duplicate / "
            f"{orphans} orphan pin boxes; {len(groups)} stripes remain"
        )

    def allocate_sram(inst, grid):
        """PRISM allocate_sram: map grid → columns, complete pairs, seed pins.

        Columns come from OBS corridors + declared PINs (see obs_corridors),
        not from the three top-level PIN rectangles alone.
        """
        cols = sram_legal[inst.getName()]
        ib = inst.getBBox()
        regions = [
            r for r in ("array L", "band", "array R")
            if r in set(cols["VPWR"].values()) | set(cols["VGND"].values())
        ]
        chosen = {"VPWR": [], "VGND": []}
        other_of = {"VPWR": "VGND", "VGND": "VPWR"}

        def clear(c, nn):
            return (
                clear_of_pins(c[0], c[1])
                and clear_of_rails(c[0], c[1], nn)
            )

        def free(nn, region=None):
            return [
                c for c, r in cols[nn].items()
                if c not in chosen[nn]
                and (region is None or r == region)
                and clear(c, nn)
            ]

        def partnered(c, nn):
            return any(
                abs(centre(o) - centre(c)) <= pair_gap
                for o in chosen[other_of[nn]]
            )

        def pairs(r):
            return sum(
                1 for c in chosen["VPWR"]
                if cols["VPWR"].get(c) == r and partnered(c, "VPWR")
            )

        def where(c):
            r = cols["VPWR"].get(c) or cols["VGND"].get(c)
            return f"x={centre(c)/dbu:.2f} um ({r})"

        # 1. every tile stripe crossing the footprint → nearest free column
        n_grid = {}
        for nn in ("VPWR", "VGND"):
            targets = sorted(set(
                centre((b.xMin(), b.xMax())) for b in grid[nn]
                if b.xMax() > ib.xMin() and b.xMin() < ib.xMax()
            ))
            n_grid[nn] = len(targets)
            for tx in targets:
                cands = free(nn)
                if not cands:
                    print(
                        f"[WARNING] {inst.getName()}: no free {nn} column "
                        f"for the stripe at x={tx/dbu:.2f}"
                    )
                    continue
                c = min(cands, key=lambda c: abs(centre(c) - tx))
                chosen[nn].append(c)
                shift = (centre(c) - tx) / dbu
                if abs(shift) > 0.05:
                    print(
                        f"[INFO] {inst.getName()}: {nn} stripe at "
                        f"x={tx/dbu:.2f} moved {shift:+.2f} um onto a column"
                    )

        # 1b. keep the named LEF PIN columns (abstract LVS hooks)
        pins = declared_pins(inst)
        for nn, bucket in (
            ("VGND", pins["VGND"]),
            ("VPWR", pins["VPWR"]),
        ):
            for c in bucket["full"] | bucket["rest"]:
                if c in cols[nn] and c not in chosen[nn] and clear(c, nn):
                    chosen[nn].append(c)
                    print(
                        f"[INFO] {inst.getName()}: kept declared {nn} PIN "
                        f"column at {where(c)}"
                    )

        # 2. pair completion inside each region
        def complete_pairs():
            for nn in ("VPWR", "VGND"):
                other = other_of[nn]
                for c in list(chosen[nn]):
                    if partnered(c, nn):
                        continue
                    r = cols[nn][c]
                    cands = free(other, r)
                    if not cands:
                        print(
                            f"[WARNING] {inst.getName()}: no free {other} "
                            f"column in the {r} to pair with the {nn} stripe "
                            f"at {where(c)}"
                        )
                        continue
                    same = [
                        centre(e) for e in chosen[other]
                        if cols[other][e] == r
                    ]
                    o = min(
                        cands,
                        key=lambda o: (
                            abs(centre(o) - centre(c)),
                            -min(
                                (abs(centre(o) - x) for x in same),
                                default=0,
                            ),
                        ),
                    )
                    chosen[other].append(o)
                    print(
                        f"[INFO] {inst.getName()}: {other} stripe added at "
                        f"{where(o)} to pair with the {nn} stripe at "
                        f"{where(c)}"
                    )

        complete_pairs()

        # 3. each populated region gets at least one pair; band wants two
        min_pairs = {"array L": 1, "band": 2, "array R": 1}
        for r in regions:
            need = min_pairs.get(r, 1)
            while pairs(r) < need:
                cands = free("VPWR", r)
                if not cands:
                    print(
                        f"[WARNING] {inst.getName()}: the {r} has only "
                        f"{pairs(r)} VPWR/VGND pair(s) and no free VPWR "
                        f"column"
                    )
                    break
                have = [
                    centre(c) for c in chosen["VPWR"]
                    if cols["VPWR"][c] == r
                ]
                c = max(
                    cands,
                    key=lambda c: (
                        min((abs(centre(c) - x) for x in have), default=0),
                        -centre(c),
                    ),
                )
                chosen["VPWR"].append(c)
                print(
                    f"[INFO] {inst.getName()}: VPWR stripe added at "
                    f"{where(c)} so the {r} reaches {need} pair(s)"
                )
                complete_pairs()

        print(
            f"[INFO] {inst.getName()}: "
            + ", ".join(f"{r}: {pairs(r)} pairs" for r in regions)
            + f"; VPWR {len(chosen['VPWR'])} / VGND {len(chosen['VGND'])} "
            f"stripes for the {n_grid['VPWR']} / {n_grid['VGND']} tile "
            f"stripes crossing the macro"
        )
        return {nn: sorted(chosen[nn]) for nn in chosen}

    # Decide allocation before mutating geometry.
    grid = {}
    for net_name in ("VPWR", "VGND"):
        net = block.findNet(net_name)
        if net is None:
            raise click.ClickException(f"net {net_name} not found")
        grid[net_name] = vertical_m4(
            [b for sw in net.getSWires() for b in sw.getWires()]
        )
    sram_alloc = {}
    for inst in block.getInsts():
        if inst.getMaster().isBlock() and is_sram(inst.getMaster()):
            if inst.getOrient() not in ("R0", "MX"):
                raise click.ClickException(
                    f"{inst.getName()} orientation {inst.getOrient()} "
                    "unsupported (need R0 or MX)"
                )
            sram_alloc[inst.getName()] = allocate_sram(inst, grid)

    for net_name in ("VPWR", "VGND"):
        net = block.findNet(net_name)
        swires = list(net.getSWires())
        swire = swires[0] if swires else odb.dbSWire_create(net, "ROUTED")
        stripes = vertical_m4(swire.getWires())
        rails = [
            b for b in swire.getWires()
            if b.getTechLayer() is not None
            and b.getTechLayer().getName() == "Metal1"
            and (b.xMax() - b.xMin()) > (b.yMax() - b.yMin())
        ]
        bpin = None
        for bterm in net.getBTerms():
            pins = list(bterm.getBPins())
            if pins:
                bpin = pins[0]
                break

        added = 0
        for inst in block.getInsts():
            master = inst.getMaster()
            if not master.isBlock() or not is_sram(master):
                continue
            ib = inst.getBBox()
            x0, x1 = ib.xMin(), ib.xMax()
            columns = sram_alloc[inst.getName()][net_name]
            if not columns:
                print(
                    f"[WARNING] {inst.getName()}: no {net_name} columns on "
                    f"{layer}"
                )
                continue

            crossing = [
                b for b in stripes if b.xMax() > x0 and b.xMin() < x1
            ]
            removed_x = [(b.xMin(), b.xMax()) for b in crossing]

            def on_removed(box, removed_x=removed_x):
                return any(
                    box.xMax() > rx0 and box.xMin() < rx1
                    for (rx0, rx1) in removed_x
                )

            removed = 0
            for b in crossing:
                odb.dbSBox_destroy(b)
                removed += 1
            if bpin is not None:
                for box in list(bpin.getBoxes()):
                    if (
                        box.getTechLayer() is not None
                        and box.getTechLayer().getName() == layer
                        and on_removed(box)
                    ):
                        odb.dbBox_destroy(box)
            for b in list(swire.getWires()):
                if b.getTechLayer() is None and on_removed(b):
                    odb.dbSBox_destroy(b)
            stripes = [b for b in stripes if b not in crossing]

            for c0, c1 in columns:
                stripes.append(
                    odb.dbSBox_create(swire, m, c0, ylo, c1, yhi, "STRIPE")
                )
                if bpin is not None:
                    odb.dbBox_create(bpin, m, c0, ylo, c1, yhi)
                added += 1
                cx = (c0 + c1) // 2
                for r in rails:
                    if r.xMin() <= cx <= r.xMax() and (
                        r.yMax() <= ib.yMin() or r.yMin() >= ib.yMax()
                    ):
                        ry = (r.yMin() + r.yMax()) // 2
                        for via in rail_vias:
                            odb.dbSBox_create(swire, via, cx, ry, "STRIPE")
            print(
                f"[INFO] {inst.getName()}: {net_name}: removed {removed} "
                f"crossing tile stripes; placed {len(columns)} "
                f"full-height column stripe(s) "
                f"({len(rail_vias)} via masters per rail crossing)"
            )

        print(
            f"[INFO] {net_name}: kept "
            f"{len(vertical_m4(swire.getWires())) - added} non-SRAM stripes, "
            f"added {added} SRAM-column stripe(s)"
        )
        tidy(net_name, swire, bpin, rails)


if __name__ == "__main__":
    extend()
