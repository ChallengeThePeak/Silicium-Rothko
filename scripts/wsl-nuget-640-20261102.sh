#!/bin/bash
set -u
export PATH="/home/ubuntu/mono/usr/bin:$PATH"
export LD_LIBRARY_PATH="/home/ubuntu/mono/usr/lib"

echo "=== 包里带 native 的 mono 包 ==="
apt-cache pkgnames 2>/dev/null | grep -i "^libmono" | grep -iE "native|corlib|system" | head -10

echo
echo "=== 系统里是否已有 System.Native ==="
find / -name "System.Native.so" -o -name "libmono-native*" 2>/dev/null | head -5

echo
echo "=== 用 pytool 指定的 nuget 6.4.0 再试 ==="
mkdir -p /home/ubuntu/nuget
if [ ! -f /home/ubuntu/nuget/NuGet-6.4.0.exe ]; then
  timeout 180 curl -sSL --retry 3 -o /home/ubuntu/nuget/NuGet-6.4.0.exe \
    "https://dist.nuget.org/win-x86-commandline/v6.4.0/nuget.exe"
fi
ls -l /home/ubuntu/nuget/NuGet-6.4.0.exe
sha256sum /home/ubuntu/nuget/NuGet-6.4.0.exe
timeout 120 mono /home/ubuntu/nuget/NuGet-6.4.0.exe help 2>&1 | head -6
