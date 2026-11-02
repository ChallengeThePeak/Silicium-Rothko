#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
U=/home/ubuntu/rothko-upstream-20261102/uefi-full
OUT=/mnt/d/漏洞/UNIXNU/适配K70U/logs

{
for P in stonePkg c1sPkg gtaxlltePkg; do
  F="$U/Platforms/Xiaomi/$P/Library/KeypadDeviceLib/KeypadDeviceLib.c"
  [ -f "$F" ] || F="$U/Platforms/Samsung/$P/Library/KeypadDeviceLib/KeypadDeviceLib.c"
  [ -f "$F" ] || continue
  echo "########## $P : $F"
  rg -n "0x[0-9A-Fa-f]{6,}|MmioRead|MmioWrite|KEYPAD_BASE|BaseAddr|GetKeys|ReadKey|Status" "$F" | head -22
  echo
done

echo "########## tree 里的 KeypadDeviceLib 全清单"
rg --files "$U" 2>/dev/null | rg "KeypadDeviceLib/KeypadDeviceLib.c" | head -10

echo
echo "########## stonePkg 内存表里的 keypad 区"
rg -n -i "keypad|0x1000[0-9a-f]{4}" "$U/Platforms/Xiaomi/stonePkg/Library/MemoryMapLib/MemoryMapLib.c" | head -10
} > "$OUT/keypad-impls.txt" 2>&1
head -90 "$OUT/keypad-impls.txt"
