# SPDX-License-Identifier: Apache-2.0
# Fails when LibreLane's metrics miss timing or signoff. The flow itself stays green on
# negative slack, so we check here. Also records the run's flow and PDK versions.
# Usage: python3 test/check_metrics.py [--csv] runs/wokwi/final/metrics.json
#        python3 test/check_metrics.py --fpga test/fpga_kit.log
import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

SLOW = "timing__setup__ws__corner:nom_slow_1p08V_125C"
POWER_NETS = ["VPWR", "VGND"]

AT_LEAST_ZERO = [SLOW, "timing__hold__ws"]
EXACTLY_ZERO = [
    "antenna__violating__nets",
    "route__drc_errors",
    "klayout__drc_error__count",
    "design__lvs_error__count",
]
# main's green run 42268510223 had these, so any more is new
AT_MOST = {
    "design__max_cap_violation__count": 1,
    "design__max_slew_violation__count": 8,
}

COLUMNS = [
    ("setup_slow_ns", SLOW),
    ("setup_typ_ns", "timing__setup__ws__corner:nom_typ_1p20V_25C"),
    ("hold_ns", "timing__hold__ws"),
    ("std_cells", "design__instance__count__stdcell"),
    ("utilisation", "design__instance__utilization"),
    ("antenna_nets", "antenna__violating__nets"),
    ("max_cap", "design__max_cap_violation__count"),
    ("max_slew", "design__max_slew_violation__count"),
]


def failures(metrics):
    for key in AT_LEAST_ZERO + EXACTLY_ZERO + list(AT_MOST):
        value = metrics.get(key)
        if value is None:
            # a flow that stopped early leaves the metric out, and that isn't a pass
            ok = False
        elif key in AT_LEAST_ZERO:
            ok = value >= 0
        elif key in AT_MOST:
            ok = value <= AT_MOST[key]
        else:
            ok = value == 0
        limit = f" (at most {AT_MOST[key]})" if key in AT_MOST else ""
        print(f"{'ok  ' if ok else 'FAIL'} {key} = {value}{limit}")
        if not ok:
            yield key


def unpowered(metrics_path):
    """What the IR drop step found unconnected on the routed layout, after the SRAM stripes.
    metrics.json's power grid count predates them."""
    logs = sorted(Path(metrics_path).parents[1].glob("*-openroad-irdropreport/*.log"))
    log = logs[-1].read_text() if logs else ""
    unconnected = re.findall(r".*PSM-00(?:38|39|69).*", log)
    for line in unconnected[:10]:
        print(f"FAIL {line.strip()}")
    if unconnected:
        yield f"{len(unconnected)} unconnected power shapes or pins"
    for net in POWER_NETS:
        ok = f"All shapes on net {net} are connected" in log
        print(f"{'ok  ' if ok else 'FAIL'} {net} connected")
        if not ok:
            yield f"{net} connectivity"


def versions(metrics_path):
    """FLOW_VERSION and PDK_VERSION from the run's pdk.json, or blanks."""
    path = Path(metrics_path).parents[1] / "pdk.json"
    pdk = json.loads(path.read_text()) if path.exists() else {}
    return pdk.get("FLOW_VERSION", ""), pdk.get("PDK_VERSION", "")


def csv(metrics, metrics_path):
    """Print a header and one row, for logging the chip over time."""
    commit = subprocess.run(
        ["git", "log", "-1", "--format=%h,%cs"], capture_output=True, text=True
    ).stdout.strip()
    values = [metrics.get(key, "") for _, key in COLUMNS]
    values = [round(v, 3) if isinstance(v, float) else v for v in values]
    values += versions(metrics_path)
    names = [name for name, _ in COLUMNS] + ["flow_version", "pdk_version"]
    print("commit,date," + ",".join(names))
    print(commit + "," + ",".join(str(v) for v in values))


def fpga(log):
    """Print the kit build's size and clock (nextpnr prints the routed frequency last)."""
    cells = re.findall(r"ICESTORM_LC:\s*(\d+)/\s*(\d+)", log)
    clocks = re.findall(r"Max frequency for clock .*: ([\d.]+) MHz", log)
    if not cells or not clocks:
        sys.exit("no cell count or max frequency in the nextpnr log")
    used, available = cells[-1]
    print(f"iCE40 kit build: {used} of {available} LCs, {clocks[-1]} MHz")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--csv", action="store_true", help="print the numbers, check nothing")
    p.add_argument("--fpga", action="store_true", help="read a nextpnr log instead")
    p.add_argument("metrics")
    args = p.parse_args()
    if args.fpga:
        with open(args.metrics) as f:
            return fpga(f.read())
    with open(args.metrics) as f:
        metrics = json.load(f)
    if args.csv:
        return csv(metrics, args.metrics)
    flow, pdk = versions(args.metrics)
    print(f"flow {flow or 'unknown'}, pdk {pdk or 'unknown'}")
    failed = list(failures(metrics)) + list(unpowered(args.metrics))
    if failed:
        sys.exit(f"{len(failed)} of the signoff checks failed: {', '.join(failed)}")


if __name__ == "__main__":
    main()
