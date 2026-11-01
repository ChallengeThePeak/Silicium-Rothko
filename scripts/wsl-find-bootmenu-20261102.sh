#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
U=/home/ubuntu/rothko-upstream-20261102/uefi-full
OLD=/home/ubuntu/rothko-evidence-20261101/Mu-Silicium-keepalive-clean

echo "=== 上游树里的 BootManagerMenu ==="
rg -rln "BootManagerMenu" "$U" 2>/dev/null | head -12

echo
echo "=== 上游树里的 BootManagerMenu 相关文件 ==="
rg --files "$U" 2>/dev/null | rg -i "bootmanagermenu|bootmanager" | head -12

echo
echo "=== 旧 Mu-Silicium 树里的 BootManagerMenu ==="
if [ -d "$OLD" ]; then
  rg --files "$OLD" 2>/dev/null | rg -i "bootmanagermenu" | head -12
  rg -rn "BootManagerMenu" "$OLD"/Platforms 2>/dev/null | head -10
fi

echo
echo "=== 上游 rothkoPkg 里现有的 .uni / HII 包 ==="
rg --files "$U/Platforms/Xiaomi/rothkoPkg" 2>/dev/null | rg -i "\.uni$|hii|form" | head -12
