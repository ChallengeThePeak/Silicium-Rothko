#!/bin/bash
# 判定血统：上游 uefi/rothko 是否含 pstore 日志与 RothkoStage，和本地树是否同源
set -u
cd /home/ubuntu/rothko-upstream-20261102/uefi-src || exit 1

echo "=== 上游 HEAD 中 pstore / RothkoStage 相关文件 ==="
git ls-tree -r HEAD --name-only | grep -iE "pstore|rothkostage|framebuffer.*serial|serialport.*fb" | head -15
echo
echo "=== 上游 rothkoPkg 完整文件表 ==="
git ls-tree -r HEAD --name-only | grep "Platforms/Xiaomi/rothkoPkg" | head -20
echo
echo "=== 上游 rothko.dsc 中是否引用 Rothko 驱动 ==="
git show HEAD:Platforms/Xiaomi/rothkoPkg/rothko.dsc 2>/dev/null | grep -nE "Rothko|UniXNU" | head -10
echo
echo "=== 上游 APRIORI.inc ==="
git show HEAD:Platforms/Xiaomi/rothkoPkg/Include/APRIORI.inc 2>/dev/null | head -25
echo
echo "=== 本地树是否有 RothkoStage / Pstore ==="
for LOC in /home/ubuntu/rothko-evidence-20261101/Mu-Silicium-keepalive-clean /home/ubuntu/rothko-evidence-20261101/Mu-Silicium-fv-membership-fixed; do
  echo "--- $LOC"
  ls "$LOC/Platforms/Xiaomi/rothkoPkg" 2>/dev/null
  grep -rl "RothkoStage" "$LOC/Platforms/Xiaomi" 2>/dev/null | head -3
done
