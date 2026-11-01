#!/bin/bash
set -u
echo "=== ProjectMu feed 连通性（重测）==="
timeout 30 curl -sS -o /dev/null -w "index.json=%{http_code}\n" \
  "https://pkgs.dev.azure.com/projectmu/mu/_packaging/Basetools-Binary/nuget/v3/index.json" 2>&1 | tail -1
timeout 60 curl -sS -o /dev/null -w "nupkg=%{http_code} %{size_download}B\n" \
  "https://pkgs.dev.azure.com/projectmu/mu/_packaging/Basetools-Binary/nuget/v3/flat2/mu_nasm/20016.1.1/mu_nasm.20016.1.1.nupkg" 2>&1 | tail -1

echo
echo "=== mono 配置目录 ==="
ls -d /home/ubuntu/mono/etc/mono 2>/dev/null && ls /home/ubuntu/mono/etc/mono | head -5
grep -m3 "System.Native" /home/ubuntu/mono/etc/mono/config 2>/dev/null

echo
echo "=== 带 MONO_CFG_DIR 重试 NuGet ==="
export MONO_CFG_DIR=/home/ubuntu/mono/etc
export PATH=/home/ubuntu/mono/usr/bin:$PATH
export LD_LIBRARY_PATH=/home/ubuntu/mono/usr/lib
timeout 60 mono /home/ubuntu/nuget/NuGet-6.4.0.exe help 2>&1 | head -8
