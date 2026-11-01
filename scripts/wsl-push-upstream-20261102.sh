#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
R=/home/ubuntu/rothko-upstream-20261102/uefi-full

echo "=========== Mu_Basecore 推送 ==========="
cd "$R/Mu_Basecore" || exit 1
git remote -v | head -2
echo "--- 推分支 k70u-port-20261102 ---"
timeout 180 git push -u origin k70u-port-20261102 2>&1 | tail -4
echo "--- 试推 main（非快进会被拒绝，不会破坏上游）---"
timeout 120 git push origin HEAD:main 2>&1 | tail -4

echo
echo "=========== uefi-full 推送 ==========="
cd "$R" || exit 1
echo "--- 推 uefi/rothko（快进）---"
timeout 300 git push origin uefi/rothko 2>&1 | tail -4
echo "--- 试推 main ---"
timeout 180 git push origin HEAD:main 2>&1 | tail -4
