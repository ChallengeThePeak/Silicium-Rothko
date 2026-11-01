#!/bin/bash
set -u
F=/home/ubuntu/rothko-upstream-20261102/uefi-full/Mu_Basecore/MdeModulePkg/Core/Dxe/Gcd/Gcd.c
echo "=== 2270-2400（Found 的判定条件）==="
sed -n '2270,2400p' "$F"
