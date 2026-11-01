#!/bin/bash
set -u
echo "=== 探测 mono 官方 tarball ==="
for u in \
 "https://download.mono-project.com/archive/6.12.0/mono-6.12.0.199-x64-0.tar.xz" \
 "https://download.mono-project.com/archive/6.12.0.199/mono-6.12.0.199-x64-0.tar.xz" \
 "https://download.mono-project.com/archive/6.8.0/mono-6.8.0.123-x64-0.tar.xz" ; do
  r=$(timeout 25 curl -sSI -o /dev/null -w "%{http_code} %{size_download}" --max-time 20 "$u" 2>/dev/null || echo fail)
  echo "$u -> $r"
done

echo
echo "=== apt 能否以普通用户下载 deb ==="
cd /home/ubuntu || exit 1
mkdir -p mono-debs
cd mono-debs || exit 1
timeout 120 apt-get download --print-uris mono-runtime 2>&1 | tail -3

echo
echo "=== ext_dep 定义位置 ==="
grep -rn "mu_nasm\|Mu-Basetools\|onecrypto" /home/ubuntu/rothko-upstream-20261102/uefi-full/Platforms/Xiaomi/rothkoPkg/DeviceBuild.py \
  /home/ubuntu/rothko-upstream-20261102/uefi-full/*.json 2>/dev/null | head -10
ls /home/ubuntu/rothko-upstream-20261102/uefi-full/uefi-ext-dep* 2>/dev/null | head -5
