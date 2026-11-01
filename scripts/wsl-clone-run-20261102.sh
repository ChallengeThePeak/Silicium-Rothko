#!/bin/bash
# 经 Windows 代理（Clash 7897 中继）完整克隆上游仓库
set -u
BASE=/home/ubuntu/rothko-upstream-20261102
export GIT_SSH_COMMAND='ssh -o StrictHostKeyChecking=no -o BatchMode=yes -o ServerAliveInterval=15 -o ProxyCommand="/usr/bin/python3 /home/ubuntu/bin/proxyconnect.py %h %p"'

cd "$BASE"
echo "start $(date +%H:%M:%S)"
timeout 1800 git clone --progress git@github.com:ChallengeThePeak/Silicium-Rothko.git 2>&1 | \
  grep -E "Receiving|Resolving|Checking|Cloning|remote:|fatal|error" | tail -20
echo "exit=$? $(date +%H:%M:%S)"
du -sh "$BASE/Silicium-Rothko" 2>/dev/null
