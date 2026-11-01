#!/bin/bash
# 一次性取齐 mono 的所有 libmono-* 程序集包
set -u
cd /home/ubuntu/mono-debs || exit 1

apt-cache pkgnames 2>/dev/null | grep -E '^libmono-' | sort -u > all_mono.txt
echo "候选包数: $(wc -l < all_mono.txt)"

echo "=== 批量下载（失败项忽略）==="
timeout 1500 apt-get download $(tr '\n' ' ' < all_mono.txt) 2>&1 | grep -E "^E:|^Err:" | head -5
echo "本地 deb 总数: $(ls *.deb 2>/dev/null | wc -l)"

echo "=== 解包 ==="
for d in *.deb; do dpkg -x "$d" /home/ubuntu/mono 2>/dev/null; done

echo "=== 测试 mono + NuGet ==="
export MONO_CFG_DIR=/home/ubuntu/mono/etc
export PATH=/home/ubuntu/mono/usr/bin:$PATH
export LD_LIBRARY_PATH=/home/ubuntu/mono/usr/lib
timeout 120 mono /home/ubuntu/nuget/NuGet.exe locals global-packages -list 2>&1 | tail -4
