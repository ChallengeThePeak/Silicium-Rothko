#!/bin/bash
# 换网后：检查子模块状态 + 测当前网络速度
set -u
U=/home/ubuntu/rothko-upstream-20261102/uefi-full
cd "$U" || { echo "NO UEFI DIR"; exit 1; }

echo "=== 子模块状态 ==="
for d in Mu_Basecore Silicium-ACPI Silicon/Silicium/OpensslPkg/Library/OpensslLib/openssl; do
  n=$(ls -A "$d" 2>/dev/null | wc -l)
  printf "%-58s %s 项\n" "$d" "$n"
done

echo
echo "=== 网络测速（取 3MB 随机块）==="
timeout 40 curl -sS -o /dev/null -w "direct codeload: %{http_code} %{speed_download} B/s\n" \
  --max-time 30 "https://codeload.github.com/Project-Silicium/Silicium-ACPI/tar.gz/refs/heads/main" 2>&1 | tail -2
echo "--- 代理是否还在 ---"
timeout 8 curl -sS -x http://172.30.32.1:15537 -o /dev/null -w "relay: %{http_code}\n" https://github.com 2>&1 | tail -1
