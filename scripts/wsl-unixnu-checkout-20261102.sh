#!/bin/bash
# 把 /home/ubuntu/UniXNU 切到上游固定提交（可从 reflog 回到原 HEAD）
set -u
REPO=/home/ubuntu/UniXNU
SHA=67df14de69ae6f6ffc3480b30b70ce7667a3bd32
cd "$REPO" || exit 1

echo "=== 切换前 HEAD ==="
git log --oneline -1
git rev-parse HEAD > /home/ubuntu/unixnu-head-before.txt
cat /home/ubuntu/unixnu-head-before.txt

echo "=== 工作区是否干净 ==="
git status --porcelain | head -5
DIRTY=$(git status --porcelain | wc -l)
echo "改动文件数: $DIRTY"

echo "=== checkout 固定提交 ==="
git checkout -q "$SHA" 2>&1 | tail -3
git log --oneline -1

echo "=== 关键 INF ==="
for f in UniXNUPkg/Application/UniXNU/UniXNU.inf \
         UniXNUPkg/Driver/UniXNUDxe/UniXNUDxe.inf \
         UniXNUPkg/Driver/UniXNURamDiskDxe/UniXNURamDiskDxe.inf \
         UniXNUPkg/Library/UniXNULib/UniXNULib.inf; do
  if [ -f "$f" ]; then echo "OK   $f"; else echo "MISS $f"; fi
done
