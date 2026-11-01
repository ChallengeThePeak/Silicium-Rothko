#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
U=/home/ubuntu/rothko-upstream-20261102/uefi-full

echo "=== DXE 阶段异常处理实现 ==="
rg -n "Synchronous Exception" "$U/Mu_Basecore" -g "*.c" | grep -v "ArmPlatformPkg/Sec" | head -8

echo
echo "=== 候选文件里的收尾循环 ==="
for f in $(rg -l "Synchronous Exception" "$U/Mu_Basecore" -g "*.c" | grep -v "ArmPlatformPkg/Sec" | head -3); do
  echo "### $f"
  rg -n "CpuDeadLoop|while \(1\)|ASSERT" "$f" | head -5
done

echo
echo "=== DebugLib.DebugAssert 结尾 ==="
sed -n '211,245p' "$U/Mu_Basecore/MdePkg/Library/BaseDebugLibSerialPort/DebugLib.c"
