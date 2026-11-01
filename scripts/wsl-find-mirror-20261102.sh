#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
D=/home/ubuntu/rothko-upstream-20261102/uefi-full/Platforms/Xiaomi/rothkoPkg/Drivers/RothkoDisplayDxe

echo "=== Refresh / 镜像相关函数 ==="
rg -n "Mirror|mirror|Refresh|MemCopy|CopyMem|mScanoutPitch|mScanoutByteSwap|mScanouts" "$D/RothkoDisplayDxe.c" | head -40
