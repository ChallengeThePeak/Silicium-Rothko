#!/bin/bash
# 对比上游 uefi/rothko 与本地 Mu-Silicium 树的 rothkoPkg
set -u
UP=/home/ubuntu/rothko-upstream-20261102/uefi-src/Platforms/Xiaomi/rothkoPkg
for LOC in /home/ubuntu/rothko-evidence-20261101/Mu-Silicium-keepalive-clean \
           /home/ubuntu/rothko-evidence-20261101/Mu-Silicium-fv-membership-fixed; do
  LP="$LOC/Platforms/Xiaomi/rothkoPkg"
  echo "############ $LOC"
  if [ ! -d "$LP" ]; then echo "  (no rothkoPkg)"; continue; fi
  echo "--- 本地 rothkoPkg 文件数: $(find "$LP" -maxdepth 2 -type f | wc -l)"
  echo "--- Include/ 条目 ---"
  ls "$LP/Include" 2>/dev/null | head -15
  echo "--- DXE.inc 行数与关键条目 ---"
  wc -l "$LP/Include/DXE.inc" 2>/dev/null
  grep -nE "RothkoDisplay|RothkoWatchdog|GraphicsConsole|BdsDxe|UniXNUDxe" "$LP/Include/DXE.inc" 2>/dev/null | head -10
  echo "--- 与上游 DXE.inc 差异统计 ---"
  diff "$UP/Include/DXE.inc" "$LP/Include/DXE.inc" 2>/dev/null | head -30
  echo "--- PstoreLog / FrameBufferSerialPortLib 是否存在 ---"
  grep -rl "PstoreLog\|K70U_UEFI_PSTORE_BEGIN" "$LOC" 2>/dev/null | head -5
  echo
done
