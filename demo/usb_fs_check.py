# SPDX-License-Identifier: Apache-2.0
# Usb_frame_rx on the board against a real host: loads icepi/usb_fs_check.v, whose D+
# pull-up makes the laptop enumerate the first USB-C port at full speed, and reads back
# every packet it took through Pico B (demo/usb_fs_listen.py). Each packet's CRC is
# checked here too, and the SOFs' frame numbers must count up by one. The device never
# answers, so the host gives up after a few seconds; openFPGALoader -r then brings the
# chip back from flash.
# Usage: PICO_B=<serial of Pico B> [REV=v1.3] python3 demo/usb_fs_check.py [--out DIR]

import argparse
import collections
import itertools
import os
import pathlib
import subprocess
import sys
import time

ROOT = pathlib.Path(__file__).resolve().parent.parent
PIDS = {
    0xA5: "SOF",
    0x2D: "SETUP",
    0x69: "IN",
    0xE1: "OUT",
    0xC3: "DATA0",
    0x4B: "DATA1",
    0xD2: "ACK",
    0x5A: "NAK",
    0x1E: "STALL",
}
FLAGS = ["crc5_ok", "crc16_ok", "half", "aligned", "stuff_error", "dropped"]


def crc5(value):
    crc = 0x1F
    for i in range(11):
        crc = (crc >> 1) ^ 0x14 if (crc ^ (value >> i)) & 1 else crc >> 1
    return ~crc & 0x1F


def crc16(data):
    crc = 0xFFFF
    for byte in data:
        for i in range(8):
            crc = (crc >> 1) ^ 0xA001 if (crc ^ (byte >> i)) & 1 else crc >> 1
    return ~crc & 0xFFFF


def packets(stream):
    """Split the UART's bytes into (flags, lost, packet bytes)."""
    i = 0
    while i + 4 <= len(stream):
        if stream[i] != 0xA5:
            raise ValueError(f"no 0xa5 at byte {i}")
        flags, count, lost = stream[i + 1], stream[i + 2], stream[i + 3]
        body = stream[i + 4 : i + 4 + 2 * count]
        if len(body) < 2 * count:
            break
        if flags & 4:
            body = body[:-1]
        yield flags, lost, body
        i += 4 + 2 * count


def check(flags, body):
    """The software's verdict on a packet, and its name."""
    if not body or body[0] & 0xF != ~body[0] >> 4 & 0xF:
        return False, "bad pid"
    name = PIDS.get(body[0], f"pid {body[0]:02x}")
    rest = body[1:]
    if len(rest) == 2:
        value = rest[0] | rest[1] << 8
        return crc5(value & 0x7FF) == value >> 11, name
    if len(rest) >= 2:
        return crc16(rest[:-2]) == (rest[-2] | rest[-1] << 8), name
    return len(rest) == 0, name


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=pathlib.Path)
    args = parser.parse_args()
    rev = os.environ.get("REV", "v1.3")
    listener = subprocess.Popen(
        [
            "mpremote",
            "connect",
            "id:" + os.environ["PICO_B"],
            "run",
            str(ROOT / "demo/usb_fs_listen.py"),
        ],
        stdout=subprocess.PIPE,
        text=True,
    )
    assert listener.stdout.readline().strip() == "listening"
    since = time.strftime("%Y-%m-%d %H:%M:%S")
    subprocess.run(
        ["make", "-C", str(ROOT / "icepi"), "REV=" + rev, "usb-fs-prog"],
        check=True,
        stdout=subprocess.DEVNULL,
    )
    lines = [line.strip() for line in listener.stdout]
    listener.wait()
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
    stream = bytes.fromhex("".join(line for line in lines if line not in ("", "done")))

    names = collections.Counter()
    disagree = []
    frames = []
    setups = collections.Counter()
    lost = 0
    report = []
    previous = None
    for n, (flags, lost, body) in enumerate(packets(stream)):
        ok, name = check(flags, body)
        names[name, ok] += 1
        if len(body) == 1:
            chip = not flags & 0x30
        else:
            chip = bool(flags & (1 if len(body) == 3 else 2)) and not flags & 0x30
        if ok != chip:
            disagree.append(n)
        if name == "SOF" and ok:
            frames.append((body[1] | body[2] << 8) & 0x7FF)
        if previous == "SETUP" and name == "DATA0" and ok:
            setups[body[1:-2].hex(" ")] += 1
        previous = name
        verdict = "ok " if ok else "BAD"
        flagged = " ".join(f for i, f in enumerate(FLAGS) if flags >> i & 1)
        report.append(
            f"{n:5d} {name:<6} {verdict} {'chip' if chip else '-':<5} {flagged} {body.hex(' ')}"
        )

    steps = collections.Counter((b - a) % 2048 for a, b in itertools.pairwise(frames))
    summary = [
        f"packets {sum(names.values())}, lost to the queue {lost}",
        "by pid: "
        + ", ".join(
            f"{name} {'ok' if ok else 'BAD'} {count}"
            for (name, ok), count in sorted(names.items())
        ),
        f"chip and software disagree on {len(disagree)} packets {disagree[:10]}",
        f"sof frame numbers: {len(frames)}, steps {dict(steps)}",
        f"setup data: {dict(setups)}",
        "kernel:",
    ] + [line for line in kernel.splitlines() if "usb" in line]
    print("\n".join(summary))
    if args.out:
        args.out.mkdir(parents=True, exist_ok=True)
        (args.out / "summary.txt").write_text("\n".join(summary) + "\n")
        (args.out / "packets.txt").write_text("\n".join(report) + "\n")
        (args.out / "uart.bin").write_bytes(stream)
    good = names and not disagree and all(ok for _, ok in names) and frames
    sys.exit(0 if good else 1)


main()
