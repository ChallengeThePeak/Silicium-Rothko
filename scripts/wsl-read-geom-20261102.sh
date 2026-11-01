#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
L=/home/ubuntu/rothko-upstream-20261102/uefi-full/Silicon/Silicium/SiliciumPkg/Library/FrameBufferSerialPortLib

echo "=== LoadGeometry 全文 ==="
awk '/^LoadGeometry/,/^}/' "$L/FrameBufferSerialPortLib.c" 2>/dev/null | head -60

echo
echo "=== FrameBufferHandoff.h ==="
find /home/ubuntu/rothko-upstream-20261102/uefi-full -name "FrameBufferHandoff.h" | head -2 | while read f; do echo "FILE=$f"; cat "$f"; done

echo
echo "=== 谁写 FrameBufferHandoff（FB_HANDOFF_MAGIC）==="
rg -rln "FB_HANDOFF_MAGIC|FrameBufferHandoff" /home/ubuntu/rothko-upstream-20261102/uefi-full --glob "*.c" --glob "*.h" 2>/dev/null | head -8
