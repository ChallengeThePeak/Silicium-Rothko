#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
U=/home/ubuntu/rothko-upstream-20261102/uefi-full
D=/home/ubuntu/rothko-evidence-20261101/Mu-Silicium-fv-membership-fixed/Platforms/Xiaomi/rothkoPkg/Drivers/RothkoDisplayDxe

echo "=== 上游是否有 FrameBufferBltLib / FdtLib ==="
rg --files "$U" -g "**/FrameBufferBltLib/**" -g "**/FdtLib/**" 2>/dev/null | head -10

echo
echo "=== gSiliciumEntryArgHobGuid 在上游 ==="
rg -rn "gSiliciumEntryArgHobGuid" "$U" -g "*.c" -g "*.h" -g "*.dec" 2>/dev/null | head -6

echo
echo "=== 上游 rothko.dsc 里的 framebuffer PCD ==="
rg -n "PcdFrameBuffer" "$U/Platforms/Xiaomi/rothkoPkg/rothko.dsc" "$U/Silicon/Silicium/SiliciumPkg/SiliciumPkg.dsc.inc" 2>/dev/null | head -12

echo
echo "=== RothkoDisplayDxe 里的 DALI / Dsi / 关键寄存器 ==="
rg -n -i "dali|dsi_start|0x1420|0x1440|mutex|1220|2712|stride|PcdFrameBuffer|Display Reserved|simple-framebuffer" "$D/RothkoDisplayDxe.c" 2>/dev/null | head -30

echo
echo "=== RothkoDisplayDxe 行数与前 60 行 ==="
wc -l "$D/RothkoDisplayDxe.c"
sed -n '1,60p' "$D/RothkoDisplayDxe.c"
