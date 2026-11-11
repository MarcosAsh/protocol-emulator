#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# What this machine's kernel sees of the chip as a USB device (python/demo_usb_fs.py).
# Waits for it in sysfs until a driver has its interface, then writes its speed, strings,
# driver and the descriptors the kernel read from it, in hex, to OUT.
# Usage: python3 demo/usb_fs_host.py OUT [SECONDS]

import sys
import time
from pathlib import Path

ID = ("1209", "0002")
FIELDS = ("speed", "version", "bcdDevice", "bMaxPacketSize0", "product",
          "bNumConfigurations", "bConfigurationValue")


def read(path):
    try:
        return path.read_bytes()
    except OSError:
        return b""


def seen():
    """Returns the device's lines once its interface has a driver, else None."""
    for d in Path("/sys/bus/usb/devices").iterdir():
        if (read(d / "idVendor").strip().decode(), read(d / "idProduct").strip().decode()) != ID:
            continue
        interface = d / (d.name + ":1.0")
        reports = list(interface.glob("0003:*/report_descriptor"))
        if not (interface / "driver").exists() or not reports:
            return None
        lines = ["id %s:%s" % ID]
        lines += ["%s %s" % (f, read(d / f).decode().strip()) for f in FIELDS]
        lines.append("driver %s" % (interface / "driver").resolve().name)
        lines.append("descriptors %s" % read(d / "descriptors").hex())
        lines.append("report_descriptor %s" % read(reports[0]).hex())
        return lines
    return None


def main():
    if len(sys.argv) not in (2, 3):
        sys.exit("usage: %s OUT [SECONDS]" % sys.argv[0])
    until = time.monotonic() + float((sys.argv[2:] or ["20"])[0])
    while time.monotonic() < until:
        lines = seen()
        if lines:
            Path(sys.argv[1]).write_text("\n".join(lines) + "\n")
            return
        time.sleep(0.05)
    sys.exit("no USB device %s:%s with a driver" % ID)


if __name__ == "__main__":
    main()
