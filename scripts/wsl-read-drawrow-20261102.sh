#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
L=/home/ubuntu/rothko-upstream-20261102/uefi-full/Silicon/Silicium/SiliciumPkg/Library/FrameBufferSerialPortLib/FrameBufferSerialPortLib.c

echo "=== DrawRow ==="
awk '/^DrawRow/,/^}/' "$L" 2>/dev/null | head -40

echo
echo "=== WriteFrameBuffer ==="
awk '/^WriteFrameBuffer/,/^}/' "$L" 2>/dev/null | head -60

echo
echo "=== 0xFF000000 / alpha 相关 ==="
rg -n "0xFF000000|FillColor|PixelColor|0xFFFFFFFF" "$L" | head -12
