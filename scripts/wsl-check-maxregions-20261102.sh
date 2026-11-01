#!/bin/bash
set -u
U=/home/ubuntu/rothko-upstream-20261102/uefi-full
echo "=== MAX_ARM_MEMORY_REGION_DESCRIPTOR_COUNT 定义 ==="
grep -rn "MAX_ARM_MEMORY_REGION_DESCRIPTOR_COUNT" "$U" --include="*.h" 2>/dev/null | head -8
echo
echo "=== ArmConfigureMmu 里如何定地址宽度 ==="
A=$(find "$U/Mu_Basecore/ArmPkg/Library/ArmMmuLib" -name "*.c" | head -3)
echo "$A"
for f in $A; do
  echo "### $f"
  grep -nE "T0SZ|MaxAddress|GetRootTranslationTableInfo|TranslationTableInfo|TCR|VirtualAddress" "$f" | head -12
done
