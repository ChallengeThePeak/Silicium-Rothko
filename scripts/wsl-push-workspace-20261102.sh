#!/bin/bash
set -u
export PATH="$HOME/bin:$PATH"
WS="/mnt/d/漏洞/UNIXNU/适配K70U"
git config --global --add safe.directory "$WS" 2>/dev/null
cd "$WS" || exit 1

echo "=== 状态 ==="
git log --oneline -1
git status --porcelain | head -3

echo
echo "=== 推工作区文档到 notes 分支 ==="
git push git@github.com:ChallengeThePeak/Silicium-Rothko.git \
      main:refs/heads/notes/k70u-workspace-20261102 2>&1 | tail -5

echo
echo "=== 远端分支确认 ==="
git ls-remote --heads git@github.com:ChallengeThePeak/Silicium-Rothko.git 2>&1 | head -8
