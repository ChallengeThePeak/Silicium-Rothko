#!/bin/bash
set -u
F=/home/ubuntu/rothko-upstream-20261102/uefi-full/Mu_Basecore/MdeModulePkg/Core/Dxe/Gcd/Gcd.c
echo "=== 锚点定位 ==="
grep -n 'ASSERT (Found)\|"Found"' "$F" | head -10
echo
echo "=== 2400-2440 ==="
sed -n '2395,2445p' "$F"
