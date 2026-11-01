#!/bin/bash
# 检查上游历史标签里是否包含 RothkoDisplayDxe/RothkoWatchdogDxe（判断本地树血统）
set -u
cd /home/ubuntu/rothko-upstream-20261102/uefi-src || exit 1
export GIT_SSH_COMMAND='ssh -o StrictHostKeyChecking=no -o BatchMode=yes -o ServerAliveInterval=10 -o ProxyCommand="/usr/bin/python3 /home/ubuntu/bin/proxyconnect.py %h %p"'

for T in rothko-trace-v2 rothko-avb-v1; do
  echo "=== fetch tag $T ==="
  timeout 300 git fetch --depth 1 origin "refs/tags/$T:refs/tags/$T" 2>&1 | tail -3
  echo "--- $T 中 rothkoPkg 下的 Drivers ---"
  git ls-tree -r --name-only "$T" -- Platforms/Xiaomi/rothkoPkg 2>/dev/null | grep -i "drivers\|DXE.inc\|APRIORI" | head -15
  echo "--- $T 的 DXE.inc 是否含 Rothko 驱动 ---"
  git show "$T:Platforms/Xiaomi/rothkoPkg/Include/DXE.inc" 2>/dev/null | grep -nE "Rothko|UniXNU|APRIORI" | head -10
  echo
done

echo "=== main 分支 tags 与提交时间 ==="
git log -1 --format="%H %ad %s" --date=iso rothko-trace-v2 2>/dev/null
git log -1 --format="%H %ad %s" --date=iso rothko-avb-v1 2>/dev/null
git log -1 --format="%H %ad %s" --date=iso HEAD 2>/dev/null
