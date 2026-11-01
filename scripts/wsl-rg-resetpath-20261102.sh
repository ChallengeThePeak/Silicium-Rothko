#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
U=/home/ubuntu/rothko-upstream-20261102/uefi-full

echo "=== Synchronous Exception 打印点 ==="
rg -n "Synchronous Exception at" "$U/Mu_Basecore" -g "*.c" | head -5

echo
echo "=== DefaultExceptionHandler 的收尾（CpuDeadLoop）==="
F=$(rg -l "Synchronous Exception at" "$U/Mu_Basecore" -g "*.c" | head -1)
echo "F=$F"
rg -n "CpuDeadLoop|while \(1\)|for \(;;\)" "$F" | head -5

echo
echo "=== Mu DebugLib 的 DebugAssert 收尾 ==="
D=$(rg -l "DebugAssert \(" "$U/Mu_Basecore/MdePkg/Library/BaseDebugLibSerialPort" -g "*.c" | head -1)
echo "D=$D"
rg -n -A12 "DebugAssert \(" "$D" | head -30

echo
echo "=== 工作区里此前的 WDT 寄存器常量 ==="
rg -n "0x1971|0x3808|WDT" /mnt/d/漏洞/UNIXNU/适配K70U/scripts /mnt/d/漏洞/UNIXNU/适配K70U/reports -g "*.py" -g "*.md" -g "*.sh" | head -10
