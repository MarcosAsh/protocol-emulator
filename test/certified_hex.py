# SPDX-License-Identifier: Apache-2.0
# Reads a test firmware's certificate (written by firmware.mk) and the assumptions
# firmware.mk certified it under.
import re


def certificate(name):
    with open(f"{name}.cert.hex") as f:
        return [int(line, 16) for line in f]


def assumptions(name):
    """The loaded, floor and single_edge values certify needs for this firmware. loaded
    comes from -period / -period-floor, or from the budget in a compiled predicate's
    settings."""
    with open("firmware.mk") as f:
        text = f.read().replace("\\\n", " ")
    match = re.search(rf"^{re.escape(name)}\.hex .*?ASSUME = (.*)$", text, re.M)
    flags = match.group(1) if match else ""
    period = re.search(r"-period(?:-floor)? (\d+)", flags)
    loaded = int(period.group(1)) if period else None
    try:
        with open(f"{name}.settings") as f:
            for line in f:
                key, _, value = line.partition(" ")
                if key == "budget_from_host":
                    loaded = int(value)
    except OSError:
        pass
    return {
        "loaded": loaded,
        "floor": "-period-floor" in flags,
        "single_edge": "-single-capture-edge" in flags,
    }
