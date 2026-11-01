#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
U=/home/ubuntu/rothko-upstream-20261102/uefi-full

echo "=== MdeModulePkg.fdf 里 BootManagerMenu 怎么进 FV ==="
rg -rn "BootManagerMenu" "$U/Mu_Basecore/MdeModulePkg/MdeModulePkg.fdf" 2>/dev/null | head -8

echo
echo "=== 全树 FDF 里 BootManagerMenu 的 FFS 名 ==="
rg -rn "BootManagerMenu" "$U" --glob "*.fdf" --glob "*.inc" 2>/dev/null | head -12

echo
echo "=== KeypadDeviceDxe.c 全文（看它读什么硬件）==="
cat "$U/Silicon/Silicium/SiliciumPkg/Drivers/KeypadDeviceDxe/KeypadDeviceDxe.c" 2>/dev/null | head -60

echo
echo "=== KeypadDxe 的设备路径/KeypadDevice 协议头 ==="
rg -n "KeypadDevicePath|gKeypadDeviceProtocolGuid|ReadKey|GetKey" \
   "$U/Silicon/Silicium/SiliciumPkg/Drivers/KeypadDeviceDxe"/*.h \
   "$U/Silicon/Silicium/SiliciumPkg/Drivers/KeypadDxe"/*.h 2>/dev/null | head -12
