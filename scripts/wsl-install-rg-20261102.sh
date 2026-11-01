#!/bin/bash
# 无 root 安装 ripgrep，并用它继续定位
set -u
mkdir -p /home/ubuntu/rg-debs /home/ubuntu/rg
cd /home/ubuntu/rg-debs || exit 1
if [ ! -x /home/ubuntu/rg/usr/bin/rg ]; then
  timeout 180 apt-get download ripgrep 2>&1 | tail -2
  for d in ripgrep*.deb; do dpkg -x "$d" /home/ubuntu/rg 2>/dev/null; done
fi
ln -sfn /home/ubuntu/rg/usr/bin/rg /home/ubuntu/bin/rg 2>/dev/null || true
/home/ubuntu/rg/usr/bin/rg --version | head -2

export PATH=/home/ubuntu/bin:$PATH
U=/home/ubuntu/rothko-upstream-20261102/uefi-full

echo
echo "=== ArmGetPhysicalAddressBits 实现 ==="
rg -n --no-heading -A18 "ArmGetPhysicalAddressBits \(" "$U/Mu_Basecore/ArmPkg" -g "*.c" | head -40

echo
echo "=== MAX_VA_BITS 定义 ==="
rg -n "define MAX_VA_BITS" "$U/Mu_Basecore" -g "*.h" | head -5
