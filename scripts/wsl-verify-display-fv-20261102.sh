#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
U=/home/ubuntu/rothko-upstream-20261102/uefi-full
B="$U/Build/rothkoPkg/DEBUG_CLANGDWARF"

echo "=== FV 文件清单里是否有 RothkoDisplayDxe ==="
rg -n "RothkoDisplayDxe" "$B/FV/FVMAIN.txt" "$B/FV/FVMAIN.inf" 2>/dev/null | head -5

echo
echo "=== flat .efi 是否生成 ==="
find "$B/AARCH64" -name "RothkoDisplayDxe.efi" 2>/dev/null | head -3
ls -l $(find "$B/AARCH64" -name "RothkoDisplayDxe.efi" 2>/dev/null | head -1) 2>/dev/null | awk '{print $5, $9}'

echo
echo "=== SimpleFbDxe 是否被排除（USE_CUSTOM_DISPLAY_DRIVER=1）==="
find "$B/AARCH64" -name "SimpleFbDxe.efi" 2>/dev/null | head -2 || true
rg -c "SimpleFbDxe" "$B/FV/FVMAIN.txt" 2>/dev/null || echo "SimpleFbDxe 不在 FV（符合预期）"

echo
echo "=== 内存表区域数（应含显示区）==="
rg -c "AddMem|AddDev" "$U/Platforms/Xiaomi/rothkoPkg/Library/MemoryMapLib/MemoryMapLib.c" 2>/dev/null
