#!/bin/bash
# 对比上游 uefi/rothko 平台包与本地 Mu-Silicium 树的关键差异
set -u
UP=/home/ubuntu/rothko-upstream-20261102/uefi-src
LOC=/home/ubuntu/rothko-evidence-20261101/Mu-Silicium-keepalive-clean

echo "=== 上游 rothkoPkg 文件清单 ==="
find "$UP/Platforms/Xiaomi/rothkoPkg" -maxdepth 2 -type f | sed "s#$UP/##" | sort | head -40
echo
echo "=== 上游 DXE.inc 全文 ==="
cat "$UP/Platforms/Xiaomi/rothkoPkg/Include/DXE.inc" 2>&1
echo
echo "=== 本地 DXE.inc 位置 ==="
find "$LOC" -name "DXE.inc" -path "*rothko*" 2>/dev/null | head -5
