#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
U=/home/ubuntu/rothko-upstream-20261102/uefi-full
I="$U/Silicon/Silicium/SiliciumPkg/Library/MemoryInitPeiLib/MemoryInitPeiLib.inf"

echo "=== SEC .inf 全文 ==="
cat "$I"

echo
echo "=== SEC 源码里新加的发布代码 ==="
rg -n -A6 "Publish the frame buffer geometry" "$U/Silicon/Silicium/SiliciumPkg/Library/MemoryInitPeiLib/MemoryInitPei.c" | head -20

echo
echo "=== 构建日志里是否提到 MemoryMapHelperLib ==="
rg -n "MemoryMapHelperLib" "$U/Build/BUILDLOG_rothkoPkg.txt" 2>/dev/null | head -6 || echo "（构建日志里没有）"

echo
echo "=== 最终 FD 里 RothkoDisplayDxe 是否还在 ==="
rg -c "RothkoDisplayDxe" "$U/Build/rothkoPkg/DEBUG_CLANGDWARF/FV/FVMAIN.inf" 2>/dev/null || echo 0
