# SPDX-License-Identifier: Apache-2.0
# The Tiny Tapeout flow has no setup checker and goes green on negative slack, so this
# reads LibreLane's metrics and fails when the chip misses timing or signoff.
# Usage: python3 test/check_metrics.py runs/wokwi/final/metrics.json
import argparse
import json
import sys

SLOW = "timing__setup__ws__corner:nom_slow_1p08V_125C"

AT_LEAST_ZERO = [SLOW, "timing__hold__ws"]
EXACTLY_ZERO = [
    "antenna__violating__nets",
    "route__drc_errors",
    "klayout__drc_error__count",
    "design__lvs_error__count",
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


def main():
    p = argparse.ArgumentParser()
    p.add_argument("metrics")
    args = p.parse_args()
    with open(args.metrics) as f:
        metrics = json.load(f)
    failed = list(failures(metrics))
    if failed:
        sys.exit(f"{len(failed)} of the signoff metrics failed: {', '.join(failed)}")


if __name__ == "__main__":
    main()
