#!/bin/bash
# 按需克隆 uefi/rothko 分支（partial + sparse），只取 rothkoPkg 平台包，便于与本地对比
set -u
BASE=/home/ubuntu/rothko-upstream-20261102
URL=git@github.com:ChallengeThePeak/Silicium-Rothko.git
export GIT_SSH_COMMAND='ssh -o StrictHostKeyChecking=no -o BatchMode=yes -o ServerAliveInterval=10 -o ServerAliveCountMax=6 -o TCPKeepAlive=yes -o ProxyCommand="/usr/bin/python3 /home/ubuntu/bin/proxyconnect.py %h %p"'

cd "$BASE" || exit 1

if [ ! -d uefi-src/.git ]; then
  for i in 1 2 3; do
    echo "=== clone uefi/rothko attempt $i $(date +%H:%M:%S) ==="
    rm -rf uefi-src.tmp 2>/dev/null || true
    if timeout 900 git clone --filter=blob:none --no-checkout --depth 1 \
        --branch uefi/rothko "$URL" uefi-src 2>&1 | tr '\r' '\n' | \
        grep -E "Cloning|remote:|fatal|error|done" | tail -5; then
      :
    fi
    if [ -d uefi-src/.git ]; then
      echo "clone dir ok"
      break
    fi
    sleep 3
  done
fi

cd "$BASE/uefi-src" 2>/dev/null || { echo "NO CLONE DIR"; exit 1; }

echo "=== sparse checkout rothkoPkg ==="
git sparse-checkout init --cone 2>&1 | tail -2
git sparse-checkout set Platforms/Xiaomi/rothkoPkg 2>&1 | tail -2
timeout 600 git checkout 2>&1 | tr '\r' '\n' | grep -E "Filtering|Updating|error|fatal" | tail -3

echo "=== result ==="
git log --oneline -3
du -sh .
echo "--- rothkoPkg 顶层 ---"
ls Platforms/Xiaomi/rothkoPkg 2>&1 | head -20
