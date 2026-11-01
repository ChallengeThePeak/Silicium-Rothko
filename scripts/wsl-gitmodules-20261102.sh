#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
R=/home/ubuntu/rothko-upstream-20261102/uefi-full
echo "=== .gitmodules ==="
cat "$R/.gitmodules" 2>/dev/null | head -20
echo
echo "=== Mu_Basecore remote ==="
cd "$R/Mu_Basecore" || exit 1
git remote -v | head -4
echo
echo "=== uefi-full 里记录的 submodule url ==="
git config -f "$R/.gitmodules" --list 2>/dev/null | head -10
echo
echo "=== Mu_Basecore 能否直连推送（SSH URL 探测）==="
timeout 60 git ls-remote --heads git@github.com:ChallengeThePeak/Silicium-Rothko.git 2>&1 | head -5
