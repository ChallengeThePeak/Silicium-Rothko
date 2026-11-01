#!/bin/bash
# 无 root 安装 mono：apt 下载 deb 后解包到 ~/mono
set -u
mkdir -p /home/ubuntu/mono-debs /home/ubuntu/mono
cd /home/ubuntu/mono-debs || exit 1

echo "=== 解析依赖 ==="
apt-cache depends --recurse --no-recommends --no-suggests --no-conflicts \
  --no-breaks --no-replaces --no-enhances mono-runtime 2>/dev/null \
  | grep -E '^[a-z0-9][a-z0-9.+-]*$' | sort -u > pkgs.txt
wc -l < pkgs.txt

echo "=== 下载 deb ==="
timeout 900 apt-get download $(tr '\n' ' ' < pkgs.txt) 2>&1 | tail -5
ls *.deb 2>/dev/null | wc -l

echo "=== 解包 ==="
for d in *.deb; do dpkg -x "$d" /home/ubuntu/mono 2>/dev/null; done
find /home/ubuntu/mono -maxdepth 4 -name "mono" -type f 2>/dev/null | head -3

echo "=== 版本检查 ==="
export PATH=/home/ubuntu/mono/usr/bin:$PATH
export LD_LIBRARY_PATH=/home/ubuntu/mono/usr/lib
/home/ubuntu/mono/usr/bin/mono --version 2>&1 | head -3 || echo "mono 启动失败"
