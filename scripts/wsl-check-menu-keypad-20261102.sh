#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
U=/home/ubuntu/rothko-upstream-20261102/uefi-full

echo "=== Extra.fdf.inc 引用的东西是否存在 ==="
for p in \
  "MdeModulePkg/Universal/Acpi/BootGraphicsResourceTableDxe/BootGraphicsResourceTableDxe.inf" \
  "MdeModulePkg/Universal/SetupBrowserDxe/SetupBrowserDxe.inf" \
  "MdeModulePkg/Application/BootManagerMenuApp/BootManagerMenuApp.inf" \
  "PcBdsPkg/MsBootPolicy/MsBootPolicy.inf" \
  "SiliciumPkg/Applications/UFPLoader/UFPLoader.inf" \
  "SiliciumPkg/Applications/UFP/ufpdevicefw.inf" \
  "SiliciumPkg/Include/Resources/BootLogo.bmp" \
  "SiliciumPkg/Include/Resources/NoBootOS.bmp" \
  "SiliciumPkg/Include/Resources/MassStorage.bmp" \
  "SiliciumPkg/Include/Resources/SecureBoot/SiPolicy.p7b" ; do
  if [ -e "$U/$p" ]; then echo "  OK      $p"; else echo "  缺失    $p"; fi
done

echo
echo "=== Boot-Manager.patch 是否已应用（找补丁特征）==="
rg -n "UEFI Misc Device|Power Off|UefiRuntimeServicesTableLib" \
   "$U/Mu_Basecore/MdeModulePkg/Application/BootManagerMenuApp/BootManagerMenu.c" 2>/dev/null | head -6 \
   || echo "  （补丁特征都不在 → 补丁未应用）"

echo
echo "=== 按键驱动：是否已在 DSC 里注册 ==="
rg -n "KeypadDxe|KeypadDeviceDxe" "$U/Silicon/Silicium/SiliciumPkg/SiliciumPkg.dsc.inc" 2>/dev/null | head -6
echo "--- 是否在某个 FDF include 里 ---"
rg -rn "KeypadDxe|KeypadDeviceDxe" "$U/Silicon/Silicium/SiliciumPkg" --glob "*.fdf.inc" 2>/dev/null | head -6

echo
echo "=== Keypad 驱动的设备路径/协议 ==="
rg -n "DevicePath|STI|gEfiSimpleTextInProtocol|InstallMultipleProtocol|KeypadDeviceDxe" \
   "$U/Silicon/Silicium/SiliciumPkg/Drivers/KeypadDeviceDxe"/*.c 2>/dev/null | head -12

echo
echo "=== BDS 的 SetupKeypad 找的是什么 ==="
rg -rn -B6 "Failed to Locate STI Device Path" "$U/Mu_Basecore/MdeModulePkg/Universal/BdsDxe" 2>/dev/null | head -20
