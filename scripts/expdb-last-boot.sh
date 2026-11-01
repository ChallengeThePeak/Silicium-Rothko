#!/bin/bash
# Reconstruct what happened in the most recent boot from the expdb tail.
#
# Prints the boot-chain lines in the order they were written, so the point where
# the log stops is visible. That stopping point is the furthest stage reached.
#
# Usage: expdb-last-boot.sh [tail-bin] [lines]
set -uo pipefail

BIN="${1:-/mnt/d/漏洞/UNIXNU/适配K70U/work/expdb/expdb-tail8m.bin}"
N="${2:-120}"

if [ ! -f "$BIN" ]; then
  echo "ERROR: $BIN missing" >&2
  exit 1
fi

echo "=== boot-chain timeline from $BIN (last $N matching lines) ==="
strings -a -n 4 "$BIN" | grep -aiE \
  'BOOT_REASON|BOOT_MODE|wdt_status|Load Image|load_bootinfo|vbmeta|avb_slot|Boot Success|cert verify|logo|boot_mode|partition|mblock name|ram_console info def|MT6989W_ECID|BLDR|CAUTION|PL_LOG_STORE|ab_ota|Long Pressed' \
  | tail -"$N"

echo
echo "=== very last 40 strings in the dump (raw) ==="
strings -a -n 4 "$BIN" | tail -40
