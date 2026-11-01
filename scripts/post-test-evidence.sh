#!/bin/bash
# Read-only evidence check after a rothko test boot.
#
# Confirms: (a) the device is in Android now, (b) how long it has been up,
# (c) whether pstore holds a panic from the test, (d) whether the boot that
# just happened was our fastboot boot or a normal Android boot.
set -uo pipefail

ADB="/mnt/i/刷机/root/scrcpy-win64-v3.2/adb.exe"
[ -x "$ADB" ] || ADB=adb

sh_() { "$ADB" shell "$@" 2>&1 | tr -d '\r'; }

echo "=== devices ==="
"$ADB" devices -l 2>&1 | tr -d '\r'
echo
echo "=== uptime / boot reason ==="
sh_ "uptime"
sh_ "getprop ro.boot.bootreason"
sh_ "getprop ro.boot.bootmode"
sh_ "getprop ro.boot.hardware"
echo
echo "=== last kernel boot log head (proves which OS booted) ==="
sh_ "su -c 'head -c 600 /sys/fs/pstore/console-ramoops-0'" | head -8
echo
echo "=== pstore mtime and size ==="
sh_ "su -c 'ls -l /sys/fs/pstore/'"
echo
echo "=== /proc/last_kmsg present? ==="
sh_ "su -c 'ls -l /proc/last_kmsg 2>/dev/null'"
echo
echo "=== boot partition slot in use ==="
sh_ "getprop ro.boot.slot_suffix"
sh_ "su -c 'cat /proc/cmdline'"
