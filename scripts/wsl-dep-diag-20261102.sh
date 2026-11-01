#!/bin/bash
set -u
echo "=== 代理端口 ==="
timeout 8 curl -sS -x http://172.30.32.1:15537 -o /dev/null -w "relay15537: %{http_code}\n" https://github.com 2>&1 | tail -1
echo
echo "=== 直连各站点 ==="
for u in https://github.com https://objects.githubusercontent.com https://github.com/microsoft/mu_basecore/releases/download/v2026080000.0.0-rc0/basetools-v2026080000.0.0-rc0.tar.gz; do
  code=$(timeout 25 curl -sSL -o /dev/null -w "%{http_code} %{size_download}B %{speed_download}B/s" --max-time 20 "$u" 2>/dev/null || echo fail)
  echo "$u"
  echo "   -> $code"
done
echo
echo "=== 树内 BaseTools ==="
ls -d /home/ubuntu/rothko-upstream-20261102/uefi-full/BaseTools 2>/dev/null
ls -d /home/ubuntu/rothko-upstream-20261102/uefi-full/Mu_Basecore/BaseTools 2>/dev/null
ls /home/ubuntu/rothko-upstream-20261102/uefi-full/Mu_Basecore 2>/dev/null | head -10
