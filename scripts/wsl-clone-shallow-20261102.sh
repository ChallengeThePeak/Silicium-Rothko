#!/bin/bash
# 经代理浅克隆（depth=1），失败自动重试；每次用新目录，不覆盖既有目录
set -u
BASE=/home/ubuntu/rothko-upstream-20261102
URL=git@github.com:ChallengeThePeak/Silicium-Rothko.git
export GIT_SSH_COMMAND='ssh -o StrictHostKeyChecking=no -o BatchMode=yes -o ServerAliveInterval=10 -o ServerAliveCountMax=6 -o TCPKeepAlive=yes -o ProxyCommand="/usr/bin/python3 /home/ubuntu/bin/proxyconnect.py %h %p"'

cd "$BASE" || exit 1

# 清走上次中断留下的半成品目录（改名为 .fail-N，不删除）
for d in Silicium-Rothko; do
  if [ -d "$d" ]; then
    mv "$d" "$d.fail-$(date +%H%M%S)"
    echo "moved incomplete $d aside"
  fi
done

OK=0
for i in 1 2 3 4; do
  echo "=== attempt $i $(date +%H:%M:%S) ==="
  if timeout 900 git clone --depth 1 --single-branch --branch main --progress "$URL" "Silicium-Rothko" 2>&1 \
      | tr '\r' '\n' | grep -E "Receiving objects:.*(100%|MiB)|Cloning|fatal|error|Resolving|Updating files:.*100%" | tail -6; then
    if [ -d "$BASE/Silicium-Rothko/.git" ] && git -C "$BASE/Silicium-Rothko" rev-parse --verify HEAD >/dev/null 2>&1; then
      OK=1
      echo "clone OK on attempt $i"
      break
    fi
  fi
  echo "attempt $i failed"
  [ -d "$BASE/Silicium-Rothko" ] && mv "$BASE/Silicium-Rothko" "$BASE/Silicium-Rothko.fail-$(date +%H%M%S)"
  sleep 3
done

if [ "$OK" = 1 ]; then
  echo "=== result ==="
  git -C "$BASE/Silicium-Rothko" log --oneline -3
  du -sh "$BASE/Silicium-Rothko"
else
  echo "ALL ATTEMPTS FAILED"
fi
