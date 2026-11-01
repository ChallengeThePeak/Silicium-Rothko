#!/bin/bash
set -u
export MONO_CFG_DIR=/home/ubuntu/mono/etc
export PATH=/home/ubuntu/mono/usr/bin:$PATH
export LD_LIBRARY_PATH=/home/ubuntu/mono/usr/lib

echo "=== 下载 pytool 指定的 NuGet 6.4.0 ==="
mkdir -p /home/ubuntu/nuget
if [ ! -s /home/ubuntu/nuget/NuGet-6.4.0.exe ]; then
  timeout 300 curl -sSL --retry 3 --retry-delay 2 -o /home/ubuntu/nuget/NuGet-6.4.0.exe \
    "https://dist.nuget.org/win-x86-commandline/v6.4.0/nuget.exe"
fi
ls -l /home/ubuntu/nuget/NuGet-6.4.0.exe
sha256sum /home/ubuntu/nuget/NuGet-6.4.0.exe
echo "期望 sha256: 26730829b240581a3e6a4e276b9ace088930032df0c680d5591beccf6452374e"

echo
echo "=== mono 带 MONO_CFG_DIR 运行 ==="
timeout 90 mono /home/ubuntu/nuget/NuGet-6.4.0.exe help 2>&1 | head -6
echo
echo "=== 查 global-packages 路径（pytool 就是这么调的）==="
timeout 60 mono /home/ubuntu/nuget/NuGet-6.4.0.exe locals global-packages -list 2>&1 | tail -3
