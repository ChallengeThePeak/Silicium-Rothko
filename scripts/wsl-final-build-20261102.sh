#!/bin/bash
# 官方链收尾：包入 NuGet 缓存 -> stuart_update -> 编译 FD
set -u
U=/home/ubuntu/rothko-upstream-20261102/uefi-full
CACHE=/home/ubuntu/.nuget/packages/mu_nasm/20016.1.1
PKG=/home/ubuntu/nuget-cache/mu_nasm.20016.1.1.nupkg

export MONO_CFG_DIR=/home/ubuntu/mono/etc
export PATH="/home/ubuntu/mono/usr/bin:$HOME/.local/bin:$PATH"
export LD_LIBRARY_PATH=/home/ubuntu/mono/usr/lib
export NUGET_PATH=/home/ubuntu/nuget

echo "=== 1) 放入 NuGet 全局缓存 ==="
mkdir -p "$CACHE"
python3 - "$PKG" "$CACHE" <<'PY'
import sys, zipfile
zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])
print("extracted to", sys.argv[2])
PY
cp -f "$PKG" "$CACHE/mu_nasm.20016.1.1.nupkg"
ls "$CACHE" | head -8
ls "$CACHE/mu_nasm" 2>/dev/null | head -5

echo
echo "=== 2) stuart update（应命中本地缓存）==="
cd "$U" || exit 1
out=$(timeout 1200 python3 Platforms/Xiaomi/rothkoPkg/DeviceBuild.py --update 2>&1)
echo "$out" | grep -E "PROGRESS - Success|ERROR|not met|Nuget|mu_nasm" | tail -10

echo
echo "=== 3) 编译 FD ==="
timeout 3600 python3 Platforms/Xiaomi/rothkoPkg/DeviceBuild.py \
  TARGET=DEBUG ENABLE_SECUREBOOT=0 \
  FD_BASE=0x40400000 FD_SIZE=0x200000 FD_BLOCKS=0x200 \
  DEVICE_MODEL=0 DISABLE_DEBUG_MACRO_CHECK=TRUE 2>&1 | tail -45

echo
echo "=== 4) 产物 ==="
ls -l Build/rothkoPkg/*/FV/*.fd 2>/dev/null
sha256sum Build/rothkoPkg/*/FV/*.fd 2>/dev/null
