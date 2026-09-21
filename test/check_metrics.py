# SPDX-License-Identifier: Apache-2.0
# The Tiny Tapeout flow has no setup checker and goes green on negative slack, so this
# reads LibreLane's metrics and fails when the chip misses timing or signoff.
# Usage: python3 test/check_metrics.py [--csv] runs/wokwi/final/metrics.json
#        python3 test/check_metrics.py --fpga test/fpga_kit.log
import argparse
import json
import re
import subprocess
import sys

SLOW = "timing__setup__ws__corner:nom_slow_1p08V_125C"

AT_LEAST_ZERO = [SLOW, "timing__hold__ws"]
EXACTLY_ZERO = [
    "antenna__violating__nets",
    "route__drc_errors",
    "klayout__drc_error__count",
    "design__lvs_error__count",
]

COLUMNS = [
    ("setup_slow_ns", SLOW),
    ("setup_typ_ns", "timing__setup__ws__corner:nom_typ_1p20V_25C"),
    ("hold_ns", "timing__hold__ws"),
    ("std_cells", "design__instance__count__stdcell"),
    ("utilisation", "design__instance__utilization"),
    ("antenna_nets", "antenna__violating__nets"),
]


def failures(metrics):
    for key in AT_LEAST_ZERO + EXACTLY_ZERO:
        value = metrics.get(key)
        if value is None:
            # a flow that stopped early leaves the metric out, which is not a pass
            ok = False
        elif key in AT_LEAST_ZERO:
            ok = value >= 0
        else:
            ok = value == 0
        print(f"{'ok  ' if ok else 'FAIL'} {key} = {value}")
        if not ok:
            yield key


def csv(metrics):
    """One row for a log of the chip over time, under its header."""
    commit = subprocess.run(
        ["git", "log", "-1", "--format=%h,%cs"], capture_output=True, text=True
    ).stdout.strip()
    values = [metrics.get(key, "") for _, key in COLUMNS]
    values = [round(v, 3) if isinstance(v, float) else v for v in values]
    print("commit,date," + ",".join(name for name, _ in COLUMNS))
    print(commit + "," + ",".join(str(v) for v in values))


def fpga(log):
    """The kit build's size and clock; nextpnr prints the routed frequency last."""
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
        return csv(metrics)
    failed = list(failures(metrics))
    if failed:
        sys.exit(f"{len(failed)} of the signoff metrics failed: {', '.join(failed)}")


if __name__ == "__main__":
    main()
