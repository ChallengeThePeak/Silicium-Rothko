#!/bin/bash
# 经代理完整克隆 uefi/rothko；先看子模块需求
set -u
BASE=/home/ubuntu/rothko-upstream-20261102
URL=git@github.com:ChallengeThePeak/Silicium-Rothko.git
export GIT_SSH_COMMAND='ssh -o StrictHostKeyChecking=no -o BatchMode=yes -o ServerAliveInterval=15 -o ServerAliveCountMax=8 -o ProxyCommand="/usr/bin/python3 /home/ubuntu/bin/proxyconnect.py %h %p"'

cd "$BASE" || exit 1

echo "=== 通道检查 ==="
timeout 10 curl -sS -x http://172.30.32.1:15537 -o /dev/null -w "proxy_github=%{http_code}\n" https://github.com 2>&1 | tail -1

echo "=== uefi/rothko 的 .gitmodules ==="
cd uefi-src && git show HEAD:.gitmodules 2>&1 | head -20; cd ..

if [ -d uefi-full ]; then
  mv uefi-full "uefi-full.partial-$(date +%H%M%S)"
  echo "旧的不完整目录已改名保留"
fi

echo "=== 完整克隆 ==="
timeout 1500 git clone --depth 1 --single-branch --branch uefi/rothko \
  --progress "$URL" uefi-full 2>&1 | tr '\r' '\n' | \
  grep -E "Receiving objects: *(100%,|.*done)|Resolving deltas: *100%|Updating files: *100%|fatal|error" | tail -5

echo "=== 结果 ==="
git -C uefi-full log --oneline -1 2>&1
du -sh uefi-full 2>/dev/null
ls uefi-full 2>/dev/null | head -15
