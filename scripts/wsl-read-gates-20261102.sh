#!/bin/bash
# 读取上游计划的"未解决关卡"并补齐 main 提交历史时间线
set -u
cd /home/ubuntu/rothko-upstream-20261102/Silicium-Rothko || exit 1
export GIT_SSH_COMMAND='ssh -o StrictHostKeyChecking=no -o BatchMode=yes -o ServerAliveInterval=10 -o ProxyCommand="/usr/bin/python3 /home/ubuntu/bin/proxyconnect.py %h %p"'

echo "=== 未解决关卡（Unresolved Gates）==="
sed -n '538,640p' ADAPTATION_PLAN.md

echo
echo "=== 决定（Decision）==="
sed -n '49,95p' ADAPTATION_PLAN.md

echo
echo "=== 补齐 main 历史 ==="
timeout 300 git fetch --deepen 80 origin main 2>&1 | tail -3
echo "--- 提交时间线 ---"
git log --format="%ad %h %s" --date=format:"%m-%d %H:%M" | head -30
