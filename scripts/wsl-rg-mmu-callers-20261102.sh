#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
U=/home/ubuntu/rothko-upstream-20261102/uefi-full

echo "=== ArmConfigureMmu 的所有调用点 ==="
rg -n "ArmConfigureMmu" "$U/Mu_Basecore" "$U/Silicon/Silicium" -g "*.c" | grep -v "ArmMmuLibCore.c" | head -15

echo
echo "=== ArmCpuDxe 是否重配 MMU / 改 TCR ==="
rg -n "ArmConfigureMmu|ArmSetTCR|TCR|ArmSetMemoryAttributes" "$U/Mu_Basecore/ArmPkg/Drivers/CpuDxe" -g "*.c" | head -20

echo
echo "=== ArmSetMemoryAttributes 是否可能重建根表 ==="
rg -n "ArmConfigureMmu|ReconfigureMmu|NewTranslationTable" "$U/Mu_Basecore/UefiCpuPkg/Library/ArmMmuLib/AArch64/ArmMmuLibCore.c" | head -15
