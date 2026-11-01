#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
OLD=/home/ubuntu/rothko-evidence-20261101/Mu-Silicium-fv-membership-fixed
U=/home/ubuntu/rothko-upstream-20261102/uefi-full

echo "=== 旧树（已验证）MemoryMapLib.c 全文 ==="
cat "$OLD/Platforms/Xiaomi/rothkoPkg/Library/MemoryMapLib/MemoryMapLib.c"

echo
echo "=== 上游是否有 FdtLib / BootDevices.h ==="
rg --files "$U" 2>/dev/null | rg -i "FdtLib|BootDevices" | head -10
