#!/bin/bash
set -u
echo "=== ProjectMu feed 连通性 ==="
timeout 30 curl -sS -o /dev/null -w "index.json: %{http_code}\n" \
  "https://pkgs.dev.azure.com/projectmu/mu/_packaging/Basetools-Binary/nuget/v3/index.json" 2>&1 | tail -2
timeout 40 curl -sS -o /dev/null -w "flat2 nupkg: %{http_code} %{size_download}B\n" \
  "https://pkgs.dev.azure.com/projectmu/mu/_packaging/Basetools-Binary/nuget/v3/flat2/mu_nasm/20016.1.1/mu_nasm.20016.1.1.nupkg" 2>&1 | tail -2

echo
echo "=== mono 相关包（找 System.Native 提供者）==="
apt-cache pkgnames 2>/dev/null | grep -i "^libmono" | head -40

echo
echo "=== 已解包的 mono 目录里是否有 native ==="
ls /home/ubuntu/mono/usr/lib/mono/4.5/ 2>/dev/null | grep -i "native\|Facades" | head -5
find /home/ubuntu/mono -name "*.so" 2>/dev/null | head -5
