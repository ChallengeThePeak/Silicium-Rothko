#!/bin/bash
# 定位 mu_nasm NuGet 失败原因：nuget.exe 位置、mono 证书库、手动安装测试
set -u
export PATH="/home/ubuntu/mono/usr/bin:$HOME/.local/bin:$PATH"
export LD_LIBRARY_PATH="/home/ubuntu/mono/usr/lib"

echo "=== nuget.exe 位置 ==="
find /home/ubuntu -maxdepth 6 -iname "nuget.exe" 2>/dev/null | head -5

echo "=== mono 证书同步工具 ==="
ls /home/ubuntu/mono/usr/bin/cert-sync 2>/dev/null || echo "无 cert-sync"
ls -d /home/ubuntu/mono/usr/lib/mono 2>/dev/null

echo "=== 手动跑 nuget 看看真实报错 ==="
NUGET=$(find /home/ubuntu -maxdepth 6 -iname "nuget.exe" 2>/dev/null | head -1)
if [ -n "${NUGET:-}" ]; then
  mkdir -p /home/ubuntu/nuget-test
  timeout 180 mono "$NUGET" install mu_nasm -Version 20016.1.1 \
    -OutputDirectory /home/ubuntu/nuget-test -NonInteractive -Verbosity detailed 2>&1 | tail -25
else
  echo "找不到 nuget.exe"
fi
