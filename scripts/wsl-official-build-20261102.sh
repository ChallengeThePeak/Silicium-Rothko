#!/bin/bash
# 官方链：stuart update（带重试）+ DeviceBuild 编译
set -u
U=/home/ubuntu/rothko-upstream-20261102/uefi-full
export PATH="/home/ubuntu/mono/usr/bin:$HOME/.local/bin:$PATH"
export LD_LIBRARY_PATH="/home/ubuntu/mono/usr/lib"
export MONO_PATH="/home/ubuntu/mono/usr/lib/mono/4.5"
cd "$U" || exit 1

echo "=== 环境 ==="
mono --version 2>&1 | head -1
command -v stuart_setup stuart_update stuart_build 2>/dev/null

echo
echo "=== stuart update（最多 4 次重试）==="
for i in 1 2 3 4; do
  echo "--- 第 $i 次 $(date +%H:%M:%S) ---"
  out=$(timeout 1200 python3 Platforms/Xiaomi/rothkoPkg/DeviceBuild.py --update 2>&1)
  echo "$out" | grep -E "SECTION - Summary|PROGRESS - Success|ERROR - Error|ERROR -|not met|Failed to fetch" | tail -8
  if echo "$out" | grep -q "PROGRESS - Success"; then echo "UPDATE OK"; break; fi
  sleep 5
done

echo
echo "=== stuart setup（确保子模块/环境就绪）==="
timeout 600 python3 Platforms/Xiaomi/rothkoPkg/DeviceBuild.py --setup 2>&1 | grep -E "PROGRESS - Success|ERROR" | tail -3

echo
echo "=== 编译 FD ==="
timeout 3600 python3 Platforms/Xiaomi/rothkoPkg/DeviceBuild.py \
  TARGET=DEBUG ENABLE_SECUREBOOT=0 \
  FD_BASE=0x40400000 FD_SIZE=0x200000 FD_BLOCKS=0x200 \
  DEVICE_MODEL=0 DISABLE_DEBUG_MACRO_CHECK=TRUE 2>&1 | tail -40

echo
echo "=== 产物 ==="
ls -l Build/rothkoPkg/*/FV/*.fd 2>/dev/null
sha256sum Build/rothkoPkg/*/FV/*.fd 2>/dev/null
