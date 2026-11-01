#!/bin/bash
# 停止走直连的慢速克隆，改用经 Windows 代理的 SSH 通道
set -u

echo "=== kill slow clone ==="
pkill -f "git-remote-ssh" 2>/dev/null
pkill -f "git clone git@github.com" 2>/dev/null
sleep 2
ps -eo pid,args | grep "[g]it-remote-ssh" | head -3

echo "=== stop task wrapper ==="
pkill -f "git clone git@github.com:ChallengeThePeak" 2>/dev/null

BASE=/home/ubuntu/rothko-upstream-20261102
if [ -d "$BASE/Silicium-Rothko" ]; then
  TS=$(date +%H%M%S)
  mv "$BASE/Silicium-Rothko" "$BASE/Silicium-Rothko.direct-slow-$TS"
  echo "partial kept as $BASE/Silicium-Rothko.direct-slow-$TS"
fi

echo "=== install proxyconnect ==="
mkdir -p /home/ubuntu/bin
cp -f "/mnt/d/漏洞/UNIXNU/适配K70U/scripts/proxyconnect.py" /home/ubuntu/bin/proxyconnect.py
chmod +x /home/ubuntu/bin/proxyconnect.py
ls -l /home/ubuntu/bin/proxyconnect.py

echo "=== test ls-remote through proxy ==="
export GIT_SSH_COMMAND='ssh -o StrictHostKeyChecking=no -o BatchMode=yes -o ProxyCommand="/usr/bin/python3 /home/ubuntu/bin/proxyconnect.py %h %p"'
cd "$BASE"
time timeout 90 git ls-remote git@github.com:ChallengeThePeak/Silicium-Rothko.git 2>&1 | head -15
