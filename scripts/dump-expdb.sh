#!/bin/bash
# Read-only dump of the rothko expdb partition.
#
# expdb is 128 MiB (/dev/block/sdc4). MTK writes boot-loader and pstore data
# into it across boots, so the region of interest is the front of the
# partition; dumping it in full costs minutes over adb.
#
# Usage: dump-expdb.sh [megabytes] [output]
set -uo pipefail

ADB="/mnt/i/刷机/root/scrcpy-win64-v3.2/adb.exe"
[ -x "$ADB" ] || ADB=adb

MB="${1:-32}"
OUT="${2:-/mnt/d/漏洞/UNIXNU/适配K70U/work/expdb/expdb-$(date +%Y%m%d-%H%M%S).bin}"

mkdir -p "$(dirname "$OUT")"

echo "=== dumping first ${MB} MiB of expdb -> $OUT ==="
"$ADB" exec-out "su -c 'dd if=/dev/block/by-name/expdb bs=1048576 count=${MB} 2>/dev/null'" > "$OUT"

size=$(stat -c %s "$OUT" 2>/dev/null || echo 0)
echo "wrote $size bytes"
if [ "$size" -lt 1048576 ]; then
  echo "ERROR: dump too small, adb or root problem" >&2
  exit 1
fi
sha256sum "$OUT"
