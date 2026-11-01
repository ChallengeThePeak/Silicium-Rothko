#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
U=/home/ubuntu/rothko-upstream-20261102/uefi-full

echo "=== PcdBootManagerMenuFile 的定义与取值 ==="
rg -rn "PcdBootManagerMenuFile" "$U" --glob "*.dec" --glob "*.dsc" --glob "*.inc" --glob "*.fdf" 2>/dev/null | head -12

echo
echo "=== BootManagerMenuApp.inf 的 [Sources] ==="
rg -n -A10 "^\[Sources" "$U/Mu_Basecore/MdeModulePkg/Application/BootManagerMenuApp/BootManagerMenuApp.inf" 2>/dev/null | head -14

echo
echo "=== 按键驱动提供的协议（KeypadDxe / KeypadTextIn）==="
rg -n "InstallMultipleProtocolInterfaces|gEfiSimpleTextInputExProtocolGuid|gEfiSimpleTextInputProtocolGuid|gKeypadDeviceProtocolGuid" \
   "$U/Silicon/Silicium/SiliciumPkg/Drivers/KeypadDxe"/*.c "$U/Silicon/Silicium/SiliciumPkg/Drivers/KeypadDeviceDxe"/*.c 2>/dev/null | head -12

echo
echo "=== SiliciumPkg.dsc.inc 里 Keypad 驱动的注册情况 ==="
rg -n "Keypad" "$U/Silicon/Silicium/SiliciumPkg/SiliciumPkg.dsc.inc" 2>/dev/null | head -6

echo
echo "=== Common.fdf.inc 里有几段 FV / 名字 ==="
rg -n "^\[FV|^FILE FV_IMAGE|^\[FD" "$U/Silicon/Silicium/SiliciumPkg/Common.fdf.inc" 2>/dev/null | head -14
