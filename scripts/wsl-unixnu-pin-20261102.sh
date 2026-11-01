#!/bin/bash
# 取 UniXNU 固定提交（67df14de），用 worktree 独立目录，不改动用户现有检出
set -u
cd /home/ubuntu/UniXNU || exit 1
SHA=67df14de69ae6f6ffc3480b30b70ce7667a3bd32
WT=/home/ubuntu/UniXNU-pin-67df14de

echo "=== github 连通性 ==="
timeout 20 curl -sS -o /dev/null -w "github=%{http_code}\n" https://github.com 2>&1 | tail -1

echo "=== 取固定提交 ==="
for i in 1 2 3; do
  echo "--- 第 $i 次 ---"
  if timeout 300 git fetch --depth 1 origin "$SHA" 2>&1 | tail -3; then :; fi
  if git cat-file -e "$SHA^{commit}" 2>/dev/null; then echo "提交已就位"; break; fi
  sleep 3
done

echo "=== 建独立 worktree ==="
if [ ! -d "$WT" ]; then
  git worktree add --detach "$WT" "$SHA" 2>&1 | tail -3
fi
git -C "$WT" log --oneline -1 2>&1
ls "$WT/package/UniXNUPkg/Driver" 2>&1 | head -5

echo "=== 切换软链指向固定提交 ==="
L=/home/ubuntu/rothko-upstream-20261102/uefi-full/UniXNU
if [ -L "$L" ]; then
  ln -sfn "$WT" "$L"
  echo "软链 -> $(readlink "$L")"
else
  echo "警告：$L 不是软链，保持原样"
fi
ls -d "$L/package/UniXNUPkg/Driver/UniXNURamDiskDxe" 2>&1 | tail -1
