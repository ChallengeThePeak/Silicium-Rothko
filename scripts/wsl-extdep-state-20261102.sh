#!/bin/bash
set -u
U=/home/ubuntu/rothko-upstream-20261102/uefi-full
echo "=== 已就绪的 ext_dep ==="
for d in "$U"/Mu_Basecore/BaseTools/Bin/Mu-Basetools_extdep "$U"/**/onecrypto* ; do :; done
ls -d "$U/Mu_Basecore/BaseTools/Bin/Mu-Basetools_extdep/Linux-x86" 2>/dev/null && echo "  Mu-Basetools: 已就绪"
find "$U" -maxdepth 4 -iname "*onecrypto*" 2>/dev/null | head -5
echo
echo "=== 各 ext_dep 状态文件 ==="
find "$U" -maxdepth 5 -name "extdep_state.yaml" 2>/dev/null | head -10 | while read -r f; do
  echo "--- $f"; cat "$f" 2>/dev/null | head -6
done
echo
echo "=== nasm 相关目录 ==="
find "$U" -maxdepth 5 -iname "*nasm*" 2>/dev/null | head -10
