#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
R=/home/ubuntu/rothko-upstream-20261102/uefi-full
for sm in Mu_Basecore Silicon/Silicium/OpensslPkg/Library/OpensslLib/openssl; do
  echo "=== $sm ==="
  cd "$R/$sm" 2>/dev/null || { echo "  (不存在)"; continue; }
  git branch -v 2>/dev/null | head -3
  git log --oneline -2 2>/dev/null | head -2
  echo "--- 改动 ---"
  git status --short 2>/dev/null | head -8
  echo
done
