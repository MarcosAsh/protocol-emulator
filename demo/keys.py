# SPDX-License-Identifier: Apache-2.0
# The keys a USB keyboard sends, as this machine's kernel takes them, kept from the
# desktop: each input device with the keyboard's VID:PID is grabbed (EVIOCGRAB) as it
# appears, so no window gets its keys or pointer; one that cannot be grabbed is unbound from
# usbhid instead, so it types nowhere. Prints each grab and each key pressed with its time,
# until SECONDS pass. Needs root for /dev/input and the unbind.
# Usage: sudo python3 demo/keys.py SECONDS [--id 1209:0001]

import argparse
import fcntl
import os
import re
import select
import struct
import time
from pathlib import Path

# _IOW('E', 0x90, int)
EVIOCGRAB = 0x40044590
# struct input_event: a timeval, then type, code and value
EVENT = struct.Struct("llHHi")
EV_KEY = 1
KEYS = dict(zip([30, 48, 46, 32, 18, 33, 34, 35, 23, 36, 37, 38, 50, 49, 24, 25, 16, 19, 31,
                 20, 22, 47, 17, 45, 21, 44, 57], "abcdefghijklmnopqrstuvwxyz "))
INPUT = Path("/sys/class/input")


def taken(text):
    """The keys a run printed, in order."""
    return "".join(re.findall(r"^key \S+ (.)$", text, re.MULTILINE))


def ours(event, vendor, product):
    ids = INPUT / event / "device" / "id"
    try:
        return ((ids / "vendor").read_text().strip(),
                (ids / "product").read_text().strip()) == (vendor, product)
    except OSError:
        return False


def unbind(event):
    """The event device's USB interface off usbhid, and its name."""
    interface = (INPUT / event / "device" / "device").resolve().parent.name
    Path("/sys/bus/usb/drivers/usbhid/unbind").write_text(interface)
    return interface


def grab(event):
    """The event device opened and grabbed, waiting for its node, or None when it is gone
    or would not be grabbed."""
    path = Path("/dev/input") / event
    for _ in range(1000):
        try:
            fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
        except FileNotFoundError:
            time.sleep(0.001)
            continue
        try:
            fcntl.ioctl(fd, EVIOCGRAB, 1)
        except OSError as e:
            os.close(fd)
            print("unbound %.6f %s %s: %s" % (time.time(), event, unbind(event), e), flush=True)
            return None
        return fd
    return None


def main():
    p = argparse.ArgumentParser()
    p.add_argument("seconds", type=float)
    p.add_argument("--id", default="1209:0001", help="VID:PID in hex")
    args = p.parse_args()
    vendor, product = args.id.lower().split(":")
    end = time.monotonic() + args.seconds
    seen, held = set(), {}
    while time.monotonic() < end:
        # a name that goes and comes back is a new device, as after a replug
        now = set(os.listdir(INPUT))
        seen &= now
        for event in sorted(now - seen):
            seen.add(event)
            if event.startswith("event") and ours(event, vendor, product):
                fd = grab(event)
                if fd is not None:
                    held[fd] = event
                    name = (INPUT / event / "device" / "name").read_text().strip()
                    print("grab %.6f %s %s" % (time.time(), event, name), flush=True)
        ready, _, _ = select.select(list(held), [], [], 0.001)
        for fd in ready:
            try:
                data = os.read(fd, 64 * EVENT.size)
            except BlockingIOError:
                continue
            except OSError:
                print("gone %.6f %s" % (time.time(), held.pop(fd)), flush=True)
                os.close(fd)
                continue
            for sec, usec, kind, code, value in EVENT.iter_unpack(data):
                if kind == EV_KEY and value == 1:
                    print("key %d.%06d %s" % (sec, usec, KEYS.get(code, "?")), flush=True)
    for fd in held:
        os.close(fd)


if __name__ == "__main__":
    main()
