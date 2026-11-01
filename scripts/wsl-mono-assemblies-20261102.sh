#!/bin/bash
# 补 mono 缺失的程序集（NuGet 需要 System.ComponentModel.Composition 等）
set -u
cd /home/ubuntu/mono-debs || exit 1

PKGS="libmono-system-componentmodel-composition4.0-cil libmono-system-runtime-serialization4.0-cil libmono-system-core4.0-cil libmono-system-io-compression-filesystem4.0-cil libmono-system-net-http4.0-cil libmono-system-security4.0-cil libmono-system-xml4.0-cil libmono-system-numerics4.0-cil libmono-system-drawing4.0-cil libmono-microsoft-csharp4.0-cil libmono-csharp4.0c-cil"

echo "=== 递归解析依赖 ==="
apt-cache depends --recurse --no-recommends --no-suggests --no-conflicts \
  --no-breaks --no-replaces --no-enhances $PKGS 2>/dev/null \
  | grep -E '^[a-z0-9][a-z0-9.+-]*$' | sort -u > pkgs2.txt
wc -l < pkgs2.txt

echo "=== 下载 ==="
timeout 900 apt-get download $(tr '\n' ' ' < pkgs2.txt) 2>&1 | tail -3
echo "deb 个数: $(ls *.deb 2>/dev/null | wc -l)"

echo "=== 解包 ==="
for d in *.deb; do dpkg -x "$d" /home/ubuntu/mono 2>/dev/null; done

echo "=== 重试 NuGet ==="
export MONO_CFG_DIR=/home/ubuntu/mono/etc
export PATH=/home/ubuntu/mono/usr/bin:$PATH
export LD_LIBRARY_PATH=/home/ubuntu/mono/usr/lib
timeout 90 mono /home/ubuntu/nuget/NuGet-6.4.0.exe locals global-packages -list 2>&1 | tail -4
