#!/bin/bash
set -u
U=/home/ubuntu/rothko-upstream-20261102/uefi-full
H=$U/Silicon/Silicium/SiliciumPkg/Include/Library/MemoryMapLib.h
M=$U/Platforms/Xiaomi/rothkoPkg/Library/MemoryMapLib/MemoryMapLib.c
echo "=== MemoryMapLib.h 55-95 ==="
sed -n '55,95p' "$H"
echo
echo "=== rothko MemoryMapLib.c 1-20 ==="
sed -n '1,20p' "$M"
echo
echo "=== 表里 SYS_MEM_CAP_XN 出现次数 ==="
grep -c "SYS_MEM_CAP_XN" "$M"
