#!/bin/bash
set -u
F=/home/ubuntu/rothko-upstream-20261102/uefi-full/Silicon/Silicium/SiliciumPkg/Library/FrameBufferSerialPortLib/FrameBufferSerialPortLib.c
echo "=== 关键函数位置 ==="
grep -n "^SerialPortWrite\|^SerialPortInitialize\|GetFrameBufferMemory\|CacheMaintenance\|InvalidateDataCache\|WriteBack\|FbRegion" "$F" | head -25
echo
echo "=== SerialPortWrite 全文 ==="
awk '/^SerialPortWrite/,/^}/' "$F" | head -70
