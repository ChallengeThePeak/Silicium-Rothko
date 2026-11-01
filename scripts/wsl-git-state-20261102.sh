#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
R=/home/ubuntu/rothko-upstream-20261102/uefi-full
cd "$R" || exit 1
echo "=== 分支 ==="
git branch -v | head -5
echo "=== 最近提交 ==="
git log --oneline -3
echo "=== 改动文件 ==="
git status --short | head -30
echo "=== remote ==="
git remote -v | head -4
