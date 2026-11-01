#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
D=/home/ubuntu/rothko-upstream-20261102/uefi-full/Platforms/Xiaomi/rothkoPkg/Drivers/RothkoDisplayDxe/RothkoDisplayDxe.c

echo "=== 含 FrameBufferBlt 的函数 ==="
rg -n "FrameBufferBlt \(|BltOperation|EfiBltVideoFill|EfiBltBufferToVideo|EfiBltVideoToVideo" "$D" | head -20

echo
echo "=== 该函数上下文 ==="
N=$(rg -n "FrameBufferBlt \(" "$D" | head -1 | cut -d: -f1)
echo "行 $N"
S=$((N - 45)); [ "$S" -lt 1 ] && S=1
sed -n "${S},$((N + 30))p" "$D"
