#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
U=/home/ubuntu/rothko-upstream-20261102/uefi-full

echo "=== 各平台的帧缓冲 PCD ==="
for d in "$U"/Platforms/Xiaomi/*/; do
  n=$(basename "$d")
  v=$(rg -n "PcdFrameBuffer" "$d"*.dsc 2>/dev/null | tr '\n' ' ' | sed 's/  */ /g')
  [ -n "$v" ] && echo "$n : $v"
done

echo
echo "=== shengPkg 的显示相关 INF 与内存表 ==="
rg -n "Display|Gop|FrameBuffer" "$U/Platforms/Xiaomi/shengPkg/Include/DXE.inc" "$U/Platforms/Xiaomi/shengPkg/Include/APRIORI.inc" 2>/dev/null | head -10
echo "--- 内存表里的显示区 ---"
rg -n "Display|FrameBuffer|VideoLfb|0xFD9|video" "$U/Platforms/Xiaomi/shengPkg/Library/MemoryMapLib/MemoryMapLib.c" 2>/dev/null | head -10

echo
echo "=== ShengDisplayDepexDxe 做了什么 ==="
head -50 "$U/Platforms/Xiaomi/shengPkg/Drivers/ShengDisplayDepexDxe/ShengDisplayDepexDxe.c" 2>/dev/null
