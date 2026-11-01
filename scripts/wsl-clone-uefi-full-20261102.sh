#!/bin/bash
# 完整检出 uefi/rothko（depth 1 全量，不用 partial/sparse），供 DeviceBuild.py 编译
set -u
BASE=/home/ubuntu/rothko-upstream-20261102
URL=git@github.com:ChallengeThePeak/Silicium-Rothko.git
export GIT_SSH_COMMAND='ssh -o StrictHostKeyChecking=no -o BatchMode=yes -o ServerAliveInterval=15 -o ServerAliveCountMax=8 -o TCPKeepAlive=yes'

cd "$BASE" || exit 1
echo "start $(date +%H:%M:%S)"

for i in 1 2 3; do
  echo "=== full clone attempt $i ==="
  timeout 5400 git clone --depth 1 --single-branch --branch uefi/rothko \
      --progress "$URL" uefi-full 2>&1 | tr '\r' '\n' | \
      grep -E "Receiving objects: *(100%|.*MiB)|Resolving|Updating files|fatal|error" | tail -4
  if [ -d uefi-full/.git ] && git -C uefi-full rev-parse --verify HEAD >/dev/null 2>&1; then
    echo "clone OK"
    break
  fi
  echo "attempt $i failed, keeping partial for inspection"
  [ -d uefi-full ] && mv uefi-full "uefi-full.fail-$(date +%H%M%S)"
  sleep 5
done

if [ -d uefi-full/.git ]; then
  echo "=== result ==="
  git -C uefi-full log --oneline -1
  du -sh uefi-full
  ls uefi-full | head -20
fi
echo "end $(date +%H:%M:%S)"
