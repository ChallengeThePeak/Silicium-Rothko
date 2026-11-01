#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
U=/home/ubuntu/rothko-upstream-20261102/uefi-full

echo "=== rothkoPkg/Drivers 现有内容 ==="
ls -R "$U/Platforms/Xiaomi/rothkoPkg/Drivers" 2>/dev/null | head -20

echo
echo "=== DXE.inc / APRIORI.inc 在哪被 include ==="
rg -n "DXE\.inc|APRIORI\.inc" "$U/Platforms/Xiaomi/rothkoPkg/rothko.dsc" "$U/Platforms/Xiaomi/rothkoPkg/UniXNUComponents.dsc.inc" 2>/dev/null | head -6

echo
echo "=== SiliciumPkg.dsc.inc 的 Packages 段 ==="
rg -n -A14 "^\[Packages" "$U/Silicon/Silicium/SiliciumPkg/SiliciumPkg.dsc.inc" 2>/dev/null | head -16

echo
echo "=== rothko.dsc 全文行数与开头 ==="
wc -l "$U/Platforms/Xiaomi/rothkoPkg/rothko.dsc"
head -40 "$U/Platforms/Xiaomi/rothkoPkg/rothko.dsc"
