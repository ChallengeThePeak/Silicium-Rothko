#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
D=/home/ubuntu/rothko-evidence-20261101/Mu-Silicium-fv-membership-fixed/Platforms/Xiaomi/rothkoPkg/Drivers/RothkoDisplayDxe

echo "=== 文件与行数 ==="
wc -l "$D"/*.c "$D"/*.h "$D"/*.inf 2>/dev/null

echo
echo "=== 函数列表 ==="
rg -n "^[A-Za-z_][A-Za-z0-9_ ]*\(" "$D/RothkoDisplayDxe.c" 2>/dev/null | rg -v "^\s*//" | head -40

echo
echo "=== 安装的协议 / GOP 相关 ==="
rg -n "InstallMultipleProtocolInterfaces|InstallProtocolInterface|gEfiGraphicsOutputProtocolGuid|gEfi.*ProtocolGuid|RothkoDisplayProtocol|EFI_GRAPHICS_OUTPUT_PROTOCOL" "$D/RothkoDisplayDxe.c" 2>/dev/null | head -20

echo
echo "=== .inf 内容 ==="
cat "$D/RothkoDisplayDxe.inf"

echo
echo "=== Bounds 头文件 ==="
head -60 "$D/RothkoDisplayBounds.h"
