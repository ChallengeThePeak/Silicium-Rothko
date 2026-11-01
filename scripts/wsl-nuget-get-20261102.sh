#!/bin/bash
# 下载 NuGet.exe 并用 mono 测试安装 mu_nasm
set -u
export PATH="/home/ubuntu/mono/usr/bin:$HOME/.local/bin:$PATH"
export LD_LIBRARY_PATH="/home/ubuntu/mono/usr/lib"

echo "=== pytool 里的下载地址 ==="
grep -rn "dist.nuget.org\|nuget.exe" /home/ubuntu/.local/lib/python3.12/site-packages/edk2toolext/bin/nuget.py 2>/dev/null | head -8

mkdir -p /home/ubuntu/nuget
for u in "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe" \
         "https://dist.nuget.org/win-x86-commandline/v6.11.0/nuget.exe"; do
  echo "--- 尝试 $u ---"
  if timeout 120 curl -sSL --retry 3 --retry-delay 2 -o /home/ubuntu/nuget/NuGet.exe "$u"; then
    sz=$(stat -c %s /home/ubuntu/nuget/NuGet.exe 2>/dev/null || echo 0)
    echo "下载字节: $sz"
    [ "$sz" -gt 1000000 ] && break
  fi
done
ls -l /home/ubuntu/nuget/NuGet.exe 2>/dev/null

echo "=== mono 跑 NuGet.exe ==="
timeout 120 mono /home/ubuntu/nuget/NuGet.exe help 2>&1 | head -5

echo "=== 试装 mu_nasm ==="
rm -rf /home/ubuntu/nuget-test 2>/dev/null || true
mkdir -p /home/ubuntu/nuget-test
timeout 240 mono /home/ubuntu/nuget/NuGet.exe install mu_nasm -Version 20016.1.1 \
  -OutputDirectory /home/ubuntu/nuget-test -NonInteractive 2>&1 | tail -15
ls /home/ubuntu/nuget-test 2>/dev/null | head -5
