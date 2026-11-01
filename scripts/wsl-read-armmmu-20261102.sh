#!/bin/bash
set -u
F=/home/ubuntu/rothko-upstream-20261102/uefi-full/Mu_Basecore/UefiCpuPkg/Library/ArmMmuLib/AArch64/ArmMmuLibCore.c
echo "=== ArmConfigureMmu ==="
awk '/^ArmConfigureMmu/,/^}/' "$F" | head -80
echo
echo "=== 地址宽度 / T0SZ 相关引用 ==="
grep -nE "T0SZ|MaxAddress|GetRootTranslationTableInfo|RootTranslationTableInfo|TCR" "$F" | head -20
