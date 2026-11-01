#!/bin/bash
set -u
U=/home/ubuntu/rothko-upstream-20261102/uefi-full
echo "=== 谁打印 MMU: %d regions ==="
grep -rn "regions" "$U/Silicon/Silicium" --include="*.c" 2>/dev/null | head -5
echo
echo "=== T0SZ / TCR / 地址宽度相关 ==="
grep -rn "T0SZ\|TCR_T0SZ\|ArmSetTCR\|AddressSpaceBits\|TTBR0" "$U/Silicon/Silicium" --include="*.c" --include="*.h" 2>/dev/null | head -20
echo
echo "=== ArmMmuLib 里的映射实现 ==="
grep -rln "ArmSetMemoryAttributes\|MmuSetAttributes" "$U/Silicon/Silicium" "$U/Mu_Basecore/ArmPkg" --include="*.c" 2>/dev/null | head -8
