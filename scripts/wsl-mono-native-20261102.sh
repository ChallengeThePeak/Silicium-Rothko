#!/bin/bash
set -u
echo "=== pytool 固定的 NuGet 版本 ==="
sed -n '10,25p' /home/ubuntu/.local/lib/python3.12/site-packages/edk2toolext/bin/nuget.py

echo
echo "=== 缺哪个 mono 原生库 ==="
find /home/ubuntu/mono -name "System.Native*" 2>/dev/null | head -5
echo "apt 里可能的提供者:"
apt-cache search "mono" 2>/dev/null | grep -iE "native|devel" | head -10
