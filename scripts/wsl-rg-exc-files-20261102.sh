#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
U=/home/ubuntu/rothko-upstream-20261102/uefi-full

echo "=== 含 Synchronous Exception 的文件 ==="
rg -l "Synchronous Exception" "$U/Mu_Basecore" -g "*.c" | head -10

echo
echo "=== 含 Data abort 的文件（DXE 异常打印）==="
rg -l "Data abort|Instruction abort" "$U/Mu_Basecore" -g "*.c" | head -10

echo
echo "=== CpuExceptionHandlerLib 实现位置 ==="
rg --files "$U/Mu_Basecore" -g "*CpuExceptionHandlerLib*" -g "*.c" | head -10
