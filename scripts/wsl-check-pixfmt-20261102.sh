#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
D=/home/ubuntu/rothko-upstream-20261102/uefi-full/Platforms/Xiaomi/rothkoPkg/Drivers/RothkoDisplayDxe
U=/home/ubuntu/rothko-upstream-20261102/uefi-full

echo "=== 驱动里 PixelFormat / PixelInformation 的设置 ==="
rg -n "PixelFormat|PixelInformation|PixelsPerScanLine|BitsPerPixel|EFI_GRAPHICS_OUTPUT_PIXEL_FORMAT" "$D/RothkoDisplayDxe.c" | head -20

echo
echo "=== 驱动里的相关常量 ==="
rg -n "PIXEL_FORMAT|FORMAT_" "$D/RothkoDisplayDxe.c" | head -12

echo
echo "=== GraphicsConsoleDxe 怎么处理 PixelFormat（像素字节数）==="
rg -n "PixelFormat|BGR_24|BGR_32|BytesPerPixel|PixelBytes" "$U/Mu_Basecore/MdeModulePkg/Universal/Console/GraphicsConsoleDxe/GraphicsConsoleDxe.c" 2>/dev/null | head -20
