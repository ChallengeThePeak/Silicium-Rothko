#!/bin/bash
# 绕开 stuart：用树内 BaseTools 源码编译，再用原生 build 编 rothko FD
set -u
U=/home/ubuntu/rothko-upstream-20261102/uefi-full
export WORKSPACE="$U"
export EDK_TOOLS_PATH="$U/Mu_Basecore/BaseTools"
export PACKAGES_PATH="$U:$U/Mu_Basecore:$U/UniXNU/package"
export PATH="$EDK_TOOLS_PATH/BinWrappers/PosixLike:$PATH"
export PYTHON_COMMAND=python3

cd "$U" || exit 1

echo "=== 0) 前置核对 ==="
ls -d "$EDK_TOOLS_PATH/Source/C" 2>&1 | tail -1
ls -d "$PACKAGES_PATH" UniXNU/package 2>&1 | tail -2
grep -nE "CLANGDWARF|CLANGPDB" "$EDK_TOOLS_PATH/Conf/tools_def.txt" 2>/dev/null | head -3

echo
echo "=== 1) 编译 BaseTools ==="
if [ ! -x "$EDK_TOOLS_PATH/Source/C/bin/GenFw" ]; then
  make -C "$EDK_TOOLS_PATH/Source/C" -j"$(nproc)" 2>&1 | tail -15
else
  echo "BaseTools 已编译，跳过"
fi
ls -l "$EDK_TOOLS_PATH/Source/C/bin/GenFw" 2>&1 | tail -1

echo
echo "=== 2) 原生 build（DEBUG / CLANGDWARF）==="
mkdir -p Conf
if [ ! -f Conf/target.txt ]; then
  cp "$EDK_TOOLS_PATH/Conf/target.template" Conf/target.txt 2>/dev/null || true
fi
timeout 3600 "$EDK_TOOLS_PATH/BinWrappers/PosixLike/build" \
  -p Platforms/Xiaomi/rothkoPkg/rothko.dsc \
  -a AARCH64 -t CLANGDWARF -b DEBUG -n "$(nproc)" \
  -D FD_BASE=0x40400000 -D FD_SIZE=0x200000 -D FD_BLOCKS=0x200 \
  -D ENABLE_SECUREBOOT=0 -D DEVICE_MODEL=0 -D DISABLE_DEBUG_MACRO_CHECK=TRUE 2>&1 | tail -45

echo
echo "=== 3) 产物 ==="
find Build -name "*.fd" -newermt "-60 minutes" 2>/dev/null | head -5
ls -l Build/rothkoPkg/*/FV/*.fd 2>/dev/null | tail -5
