#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
U=/home/ubuntu/rothko-upstream-20261102/uefi-full
OLD=/home/ubuntu/rothko-evidence-20261101/Mu-Silicium-fv-membership-fixed

echo "=== 上游 FrameBufferBltLib / FdtLib ==="
rg --files "$U" -g "**/FrameBufferBltLib/*.c" -g "**/FdtLib/*.c" -g "**/FdtLib/*.h" 2>/dev/null | head -8

echo
echo "=== 上游 gSiliciumEntryArgHobGuid ==="
rg -ln "gSiliciumEntryArgHobGuid" "$U" 2>/dev/null | head -6

echo
echo "=== 上游 PcdFrameBuffer* ==="
rg -n "PcdFrameBuffer" "$U/Silicon/Silicium/SiliciumPkg/SiliciumPkg.dec" "$U/Silicon/Silicium/SiliciumPkg/SiliciumPkg.dsc.inc" "$U/Platforms/Xiaomi/rothkoPkg/rothko.dsc" 2>/dev/null | head -14

echo
echo "=== 旧树里的 RothkoStage.h / BootDevices.h 位置 ==="
rg --files "$OLD" -g "RothkoStage.h" -g "BootDevices.h" 2>/dev/null | head -6

echo
echo "=== 旧树 rothkoPkg 里 RothkoDisplayDxe 的 INF 与 APRIORI 行 ==="
rg -n "RothkoDisplayDxe|RothkoWatchdogDxe" "$OLD/Platforms/Xiaomi/rothkoPkg/Include/DXE.inc" "$OLD/Platforms/Xiaomi/rothkoPkg/Include/APRIORI.inc" 2>/dev/null | head -8

echo
echo "=== 旧树 rothko.dsc 的 framebuffer PCD 取值 ==="
rg -n "PcdFrameBuffer|Display Reserved" "$OLD/Platforms/Xiaomi/rothkoPkg/rothko.dsc" "$OLD/Platforms/Xiaomi/rothkoPkg/Library/MemoryMapLib/MemoryMapLib.c" 2>/dev/null | head -14
