#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
U=/home/ubuntu/rothko-upstream-20261102/uefi-full

echo "=== 谁在找 \"Incoming DTB\" ==="
rg -rn "Incoming DTB" "$U/Platforms/Xiaomi/rothkoPkg" "$U/Silicon/Silicium/SiliciumPkg" 2>/dev/null | head -10

echo
echo "=== 谁在找 \"LK DTB\" ==="
rg -rn '"LK DTB"' "$U/Platforms/Xiaomi/rothkoPkg" "$U/Silicon/Silicium/SiliciumPkg" 2>/dev/null | head -10

echo
echo "=== SEC 里 gSiliciumEntryArgHob 的写入（HOB 载荷宽度）==="
rg -n -B4 -A12 "gSiliciumEntryArgHobGuid" "$U/Silicon/Silicium/SiliciumPkg/Sec/Sec.c" | head -40
