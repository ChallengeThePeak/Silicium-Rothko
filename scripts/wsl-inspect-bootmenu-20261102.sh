#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
U=/home/ubuntu/rothko-upstream-20261102/uefi-full
OLD=/home/ubuntu/rothko-evidence-20261101/Mu-Silicium-keepalive-clean

echo "=== Resources/MuPatches 目录 ==="
ls -l "$U/Resources/MuPatches" 2>/dev/null | head -12

echo
echo "=== Boot-Manager.patch 涉及的文件与规模 ==="
rg -n "^diff --git|^\+\+\+|^---" "$U/Resources/MuPatches/Boot-Manager.patch" 2>/dev/null | head -20
wc -l "$U/Resources/MuPatches/Boot-Manager.patch" 2>/dev/null

echo
echo "=== 上游 Mu_Basecore 有没有 BootManagerMenuApp ==="
rg --files "$U/Mu_Basecore/MdeModulePkg/Application" 2>/dev/null | rg -i "bootmanager" | head -8 || echo "（上游 Mu_Basecore 没有 BootManagerMenuApp）"

echo
echo "=== 旧树 BootManagerMenuApp 的文件与大小 ==="
ls -l "$OLD/Mu_Basecore/MdeModulePkg/Application/BootManagerMenuApp" 2>/dev/null | head -12

echo
echo "=== 旧树 rothkoPkg 是怎么挂它的（DXE.inc / FDF）==="
rg -rn "BootManagerMenuApp" "$OLD/Platforms/Xiaomi/rothkoPkg" 2>/dev/null | head -6
