#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
D=/home/ubuntu/rothko-upstream-20261102/uefi-full/Platforms/Xiaomi/rothkoPkg/Drivers/RothkoDisplayDxe

echo "=== 所有 EFI_INVALID_PARAMETER 的返回点 ==="
rg -n -B6 "EFI_INVALID_PARAMETER" "$D/RothkoDisplayDxe.c" | head -80
