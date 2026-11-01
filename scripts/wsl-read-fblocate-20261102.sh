#!/bin/bash
set -u
F=/home/ubuntu/rothko-upstream-20261102/uefi-full/Silicon/Silicium/SiliciumPkg/Library/FrameBufferSerialPortLib/FrameBufferSerialPortLib.c
H=/home/ubuntu/rothko-upstream-20261102/uefi-full/Silicon/Silicium/SiliciumPkg/Include/Library/MemoryMapHelperLib.h
echo "=== GetFrameBufferMemory ==="
sed -n '325,370p' "$F"
echo
echo "=== LocateMemoryRegionByName 原型 ==="
sed -n '10,35p' "$H"
echo
echo "=== MemoryMapHelperLib 实现（失败时是否写输出参数）==="
IMPL=$(find /home/ubuntu/rothko-upstream-20261102/uefi-full/Silicon/Silicium -name "MemoryMapHelper.c" | head -1)
echo "IMPL=$IMPL"
awk '/^LocateMemoryRegionByName/,/^}/' "$IMPL" | head -40
