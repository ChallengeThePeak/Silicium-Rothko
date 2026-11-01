#!/bin/bash
# Full read-only dump of the rothko expdb partition, then strings on the whole
# thing. No truncation: the point is to see everything the device recorded.
#
# Usage: dump-expdb-full.sh [output-dir]
set -uo pipefail

ADB="/mnt/i/刷机/root/scrcpy-win64-v3.2/adb.exe"
[ -x "$ADB" ] || ADB=adb

OUTDIR="${1:-/mnt/d/漏洞/UNIXNU/适配K70U/work/expdb}"
STAMP=$(python3 -c 'import time; print(time.strftime("%Y%m%d-%H%M%S"))')
BIN="$OUTDIR/expdb-full-$STAMP.bin"
TXT="$OUTDIR/expdb-full-$STAMP.txt"

mkdir -p "$OUTDIR"

echo "=== probing partition size ==="
"$ADB" shell "su -c 'blockdev --getsize64 /dev/block/by-name/expdb'" 2>&1 | tr -d '\r'

echo "=== dumping whole partition -> $BIN ==="
"$ADB" exec-out "su -c 'dd if=/dev/block/by-name/expdb bs=1048576 2>/dev/null'" > "$BIN"

size=$(stat -c %s "$BIN" 2>/dev/null || echo 0)
echo "wrote $size bytes"
if [ "$size" -lt 1048576 ]; then
  echo "ERROR: dump too small (adb or root problem)" >&2
  exit 1
fi
sha256sum "$BIN"

echo "=== strings (min length 4) -> $TXT ==="
strings -a -n 4 "$BIN" > "$TXT"
ls -l "$TXT"
echo "lines: $(wc -l < "$TXT")"
