#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# Puts an act's firmware on Pico B, which stays wired for every act: MicroPython for the
# listener, demo/can_node for can and can_node, demo/start_hold_master's pio or hw build
# for start_hold. Pico B reaches its bootloader through mpremote from MicroPython, and from
# the C builds through picotool or, without it, a 1200 baud open of their serial port. The
# UF2 goes in by picotool or onto the RPI-RP2 drive, mounted by udisksctl if need be.
# The UF2s live in demo/out: the C builds as their CMakeLists.txt build them, MicroPython
# as downloaded from micropython.org.
# Usage: [PICO_B_SERIAL=<serial>] demo/pico_b.sh micropython|can_node|start_hold_pio|start_hold_hw
set -e
serial=${PICO_B_SERIAL:-e66548545740ad29}
out=$(dirname "$0")/out
case $1 in
micropython)
    uf2=${MICROPYTHON_UF2:-$out/RPI_PICO-v1.29.0.uf2}
    how="download it from micropython.org/download/RPI_PICO"
    ;;
can_node)
    uf2=${CAN_NODE_UF2:-$out/can_node/can_node.uf2}
    # the first build went to ~/can_node, used until demo/out has one
    if [ -z "$CAN_NODE_UF2" ] && [ ! -f "$uf2" ] && [ -f "$HOME/can_node/can_node.uf2" ]; then
        uf2=$HOME/can_node/can_node.uf2
    fi
    how="build it as demo/can_node/CMakeLists.txt says"
    ;;
start_hold_pio | start_hold_hw)
    uf2=${START_HOLD_DIR:-$out/start_hold_master}/$1.uf2
    how="build it as demo/start_hold_master/CMakeLists.txt says"
    ;;
*)
    echo "usage: [PICO_B_SERIAL=<serial>] $0 micropython|can_node|start_hold_pio|start_hold_hw" >&2
    exit 1
    ;;
esac
[ -f "$uf2" ] || { echo "no $uf2: $how" >&2; exit 1; }

# Pico B's serial port, as MicroPython names it in lower case and the SDK in upper
port() {
    ls /dev/serial/by-id/ 2>/dev/null | grep -i "_${serial}-if00" | head -n 1
}

# the RPI-RP2 partition, refused if more than one Pico is in its bootloader
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
    picotool reboot -f -u --ser "$serial"
else
    # the SDK's USB serial port reboots to the bootloader when opened at 1200 baud
    stty -F "/dev/serial/by-id/$name" 1200 || true
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
