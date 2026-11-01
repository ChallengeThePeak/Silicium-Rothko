#!/bin/bash
set -u
U=/home/ubuntu/rothko-upstream-20261102/uefi-full
echo "=== mu_nasm / onecrypto / basetools 的 ext_dep 定义 ==="
grep -rn "mu_nasm" "$U" --include="*.yaml" --include="*.yml" --include="*.json" --include="*.py" 2>/dev/null | grep -v "\.git/" | head -10
echo "--- 找到的 yaml 内容 ---"
for f in $(grep -rl "mu_nasm" "$U" --include="*.yaml" --include="*.yml" 2>/dev/null | grep -v "\.git/" | head -3); do
  echo "### $f"
  cat "$f"
done

echo
echo "=== 已落地的 ext_dep 目录 ==="
ls -d "$U"/Mu_Basecore/BaseTools/Bin/*_extdep 2>/dev/null | head -5
ls "$U"/Mu_Basecore/BaseTools/Bin/ 2>/dev/null | head -10
