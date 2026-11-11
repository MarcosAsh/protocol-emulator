# SPDX-License-Identifier: Apache-2.0
# A real host enumerates the chip as a full speed USB device (MicroPython, Pico A), as
# demo_usb_fs, attached for a few seconds. It needs the Icepi build with FS=1, and
# demo/usb_fs_device.sh runs it and keeps what the host saw.

import time

import bench
import demo_usb_fs

SECONDS = 3


def run(log):
    demo_usb_fs.run(SECONDS, log)
    return "configured" in log.lines


if __name__ == "__main__":
    log = bench.Log()
    time.sleep_ms(bench.START_MS)
    bench.report(lambda: run(log), log)
