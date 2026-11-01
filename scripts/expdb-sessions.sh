#!/bin/bash
# Split an expdb strings dump into boot sessions and show what happened in each.
#
# expdb accumulates across boots: every preloader/LK run appends its own
# records. Looking only at the tail shows the most recent boot, which may not be
# the test boot at all. This finds every session boundary and reports, per
# session, whether anything from our UEFI payload appears.
#
# Usage: expdb-sessions.sh [txt]
set -uo pipefail

TXT="${1:-/mnt/d/漏洞/UNIXNU/适配K70U/work/expdb/expdb-full-20261025-005209.txt}"

if [ ! -f "$TXT" ]; then
  echo "ERROR: $TXT missing" >&2
  exit 1
fi

echo "=== markers that start a new boot session ==="
for pat in 'boot image header loaded' 'cert verify, part = lk' 'Load Image' 'lk_start' 'Boot Success'
do
  printf '  %-28s %s\n' "$pat" "$(grep -ac "$pat" "$TXT")"
done

echo
echo "=== all boot-image load sites ==="
grep -an 'load_bootinfo_from_hdr:72' "$TXT" | awk -F: '{printf "  line %-7s %s\n", $1, $2}'

echo
echo "=== all 'OTA Boot Success' sites ==="
grep -an 'OTA Boot Success' "$TXT" | awk -F: '{printf "  line %-7s %s\n", $1, $2}'

echo
echo "=== any UEFI-side signature anywhere ==="
for pat in 'ROTHKO' 'Silicium' 'SILICIUM' 'BootShim' 'SimpleTextInOut' 'GraphicsConsole' 'DXE' 'BdsDxe' 'gBS'
do
  printf '  %-18s %s\n' "$pat" "$(grep -ac "$pat" "$TXT")"
done
