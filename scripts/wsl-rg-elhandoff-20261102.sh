#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
U=/home/ubuntu/rothko-upstream-20261102/uefi-full

echo "=== SEC / PeilessSec 中的 eret / spsr 写操作 ==="
rg -n "eret|spsr_el2|spsr_el1|SPSR_EL2|SPSR_EL1|msr.*spsr" "$U/Silicon/Silicium/SiliciumPkg/Sec" "$U/Mu_Basecore/ArmPlatformPkg/PeilessSec" -g "*.S" -g "*.c" | head -20

echo
echo "=== ArmCallEl1 / ArmCallEl2 定义 ==="
rg -n "ArmCallEl1|ArmCallEl2" "$U/Mu_Basecore/ArmPkg" "$U/Mu_Basecore/MdePkg" -g "*.h" -g "*.S" -g "*.c" | head -12

echo
echo "=== Sec.c 主流程里的 EL 相关调用 ==="
rg -n "CurrentEl|CurrentEL|ArmReadCurrentEL|EL2|EL1" "$U/Silicon/Silicium/SiliciumPkg/Sec/Sec.c" | head -20
