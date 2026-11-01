#!/bin/bash
set -u
OLD=/home/ubuntu/rothko-evidence-20261101/Mu-Silicium-keepalive-clean
echo "=== 旧树顶层 ==="
ls "$OLD" | head -20
echo
echo "=== 旧树里的构建脚本 ==="
ls "$OLD"/*.sh "$OLD"/scripts/*.sh 2>/dev/null | head -10
echo
echo "=== 旧树 Build 目录 ==="
ls "$OLD/Build" 2>/dev/null | head -5
ls "$OLD/Build/rothkoPkg" 2>/dev/null | head -5
echo
echo "=== BUILDLOG 头部（看用的命令与工具路径）==="
head -25 "$OLD"/Build/BUILDLOG_rothkoPkg.txt 2>/dev/null
echo
echo "=== 是否有 nasm 依赖落地 ==="
find /home/ubuntu -maxdepth 6 -name "nasm" -type f 2>/dev/null | head -5
find /home/ubuntu -maxdepth 6 -iname "*mu_nasm*" 2>/dev/null | head -5
