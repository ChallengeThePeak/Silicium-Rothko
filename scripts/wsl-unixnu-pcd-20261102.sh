#!/bin/bash
# 查 UniXNU 最新提交是否声明 RamDisk PCD，以及驱动是否真的用到它
set -u
R=/home/ubuntu/UniXNU
cd "$R" || exit 1

echo "=== 驱动里是否引用该 PCD ==="
grep -rn "PcdUniXNURamDisk" package/UniXNUPkg/Driver/UniXNURamDiskDxe/ 2>/dev/null | head -10
echo "--- INF 内容关键行 ---"
grep -nE "Pcd|DEC|\[Packages\]" package/UniXNUPkg/Driver/UniXNURamDiskDxe/UniXNURamDiskDxe.inf 2>/dev/null | head -10

echo
echo "=== 拉最新分支并检查 DEC ==="
timeout 300 git fetch --depth 1 origin HEAD 2>&1 | tail -3
LATEST=$(git rev-parse FETCH_HEAD 2>/dev/null)
echo "latest=$LATEST"
if [ -n "${LATEST:-}" ]; then
  git log --oneline -1 "$LATEST" 2>/dev/null
  echo "--- 最新提交的 DEC 是否声明 RamDisk PCD ---"
  git show "$LATEST:package/UniXNUPkg/UniXNUPkg.dec" 2>/dev/null | grep -n "PcdUniXNURamDisk" | head -5
  echo "--- 最新提交是否有 RamDiskDxe ---"
  git ls-tree -r --name-only "$LATEST" -- package/UniXNUPkg/Driver/UniXNURamDiskDxe 2>/dev/null | head -5
fi

echo
echo "=== 67df14de 提交时间与 fb2bb31 对比 ==="
git log -1 --format="%H %ad %s" --date=iso "$LATEST" 2>/dev/null
