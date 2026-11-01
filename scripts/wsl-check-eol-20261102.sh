#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
U=/home/ubuntu/rothko-upstream-20261102/uefi-full
Q=/home/ubuntu/quarantine

echo "=== 行尾检测（备份 vs 当前）==="
for f in "$Q/DXE.inc.orig-"* "$Q/rothko.dsc.orig-"*; do
  [ -f "$f" ] || continue
  printf "%-60s CR=%s LF=%s\n" "$(basename $f)" \
    "$(tr -cd '\r' < "$f" | wc -c)" "$(tr -cd '\n' < "$f" | wc -c)"
done
for f in "$U/Platforms/Xiaomi/rothkoPkg/Include/DXE.inc" "$U/Platforms/Xiaomi/rothkoPkg/rothko.dsc" "$U/Platforms/Xiaomi/rothkoPkg/Include/APRIORI.inc"; do
  printf "%-60s CR=%s LF=%s\n" "$(basename $f)" \
    "$(tr -cd '\r' < "$f" | wc -c)" "$(tr -cd '\n' < "$f" | wc -c)"
done
