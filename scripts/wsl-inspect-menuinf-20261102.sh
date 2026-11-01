#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
U=/home/ubuntu/rothko-upstream-20261102/uefi-full

echo "=== 上游 BootManagerMenuApp.inf ==="
cat "$U/Mu_Basecore/MdeModulePkg/Application/BootManagerMenuApp/BootManagerMenuApp.inf"

echo
echo "=== 别的平台怎么挂它 ==="
rg -rn "BootManagerMenuApp" "$U/Platforms" "$U/Silicon" 2>/dev/null | head -12

echo
echo "=== Boot-Manager.patch 是否已应用（看 BootManagerMenu.c 里有没有补丁的痕迹）==="
rg -n "Rothko|rothko|Silicium|k70u" "$U/Mu_Basecore/MdeModulePkg/Application/BootManagerMenuApp/BootManagerMenu.c" 2>/dev/null | head -8

echo
echo "=== 补丁内容（前 40 行）==="
head -40 "$U/Resources/MuPatches/Boot-Manager.patch"

echo
echo "=== DeviceBuild.py 是否自动应用 MuPatches ==="
rg -n "MuPatches|patch" "$U/Platforms/Xiaomi/rothkoPkg/DeviceBuild.py" 2>/dev/null | head -10
