#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
U=/home/ubuntu/rothko-upstream-20261102/uefi-full

echo "=== 家目录下的 Mu-Silicium 树（可能含 RothkoDisplayDxe）==="
ls -d /home/ubuntu/*Mu-Silicium* /home/ubuntu/*keepalive* 2>/dev/null | head -10

echo
echo "=== 上游树里搜 RothkoDisplayDxe / SimpleFB / DALI / GOP ==="
rg -l -i "RothkoDisplay|SimpleFB|SimpleFrameBuffer|DALI|GraphicsOutput" "$U/Platforms" "$U/Silicon/Silicium/SiliciumPkg" 2>/dev/null | head -20

echo
echo "=== 上游 SiliciumPkg 的 Drivers 目录 ==="
ls "$U/Silicon/Silicium/SiliciumPkg/Drivers" 2>/dev/null | head -30

echo
echo "=== 上游 DXE.inc 全文 ==="
cat "$U/Platforms/Xiaomi/rothkoPkg/Include/DXE.inc" 2>/dev/null | head -50
