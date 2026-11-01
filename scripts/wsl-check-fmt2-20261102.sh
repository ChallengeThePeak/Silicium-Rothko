#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
D=/home/ubuntu/rothko-upstream-20261102/uefi-full/Platforms/Xiaomi/rothkoPkg/Drivers/RothkoDisplayDxe
U=/home/ubuntu/rothko-upstream-20261102/uefi-full

echo "=== 驱动里 PixelFormat / PixelInformation 的赋值 ==="
rg -n -B3 -A6 "PixelFormat|PixelInformation" "$D/RothkoDisplayDxe.c" | head -40

echo
echo "=== EDK2 枚举定义 ==="
rg -n -A6 "EFI_GRAPHICS_OUTPUT_PIXEL_FORMAT_BGR_32" "$U/Mu_Basecore/MdePkg/Include/Protocol/GraphicsOutput.h" | head -12

echo
echo "=== GraphicsConsoleDxe 如何按 PixelFormat 取每像素字节数 ==="
G="$U/Mu_Basecore/MdeModulePkg/Universal/Console/GraphicsConsoleDxe/GraphicsConsoleDxe.c"
rg -n "PixelFormat|BGR_24|BGR_32|RGB_32|PixelBytes|BytesPerPixel" "$G" | head -20
