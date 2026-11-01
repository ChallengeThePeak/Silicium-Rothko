#!/bin/bash
set -u
U=/home/ubuntu/rothko-upstream-20261102/uefi-full
echo "=== SYS_MEM_CAP_XN / TESTED 定义 ==="
grep -rn "SYS_MEM_CAP_XN\|SYS_MEM\b" "$U/Silicon/Silicium" --include="*.h" | head -10
echo
echo "=== 枚举定义所在文件 ==="
grep -rln "SYS_MEM_CAP_XN" "$U/Silicon/Silicium" | head -5
echo
echo "=== 与 EFI_RESOURCE_ATTRIBUTE 的映射 ==="
for f in $(grep -rln "SYS_MEM_CAP_XN" "$U/Silicon/Silicium" --include="*.h" | head -3); do
  echo "### $f"
  grep -n -B3 -A12 "SYS_MEM_CAP_XN" "$f" | head -40
done
