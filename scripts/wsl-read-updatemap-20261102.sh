#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
F=/home/ubuntu/rothko-upstream-20261102/uefi-full/Mu_Basecore/UefiCpuPkg/Library/ArmMmuLib/AArch64/ArmMmuLibCore.c

echo "=== UpdateRegionMapping 签名与主循环 ==="
rg -n -A60 "^UpdateRegionMapping \(" "$F" | head -75

echo
echo "=== NextLevelTable / BlockShift 相关 ==="
rg -n "BlockShift|NextLevelTable|TT_ADDRESS_MASK|LevelShift" "$F" | head -20
