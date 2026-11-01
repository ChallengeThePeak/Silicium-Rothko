#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
L=/home/ubuntu/rothko-upstream-20261102/uefi-full/Silicon/Silicium/SiliciumPkg/Library/FrameBufferSerialPortLib

echo "=== 目录内容 ==="
ls -l "$L"

echo
echo "=== FrameBuffer.h ==="
cat "$L/FrameBuffer.h" 2>/dev/null

echo
echo "=== DrawGlyph 全文 ==="
awk '/^DrawGlyph/,/^}/' "$L/FrameBufferSerialPortLib.c" 2>/dev/null | head -70
