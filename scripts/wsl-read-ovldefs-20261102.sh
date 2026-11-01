#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
D=/home/ubuntu/rothko-upstream-20261102/uefi-full/Platforms/Xiaomi/rothkoPkg/Drivers/RothkoDisplayDxe

echo "=== OVL_* 偏移与 L_CON_* 常量 ==="
rg -n "^#define (OVL_|L_CON_|BIT|PANEL_)" "$D/RothkoDisplayDxe.c" | head -60

echo
echo "=== 打印 layer 的那段（完整）==="
sed -n '264,316p' "$D/RothkoDisplayDxe.c"

echo
echo "=== CollectScanout 全文 ==="
rg -n -A55 "^CollectScanout" "$D/RothkoDisplayDxe.c" | head -70
