#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
U=/home/ubuntu/rothko-upstream-20261102/uefi-full
OUT=/mnt/d/漏洞/UNIXNU/适配K70U/logs

{
echo "=== stonePkg 的 KeypadDeviceLib（小米平台，MTK）==="
sed -n '1,140p' "$U/Platforms/Xiaomi/stonePkg/Library/KeypadDeviceLib/KeypadDeviceLib.c"

echo
echo "=== 它的 .inf ==="
cat "$U/Platforms/Xiaomi/stonePkg/Library/KeypadDeviceLib/KeypadDeviceLib.inf"

echo
echo "=== stonePkg 的内存表里有没有对应的 keypad MMIO 区 ==="
rg -n -i "keypad|topright|kp" "$U/Platforms/Xiaomi/stonePkg/Library/MemoryMapLib/MemoryMapLib.c" | head -8
} > "$OUT/keypad-stone.txt" 2>&1

head -120 "$OUT/keypad-stone.txt"
