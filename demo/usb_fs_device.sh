#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# The full speed USB device demo, with the Icepi's first USB-C port on this machine and
# the FS=1 build loaded. Runs python/demo_usb_fs_device.py on Pico A while
# demo/usb_fs_host.py keeps what the kernel saw, as usb_fs_device.host and .log in
# CAPTURES. No analyser: on the bench pc it shares the device's USB controller and stops
# early when the device attaches.
# Usage: PICO=id:<serial of Pico A> demo/usb_fs_device.sh
set -e
: "${PICO:?PICO=id:<serial of Pico A>}"
captures=${CAPTURES:-.}
mkdir -p "$captures"
mpremote connect "$PICO" cp python/protocol_emulator.py python/pico_board.py python/bench.py \
    python/usb_fs_board.py python/usb_fs_device_firmware.py python/demo_usb_fs.py \
    python/demo_usb_fs_device.py :
mpremote connect "$PICO" exec "import os
try:
    os.remove('outside.log')
except OSError:
    pass"
python3 demo/usb_fs_host.py "$captures/usb_fs_device.host" 20 &
host=$!
mpremote connect "$PICO" run --no-follow python/demo_usb_fs_device.py
status=0
wait "$host" || status=1
# the demo stays attached a few seconds more, then writes its log
sleep 8
mpremote connect "$PICO" cat :outside.log > "$captures/usb_fs_device.log" || status=1
cat "$captures/usb_fs_device.host" "$captures/usb_fs_device.log"
exit "$status"
