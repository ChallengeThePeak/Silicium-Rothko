#!/bin/bash
# 按上游原样编译带 pstore 的 DEBUG FD
set -u
U=/home/ubuntu/rothko-upstream-20261102/uefi-full
export PATH="$HOME/.local/bin:$PATH"
cd "$U" || exit 1

echo "=== 1) UniXNU 只读软链（不改动其内容）==="
if [ -e UniXNU ] && [ ! -L UniXNU ]; then
  echo "已存在实体目录 UniXNU，跳过"
elif [ ! -e UniXNU ]; then
  ln -s /home/ubuntu/UniXNU UniXNU
  echo "已建立 UniXNU -> /home/ubuntu/UniXNU"
else
  echo "软链已存在: $(readlink UniXNU)"
fi
ls -d UniXNU/package 2>&1 | tail -1
ls UniXNU/package 2>/dev/null | head -5

echo
echo "=== 2) stuart setup ==="
timeout 900 python3 Platforms/Xiaomi/rothkoPkg/DeviceBuild.py --setup 2>&1 | tail -15

echo
echo "=== 3) stuart update ==="
timeout 900 python3 Platforms/Xiaomi/rothkoPkg/DeviceBuild.py --update 2>&1 | tail -20

echo
echo "=== 4) 编译 ==="
timeout 3600 python3 Platforms/Xiaomi/rothkoPkg/DeviceBuild.py \
  TARGET=DEBUG ENABLE_SECUREBOOT=0 \
  FD_BASE=0x40400000 FD_SIZE=0x200000 FD_BLOCKS=0x200 \
  DEVICE_MODEL=0 DISABLE_DEBUG_MACRO_CHECK=TRUE 2>&1 | tail -40

echo
echo "=== 5) 产物 ==="
ls -l Build/rothkoPkg/DEBUG_CLANGDWARF/FV/*.fd 2>/dev/null
sha256sum Build/rothkoPkg/DEBUG_CLANGDWARF/FV/*.fd 2>/dev/null
