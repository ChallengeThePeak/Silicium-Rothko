#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
U=/home/ubuntu/rothko-upstream-20261102/uefi-full

echo "=== SiliciumPkg/Sec 目录 ==="
rg --files "$U/Silicon/Silicium/SiliciumPkg/Sec" | head -20

echo
echo "=== 全树 spsr 写 / eret（排除 openssl 等噪音）==="
rg -n "spsr_el2|spsr_el1|eret" "$U/Silicon/Silicium/SiliciumPkg" "$U/Mu_Basecore/ArmPlatformPkg" -g "*.S" -g "*.asm" | head -20

echo
echo "=== ArmReadCurrentEL 用法 ==="
rg -n "ArmReadCurrentEL \(\)" "$U/Silicon/Silicium/SiliciumPkg" "$U/Mu_Basecore/ArmPlatformPkg/PeilessSec" | head -10
