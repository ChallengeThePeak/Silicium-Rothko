#!/bin/bash
# Grab the freshest expdb evidence right after a rothko test boot.
#
# Dumps only the tail of expdb first (fast), because the newest records land at
# the end of the log_store region. If the tail is all zeros, falls back to a
# full dump.
#
# Usage: expdb-quick.sh [outdir]
set -uo pipefail

ADB="/mnt/i/刷机/root/scrcpy-win64-v3.2/adb.exe"
[ -x "$ADB" ] || ADB=adb
OUTDIR="${1:-/mnt/d/漏洞/UNIXNU/适配K70U/work/expdb}"
mkdir -p "$OUTDIR"

echo "=== device ==="
"$ADB" devices -l 2>&1 | tr -d '\r'
echo
echo "=== uptime / bootreason / slot ==="
"$ADB" shell 'uptime; getprop ro.boot.bootreason; getprop ro.boot.slot_suffix' 2>&1 | tr -d '\r'
echo

echo "=== expdb partition size ==="
SIZE=$("$ADB" shell "su -c 'blockdev --getsize64 /dev/block/by-name/expdb'" 2>/dev/null | tr -d '\r')
echo "size=$SIZE"
[ -z "$SIZE" ] && { echo "cannot query size (root?)" >&2; exit 1; }

echo
echo "=== pstore now ==="
"$ADB" shell "su -c 'ls -l /sys/fs/pstore/'" 2>&1 | tr -d '\r'

echo
echo "=== last 8 MiB of expdb ==="
BIN="$OUTDIR/expdb-tail8m.bin"
"$ADB" exec-out "su -c 'dd if=/dev/block/by-name/expdb bs=1048576 skip=120 2>/dev/null'" > "$BIN"
echo "wrote $(stat -c %s "$BIN" 2>/dev/null || echo 0) bytes -> $BIN"

echo
echo "=== strings of that tail, filtered to boot-chain lines ==="
strings -a -n 5 "$BIN" | grep -aiE \
  'load_bootinfo|vbmeta|avb_slot|boot_reason|wdt|watchdog|panic|aee|RAM_CONSOLE|ROTHKO|UEFI|SILICIUM|LK_AB|Boot Success|boot_mode' \
  | tail -60
