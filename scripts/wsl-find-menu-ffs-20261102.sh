#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
U=/home/ubuntu/rothko-upstream-20261102/uefi-full

echo "=== 报错那句的源码 ==="
rg -rn -B12 "BootManagerMenu FFS section can not be found" "$U/Mu_Basecore/MdeModulePkg/Universal/BdsDxe" 2>/dev/null | head -30

echo
echo "=== SiliciumPkg/Extra.fdf.inc 全文 ==="
cat "$U/Silicon/Silicium/SiliciumPkg/Extra.fdf.inc" 2>/dev/null | head -40

echo
echo "=== rothko.fdf 里的 include 与 FILE 段 ==="
rg -n "!include|FILE |BootManager" "$U/Platforms/Xiaomi/rothkoPkg/rothko.fdf" | head -25
