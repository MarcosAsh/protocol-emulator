#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# Puts a demo's firmware on Pico B, which stays wired up for every demo: MicroPython for the
# listener, demo/can_node for can and can_node, demo/start_hold_master (pio or hw build) for
# start_hold. To reach the bootloader we use mpremote from MicroPython, and for the C
# builds picotool or, without it, a 1200 baud open of the serial port. The UF2 goes in via
# picotool or onto the RPI-RP2 drive (mounted with udisksctl if needed).
# Usage: [PICO_B_SERIAL=<serial>] demo/pico_b.sh micropython|can_node|start_hold_pio|start_hold_hw
set -e
serial=${PICO_B_SERIAL:-e66548545740ad29}
# not in ~/.cache, which a cleanup emptied once
uf2s=$HOME/.local/share/protocol-emulator/uf2
case $1 in
micropython) uf2=${MICROPYTHON_UF2:-$uf2s/RPI_PICO-v1.29.0.uf2} ;;
can_node) uf2=${CAN_NODE_UF2:-$(dirname "$0")/../build/can_node/can_node.uf2} ;;
start_hold_pio | start_hold_hw) uf2=${START_HOLD_DIR:-$uf2s}/$1.uf2 ;;
*)
    echo "usage: [PICO_B_SERIAL=<serial>] $0 micropython|can_node|start_hold_pio|start_hold_hw" >&2
    exit 1
    ;;
esac
[ -f "$uf2" ] || { echo "no $uf2" >&2; exit 1; }

# Pico B's serial port; MicroPython spells the serial lower case, the SDK upper case
port() {
    ls /dev/serial/by-id/ 2>/dev/null | grep -i "_${serial}-if00" | head -n 1
}

# the RPI-RP2 partition; fails if more than one Pico is in its bootloader
drive() {
    found=$(lsblk -rno NAME,LABEL | awk '$2 == "RPI-RP2" { print $1 }')
    [ "$(echo "$found" | grep -c .)" -le 1 ] || { echo "more than one RPI-RP2 drive" >&2; exit 1; }
    echo "$found"
}

wait_for() {
    i=0
    while [ $i -lt 40 ]; do
        [ -z "$($1)" ] || return 0
        sleep 0.25
        i=$((i + 1))
    done
    return 1
}

name=$(port)
if [ -z "$name" ] && [ -n "$(drive)" ]; then
    echo "Pico B is in its bootloader already"
elif [ -z "$name" ]; then
    echo "Pico B ($serial) is not on USB" >&2
    exit 1
elif echo "$name" | grep -q MicroPython; then
    mpremote connect "id:$serial" bootloader || true
elif command -v picotool >/dev/null; then
    # reboot's flags go before the device's; the serial is upper case, as the SDK has it
    picotool reboot -u -f --ser "$(echo "$name" | sed 's/.*_\([0-9A-Fa-f]*\)-if00$/\1/')"
else
    # the SDK's USB serial port reboots to the bootloader when opened at 1200 baud. stty
    # hangs in set_termios if the firmware never reads the port, hence the timeout
    timeout -s KILL 10 stty -F "/dev/serial/by-id/$name" 1200 || true
fi
wait_for drive || { echo "Pico B never showed its RPI-RP2 drive" >&2; exit 1; }
if command -v picotool >/dev/null; then
    picotool load -x "$uf2"
else
    dev=/dev/$(drive)
    mnt=$(lsblk -rno MOUNTPOINT "$dev")
    if [ -z "$mnt" ]; then
        udisksctl mount -b "$dev" >/dev/null
        mnt=$(lsblk -rno MOUNTPOINT "$dev")
    fi
    cp "$uf2" "$mnt/"
    sync
fi
wait_for port || { echo "Pico B took $uf2 but has no serial port yet" >&2; exit 1; }
echo "Pico B runs $1 on /dev/serial/by-id/$(port)"
