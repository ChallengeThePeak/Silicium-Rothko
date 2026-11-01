#!/bin/bash
set -u
echo "=== 现有 Mu 树 ==="
for d in /home/ubuntu/rothko-evidence-20261101/Mu-Silicium-keepalive-clean \
         /home/ubuntu/rothko-evidence-20261101/Mu-Silicium-fv-membership-fixed \
         /home/ubuntu/rothko-evidence-20261101/Mu-Silicium-confirmed-20261101; do
  [ -d "$d" ] || continue
  printf "%-70s BaseTools:%s Build:%s\n" "$d" \
    "$([ -d "$d/BaseTools" ] && echo yes || echo no)" \
    "$([ -d "$d/Build" ] && echo yes || echo no)"
done

echo
echo "=== 依赖缓存目录（ext_dep / nasm / basetools / onecrypto）==="
find /home/ubuntu -maxdepth 5 \( -type d -name "*ext_dep*" -o -type d -name "mu_nasm*" \
  -o -type d -iname "*basetools*" -o -type d -iname "*onecrypto*" \) 2>/dev/null | head -25

echo
echo "=== Mu_Basecore 内容 ==="
ls /home/ubuntu/rothko-upstream-20261102/uefi-full/Mu_Basecore 2>/dev/null | head -15
