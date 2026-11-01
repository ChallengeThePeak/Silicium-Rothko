#!/bin/bash
set -u
U=/home/ubuntu/rothko-upstream-20261102/uefi-full
echo "=== ArmGetPhysicalAddressBits 实现 ==="
F=$(grep -rl "ArmGetPhysicalAddressBits" "$U/Mu_Basecore/ArmPkg/Library" --include="*.c" | head -1)
echo "$F"
awk '/ArmGetPhysicalAddressBits/,/^}/' "$F" | head -45
echo
echo "=== MAX_VA_BITS / MAX_VA_BITS_48 定义 ==="
grep -rn "MAX_VA_BITS" "$U/Mu_Basecore/UefiCpuPkg/Library/ArmMmuLib/AArch64/ArmMmuLibCore.c" | head -5
grep -rn "define MAX_VA_BITS" "$U/Mu_Basecore" --include="*.h" | head -5
