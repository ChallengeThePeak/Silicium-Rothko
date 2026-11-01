#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
D=/home/ubuntu/rothko-upstream-20261102/uefi-full/Platforms/Xiaomi/rothkoPkg/Drivers/RothkoDisplayDxe

echo "=== 关键常量 ==="
rg -n "^#define" "$D/RothkoDisplayDxe.c" | rg -i "OVL_|L_CON_|BIT|PANEL_" | head -45

echo
echo "=== ProbeScanouts / 调用关系 ==="
rg -n -B3 -A40 "ProbeScanouts" "$D/RothkoDisplayDxe.c" | head -70
