#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
R=/home/ubuntu/rothko-upstream-20261102/uefi-full
cd "$R" || exit 1

git fetch origin main:refs/remotes/origin/main 2>&1 | tail -2
OLD=$(git rev-parse refs/remotes/origin/main)
echo "远端 main 当前 = $OLD"
timeout 300 git push origin uefi/rothko:main --force-with-lease=main:"$OLD" 2>&1 | tail -4
echo
timeout 120 git ls-remote --heads origin 2>&1 | grep -E "main|rothko" | head -6
