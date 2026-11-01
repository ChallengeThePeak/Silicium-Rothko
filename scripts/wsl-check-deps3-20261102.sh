#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
OLD=/home/ubuntu/rothko-evidence-20261101/Mu-Silicium-fv-membership-fixed
U=/home/ubuntu/rothko-upstream-20261102/uefi-full

echo "=== ROTHKO_DISPLAY_BASE / SIZE 定义在哪 ==="
rg -rn "ROTHKO_DISPLAY_BASE|ROTHKO_DISPLAY_SIZE" "$OLD/Platforms" 2>/dev/null | head -8

echo
echo "=== 上游 FdtLib 的 INF 与 LibraryClasses 映射 ==="
rg --files "$U/Mu_Basecore/MdePkg/Library/BaseFdtLib" 2>/dev/null | head -8
rg -n "FdtLib" "$U/Silicon/Silicium/SiliciumPkg/SiliciumPkg.dsc.inc" "$U/Platforms/Xiaomi/rothkoPkg/rothko.dsc" 2>/dev/null | head -8

echo
echo "=== 上游 ArmSmcLib / MemoryMapHelperLib 映射 ==="
rg -n "ArmSmcLib|MemoryMapHelperLib|FrameBufferBltLib" "$U/Silicon/Silicium/SiliciumPkg/SiliciumPkg.dsc.inc" "$U/Platforms/Xiaomi/rothkoPkg/rothko.dsc" 2>/dev/null | head -10

echo
echo "=== 旧树 RothkoStage.h 全文 ==="
cat "$OLD/Mu_Basecore/MdePkg/Include/Library/RothkoStage.h"

echo
echo "=== 旧树 rothkoPkg 里 RothkoStage 相关（是否在 rothkoPkg 自带）==="
rg -rln "RothkoStage" "$OLD/Platforms/Xiaomi/rothkoPkg" 2>/dev/null | head -8
