#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
D=/home/ubuntu/rothko-upstream-20261102/uefi-full/Platforms/Xiaomi/rothkoPkg/Drivers/RothkoDisplayDxe

echo "=== 打印 OVL layer 的地方 ==="
rg -n -B25 'size=%' "$D/RothkoDisplayDxe.c" | head -60

echo
echo "=== LayerIsLinear / CollectScanout ==="
rg -n -A40 "^LayerIsLinear" "$D/RothkoDisplayDxe.c" | head -55
