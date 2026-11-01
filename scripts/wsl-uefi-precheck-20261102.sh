#!/bin/bash
# 检查子模块状态 + DeviceBuild.py 的依赖要求
set -u
U=/home/ubuntu/rothko-upstream-20261102/uefi-full
cd "$U" || exit 1

echo "=== 子模块目录内容 ==="
for d in Mu_Basecore Silicium-ACPI Silicon/Silicium/OpensslPkg/Library/OpensslLib/openssl; do
  printf "%-60s " "$d"
  if [ -d "$d" ] && [ -n "$(ls -A "$d" 2>/dev/null)" ]; then echo "有内容($(ls -A "$d" | wc -l) 项)"; else echo "空"; fi
done

echo
echo "=== DeviceBuild.py 中与 UniXNU / 子模块 / 工具链相关的行 ==="
grep -nE "UniXNU|submodule|setup|update|venv|pip|Basecore|insteadOf|PATH" Platforms/Xiaomi/rothkoPkg/DeviceBuild.py | head -40

echo
echo "=== pip-requirements.txt ==="
cat pip-requirements.txt 2>/dev/null | head -20
