#!/bin/bash
# Read-only inventory of rothko block devices and the boot/log state.
# Nothing here writes to the device.
ADB="/mnt/i/刷机/root/scrcpy-win64-v3.2/adb.exe"
[ -x "$ADB" ] || ADB=adb

run() { "$ADB" shell "$@"; }

echo "=== uptime / bootreason ==="
run "uptime; getprop ro.boot.bootreason; getprop ro.bootmode"
echo
echo "=== by-name entries of interest ==="
run "su -c 'ls -l /dev/block/by-name/' | grep -Ei 'expdb|persist|misc|boot|log|md' || true"
echo
echo "=== memory of last pstore ==="
run "su -c 'ls -l /sys/fs/pstore/ 2>/dev/null' || true"
echo
echo "=== expdb size ==="
run "su -c 'blockdev --getsize64 /dev/block/by-name/expdb 2>/dev/null' || true"
