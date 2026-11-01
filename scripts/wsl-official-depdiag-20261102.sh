#!/bin/bash
set -u
echo "=== 1) GitHub releases 可达性（stuart 需要的三个外部依赖）==="
for u in "https://github.com/microsoft/mu_basecore/releases/download/v2026080000.0.0-rc0/basetools-v2026080000.0.0-rc0.tar.gz" \
         "https://github.com/microsoft/mu_crypto_release/releases/download/v1.1.2-OneCrypto/OneCrypto-Accelerated.zip"; do
  echo "$u"
  timeout 30 curl -sSL -o /dev/null -w "   http=%{http_code} size=%{size_download} speed=%{speed_download}B/s\n" --max-time 25 "$u" 2>&1 | tail -2
done

echo
echo "=== 2) mono / nuget ==="
command -v mono || echo "mono: missing"
command -v nuget || echo "nuget: missing"

echo
echo "=== 3) sudo 与 apt 源 ==="
sudo -n true 2>&1 && echo "sudo: 免密可用" || echo "sudo: 需要密码或不可用"
grep -rhE "^deb |^URIs:" /etc/apt/sources.list /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources 2>/dev/null | head -5
echo "--- apt 源连通 ---"
timeout 20 curl -sS -o /dev/null -w "archive.ubuntu.com=%{http_code}\n" http://archive.ubuntu.com/ubuntu/ 2>&1 | tail -1
timeout 20 curl -sS -o /dev/null -w "mirrors.tuna=%{http_code}\n" https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ 2>&1 | tail -1
