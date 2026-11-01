#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
U=/home/ubuntu/rothko-upstream-20261102/uefi-full

echo "=== Silicium SEC 里的 EL 处理 ==="
rg -n "CurrentEl|CurrentEL|SPSR|spsr|EL1|EL2|DropTo|SwitchEl" "$U/Silicon/Silicium/SiliciumPkg/Sec" -g "*.c" -g "*.h" | head -20

echo
echo "=== PeilessSec 的 EL 处理 ==="
rg -n "CurrentEl|SPSR|ArmCall|EL1|EL2" "$U/Mu_Basecore/ArmPlatformPkg/PeilessSec/PeilessSec.c" | head -20

echo
echo "=== TranslationRegimeIsDual 实现 ==="
rg -n -A12 "TranslationRegimeIsDual \(" "$U/Mu_Basecore/UefiCpuPkg/Library/ArmMmuLib/AArch64/ArmMmuLibCore.c" | head -25

echo
echo "=== 谁在 C 里切 EL（msr spsr / eret）==="
rg -n "ArmCallEl1|ArmCallEl2|SwitchToEl1|spsr_el2|elr_el2" "$U/Silicon/Silicium" -g "*.c" -g "*.S" | head -15
