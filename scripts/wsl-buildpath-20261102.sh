#!/bin/bash
set -u
OLD=/home/ubuntu/rothko-evidence-20261101/Mu-Silicium-keepalive-clean
NEW=/home/ubuntu/rothko-upstream-20261102/uefi-full

echo "=== 旧树 DEBUG_CLANGPDB 目录 ==="
ls "$OLD/Build/rothkoPkg/DEBUG_CLANGPDB" 2>/dev/null | head -10
echo "--- 日志 ---"
ls "$OLD/Build"/*.txt "$OLD/Build/rothkoPkg"/*.txt "$OLD/Build/rothkoPkg/DEBUG_CLANGPDB"/*.txt 2>/dev/null | head -5
echo
echo "--- 日志里的编译命令 ---"
grep -h -m5 -E "Command line|build -p|BuildEnv|edksetup|TOOL_CHAIN" "$OLD/Build/rothkoPkg/DEBUG_CLANGPDB/"*.txt 2>/dev/null | head -10
echo
echo "=== 新树 build_uefi.py 用法 ==="
head -40 "$NEW/build_uefi.py" 2>/dev/null
echo
echo "=== 新树 setup_env.sh 是否存在 ==="
ls -l "$NEW/setup_env.sh" 2>/dev/null || echo "无 setup_env.sh"
echo "=== 旧树 setup_env.sh 内容 ==="
head -30 "$OLD/setup_env.sh" 2>/dev/null
