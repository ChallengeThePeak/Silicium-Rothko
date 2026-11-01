#!/bin/bash
# Read-only: dump current pstore contents and check fastboot readiness.
ADB="/mnt/i/刷机/root/scrcpy-win64-v3.2/adb.exe"
[ -x "$ADB" ] || ADB=adb

echo "=== console-ramoops-0 head ==="
"$ADB" shell "su -c 'head -c 4000 /sys/fs/pstore/console-ramoops-0'" 2>&1
echo
echo "=== pmsg-ramoops-0 (full) ==="
"$ADB" shell "su -c 'cat /sys/fs/pstore/pmsg-ramoops-0'" 2>&1
echo
echo "=== expdb magic / first bytes (read-only) ==="
"$ADB" shell "su -c 'dd if=/dev/block/by-name/expdb bs=512 count=4 2>/dev/null | od -A d -t x1z | head -20'" 2>&1
