#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
U=/home/ubuntu/rothko-upstream-20261102/uefi-full

echo "=== ArmGetPhysicalAddressBits 定义（全树）==="
rg -n --no-heading "ArmGetPhysicalAddressBits" "$U/Mu_Basecore" -g "*.S" -g "*.c" -g "*.h" | head -12

echo
echo "=== 汇编实现（若有）==="
F=$(rg -l "ArmGetPhysicalAddressBits:" "$U/Mu_Basecore" -g "*.S" | head -1)
echo "ASM=$F"
[ -n "$F" ] && rg -n -A20 "ArmGetPhysicalAddressBits:" "$F" | head -30

echo
echo "=== FillTranslationTable 对高位区域的处理 ==="
rg -n -A30 "^FillTranslationTable" "$U/Mu_Basecore/UefiCpuPkg/Library/ArmMmuLib/AArch64/ArmMmuLibCore.c" | head -45
