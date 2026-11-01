#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
R=/home/ubuntu/rothko-upstream-20261102/uefi-full
SSHURL="git@github.com:ChallengeThePeak/Silicium-Rothko.git"

echo "=== 祖先关系检查 ==="
cd "$R" || exit 1
if git merge-base --is-ancestor 6b1f2dd 3b33638 2>/dev/null; then
  echo "父仓: main(6b1f2dd) 是 uefi/rothko 的祖先 → main 可快进"
else
  echo "父仓: main 与 uefi/rothko 无祖先关系 → 推 main 会被拒（非快进）"
fi
cd "$R/Mu_Basecore" || exit 1
if git merge-base --is-ancestor 6b1f2dd cd48f4d 2>/dev/null; then
  echo "子模块: main(6b1f2dd) 是 basecore/rothko 的祖先 → 可快进"
else
  echo "子模块: 无祖先关系"
fi

echo
echo "=== 改用 SSH remote（避开 HTTPS 密码提示）==="
cd "$R/Mu_Basecore" && git remote set-url origin "$SSHURL" && git remote -v | head -2
cd "$R" && git remote set-url origin "$SSHURL" && git remote -v | head -2

echo
echo "=== 推 Mu_Basecore → basecore/rothko ==="
cd "$R/Mu_Basecore" || exit 1
timeout 300 git push origin k70u-port-20261102:basecore/rothko 2>&1 | tail -6

echo
echo "=== 推父仓 uefi/rothko ==="
cd "$R" || exit 1
timeout 600 git push origin uefi/rothko 2>&1 | tail -6

echo
echo "=== 试推 main（能快进就推）==="
timeout 300 git push origin HEAD:main 2>&1 | tail -6

echo
echo "=== 远端确认 ==="
timeout 120 git ls-remote --heads origin 2>&1 | grep -E "main|rothko" | head -6
echo DONE
