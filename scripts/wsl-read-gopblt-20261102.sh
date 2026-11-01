#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
D=/home/ubuntu/rothko-upstream-20261102/uefi-full/Platforms/Xiaomi/rothkoPkg/Drivers/RothkoDisplayDxe/RothkoDisplayDxe.c

echo "=== 驱动的 GOP Blt ==="
awk '/^RothkoGopBlt|^FrameBufferGopBlt/,/^}/' "$D" 2>/dev/null | head -60

echo
echo "=== 驱动里 InstallGop 前后（确定插入 handoff 的位置）==="
rg -n "ProbeScanouts \(\)|InstallGop \(ImageHandle\)|mFbBase =|mFbSize =" "$D" | head -12
