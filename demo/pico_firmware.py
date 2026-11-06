# SPDX-License-Identifier: Apache-2.0
# Cuts python/bench_firmware.py down to the entries the given demo scripts name, for Pico A.
# MicroPython compiles the whole file on import, and with the 8x4 chip's certificates that
# is slow enough to push a demo's traffic past the end of its capture.
# Usage: python3 demo/pico_firmware.py OUT SCRIPT...

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FIRMWARE = ROOT / "python/bench_firmware.py"


def names(scripts):
    """Returns every bench_firmware.NAME the scripts use."""
    found = set()
    for script in scripts:
        text = Path(script).read_text()
        found |= set(re.findall(r"\bbench_firmware\.([A-Z][A-Z0-9_]*)\b", text))
    return sorted(found)


def subset(wanted):
    scope = {}
    exec(FIRMWARE.read_text(), scope)
    missing = [name for name in wanted if name not in scope]
    if missing:
        sys.exit("python/bench_firmware.py has no %s" % " ".join(missing))
    lines = ["# python/bench_firmware.py's %s, cut by demo/pico_firmware.py" % " ".join(wanted)]
    lines += ["%s = %r" % (name, scope[name]) for name in wanted]
    return "\n".join(lines) + "\n"


def main():
    out, scripts = sys.argv[1], sys.argv[2:]
    # a script that picks its firmware at run time gets all of it
    if any("getattr(bench_firmware" in Path(script).read_text() for script in scripts):
        Path(out).write_text(FIRMWARE.read_text())
    else:
        Path(out).write_text(subset(names(scripts)))


if __name__ == "__main__":
    main()
