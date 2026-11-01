#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
U=/home/ubuntu/rothko-upstream-20261102/uefi-full
OUT=/mnt/d/漏洞/UNIXNU/适配K70U/logs
F="$U/Platforms/Xiaomi/stonePkg/Library/KeypadDeviceLib/KeypadDeviceLib.c"

{
echo "=== 硬件访问与寄存器 ==="
rg -n "Mmio|0x[0-9A-Fa-f]{4,}|KEYPAD_BASE|Base\b|ReadKey|GetKeys|Status" "$F" | head -30

echo
echo "=== GetKeys 实现 ==="
awk '/^KeypadDeviceGetKeys/,/^}/' "$F" | head -60

echo
echo "=== 它 include 的头 ==="
rg -n "#include" "$F" | head -12

echo
echo "=== stonePkg 内存表里 keypad 区 ==="
rg -n -i "keypad|0x1[0-9A-Fa-f]{7}" "$U/Platforms/Xiaomi/stonePkg/Library/MemoryMapLib/MemoryMapLib.c" | head -10
} > "$OUT/keypad-stone2.txt" 2>&1
cat "$OUT/keypad-stone2.txt" | head -80
