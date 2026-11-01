#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
U=/home/ubuntu/rothko-upstream-20261102/uefi-full

echo "=== 平台把 ArmMmuLib 映射到哪个实现 ==="
rg -n "ArmMmuLib\s*\|" "$U/Silicon/Silicium/SiliciumPkg/SiliciumPkg.dsc.inc" "$U/Platforms/Xiaomi/rothkoPkg/rothko.dsc" | head -10

echo
echo "=== 树内所有 ArmMmuLib 实现目录 ==="
rg --files "$U" -g "**/ArmMmuLib/**/*.c" | head -10

echo
echo "=== Silicium 版 ArmMmuLib 里的 T0SZ/地址宽度 ==="
for f in $(rg --files "$U/Silicon" -g "**/ArmMmuLib/**/*.c" | head -3); do
  echo "### $f"
  rg -n "T0SZ|TCR|2MB|BLOCK|MaxAddress|PhysicalAddressBits" "$f" | head -12
done
