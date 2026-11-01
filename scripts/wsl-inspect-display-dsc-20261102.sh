#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
U=/home/ubuntu/rothko-upstream-20261102/uefi-full
S="$U/Silicon/Silicium/SiliciumPkg/SiliciumPkg.dsc.inc"

echo "=== USE_CUSTOM_DISPLAY_DRIVER 相关 ==="
rg -n -B4 -A10 "USE_CUSTOM_DISPLAY_DRIVER" "$S" 2>/dev/null | head -40

echo
echo "=== DXE.inc / APRIORI.inc 的 include ==="
rg -n "DXE\.inc|APRIORI\.inc" "$S" "$U/Silicon/Silicium/SiliciumPkg" 2>/dev/null | head -10

echo
echo "=== Packages / Components 段头 ==="
rg -n "^\[Packages\]|^\[Components\]|^\[LibraryClasses\]|^\[PcdsFixedAtBuild\]" "$S" 2>/dev/null | head -10

echo
echo "=== FDF 里 DXE.inc 怎么用 ==="
rg -n "DXE\.inc|APRIORI" "$U/Platforms/Xiaomi/rothkoPkg/rothko.fdf" 2>/dev/null | head -10
