#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
U=/home/ubuntu/rothko-upstream-20261102/uefi-full
OLD=/home/ubuntu/rothko-evidence-20261101/Mu-Silicium-fv-membership-fixed

echo "=== 旧树 rothko.dsc 的 [Components] 段 ==="
rg -n -A20 "^\[Components" "$OLD/Platforms/Xiaomi/rothkoPkg/rothko.dsc" 2>/dev/null | head -24

echo
echo "=== 旧树 rothko.fdf 里的 DXE.inc ==="
rg -n "DXE\.inc|APRIORI\.inc" "$OLD/Platforms/Xiaomi/rothkoPkg/rothko.fdf" 2>/dev/null | head -4

echo
echo "=== 旧树 DXE.inc 里 RothkoDisplayDxe 那行（完整路径写法）==="
rg -n "RothkoDisplayDxe" "$OLD/Platforms/Xiaomi/rothkoPkg/Include/DXE.inc" "$OLD/Platforms/Xiaomi/rothkoPkg/Include/APRIORI.inc" 2>/dev/null | head -4

echo
echo "=== 我们当前 rothko.dsc 的尾部（看有没有 [Components]）==="
tail -18 "$U/Platforms/Xiaomi/rothkoPkg/rothko.dsc"

echo
echo "=== 我们当前 DXE.inc / APRIORI.inc 里那两行 ==="
rg -n "RothkoDisplayDxe" "$U/Platforms/Xiaomi/rothkoPkg/Include/DXE.inc" "$U/Platforms/Xiaomi/rothkoPkg/Include/APRIORI.inc" | head -4
