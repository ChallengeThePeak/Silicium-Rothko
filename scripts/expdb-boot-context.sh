#!/bin/bash
# Show the context around the last boot-image load in an expdb strings dump.
# This is where LK hands control to whatever boot.img contains, so anything the
# UEFI payload printed before dying would appear just after it.
#
# Usage: expdb-boot-context.sh [txt] [before] [after]
set -uo pipefail

TXT="${1:-/mnt/d/漏洞/UNIXNU/适配K70U/work/expdb/expdb-full-20261025-005209.txt}"
BEFORE="${2:-25}"
AFTER="${3:-60}"

if [ ! -f "$TXT" ]; then
  echo "ERROR: $TXT missing" >&2
  exit 1
fi

line=$(grep -an 'load_bootinfo_from_hdr:72' "$TXT" | tail -1 | cut -d: -f1)

if [ -z "$line" ]; then
  echo "no boot-image load record found" >&2
  exit 1
fi

start=$((line - BEFORE))
[ "$start" -lt 1 ] && start=1
end=$((line + AFTER))

echo "last boot load at line $line; showing $start..$end"
echo "---------------------------------------------------"
sed -n "${start},${end}p" "$TXT"
