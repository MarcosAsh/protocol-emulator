# SPDX-License-Identifier: Apache-2.0
# The chip's own USB full speed receiver on the board against a real host: loads the
# chip built with FS=1, whose D+ pull-up makes the laptop enumerate the first USB-C port
# at full speed, and has Pico A (demo/usb_fs_chip_pico.py), holding the port detached as it
# loads, arm the receiver over the host port and read its verdict on every packet. Tokens (two words, one half) must carry a good
# CRC-5 and data packets a good CRC-16, with no stuffing error and no word dropped. The
# chip never answers, so the host gives up; openFPGALoader -r then brings back the flash.
# Usage: PICO_A=<serial of Pico A> [REV=v1.3] python3 demo/usb_fs_chip.py [--out DIR]

import argparse
import collections
import os
import pathlib
import subprocess
import sys
import time

ROOT = pathlib.Path(__file__).resolve().parent.parent


def verdict(status, flags):
    """A packet's shape and whether the chip found it good."""
    words, half = status & 0x3FF, (status >> 12) & 1
    dropped = (status >> 13) & 1
    crc5, crc16, stuffed = flags & 1, (flags >> 1) & 1, (flags >> 2) & 1
    if words == 1 and half:
        kind, good = "handshake", True
    elif words == 2 and half:
        kind, good = "token", bool(crc5)
    else:
        kind, good = f"data {2 * words - half} bytes", bool(crc16)
    return kind, good and not stuffed and not dropped


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=pathlib.Path)
    args = parser.parse_args()
    rev = os.environ.get("REV", "v1.3")
    pico = ["mpremote", "connect", "id:" + os.environ["PICO_A"]]
    subprocess.run(
        [*pico, "cp", "python/protocol_emulator.py", "python/pico_board.py", ":"],
        cwd=ROOT,
        check=True,
        stdout=subprocess.DEVNULL,
    )
    # Pico A holds the port detached while the chip loads, so the host sees it attach
    # only once the receiver is armed
    pico_run = subprocess.Popen(
        [*pico, "run", str(ROOT / "demo/usb_fs_chip_pico.py")],
        stdout=subprocess.PIPE,
        text=True,
    )
    assert pico_run.stdout.readline().strip() == "ready"
    subprocess.run(
        ["make", "-C", "icepi", "REV=" + rev, "FS=1", "prog"],
        cwd=ROOT,
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    since = time.strftime("%Y-%m-%d %H:%M:%S")
    output = pico_run.stdout.read()
    pico_run.wait()
    subprocess.run(
        ["openFPGALoader", "-b", "icepi-zero", "-r"],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    kernel = subprocess.run(
        ["journalctl", "-k", "--since", since, "--no-pager", "-q"],
        check=False,
        capture_output=True,
        text=True,
    ).stdout
    lines = [line.split() for line in output.splitlines()]
    seen = [
        (int(s, 16), int(f, 16), int(n))
        for s, f, n in (x for x in lines if len(x) == 3)
    ]
    tally = collections.Counter()
    for status, flags, count in seen:
        tally[verdict(status, flags)] += count
    packets = sum(tally.values())
    summary = [
        f"packets {packets}",
        *(
            f"  {kind}: {'good' if good else 'BAD'} {count}"
            for (kind, good), count in sorted(tally.items())
        ),
        "kernel:",
        *(line for line in kernel.splitlines() if "usb" in line),
    ]
    print("\n".join(summary))
    if args.out:
        args.out.mkdir(parents=True, exist_ok=True)
        (args.out / "summary.txt").write_text("\n".join(summary) + "\n")
        (args.out / "pico.txt").write_text(output)
    full_speed = "new full-speed USB device" in kernel
    sys.exit(0 if packets and full_speed and all(good for _, good in tally) else 1)


main()
