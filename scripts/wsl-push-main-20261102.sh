#!/bin/bash
# 备份旧 main 后，把 uefi/rothko 推到 main（带 lease 保护）
set -u
export PATH="$HOME/bin:$PATH"
R=/home/ubuntu/rothko-upstream-20261102/uefi-full
cd "$R" || exit 1

echo "=== 1) 显式抓取远端 main ==="
git fetch origin main:refs/remotes/origin/main 2>&1 | tail -3
OLD_MAIN=$(git rev-parse refs/remotes/origin/main)
echo "远端 main = $OLD_MAIN"

echo
echo "=== 2) 备份旧 main → archive/main-before-k70u ==="
git branch -f archive/main-before-k70u "$OLD_MAIN"
git push origin refs/heads/archive/main-before-k70u:refs/heads/archive/main-before-k70u 2>&1 | tail -3

echo
echo "=== 3) 带 lease 的强推到 main ==="
git push origin +uefi/rothko:main --force-with-lease=main:"$OLD_MAIN" 2>&1 | tail -5

echo
echo "=== 4) 远端分支确认 ==="
git ls-remote --heads origin 2>&1 | head -10
