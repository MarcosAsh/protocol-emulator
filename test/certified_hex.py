# SPDX-License-Identifier: Apache-2.0
# A test firmware's certificate, as firmware.mk writes it beside its words, and the
# assumptions firmware.mk makes it under, read from firmware.mk itself.
import re


def certificate(name):
    with open(f"{name}.cert.hex") as f:
        return [int(line, 16) for line in f]


def assumptions(name):
    """certify's loaded and single_edge for the firmware: -period or -period-floor, or
    the budget a compiled predicate's settings give, and -single-capture-edge."""
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
    return {"loaded": loaded, "single_edge": "-single-capture-edge" in flags}
