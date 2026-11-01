#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
U=/home/ubuntu/rothko-upstream-20261102/uefi-full
B="$U/Mu_Basecore"
S="$U/Silicon/Silicium/SiliciumPkg"

echo "=== Extra.fdf.inc 依赖是否存在（修正前缀）==="
check() { if [ -e "$1" ]; then echo "  OK      $2"; else echo "  缺失    $2"; fi; }
check "$B/MdeModulePkg/Universal/Acpi/BootGraphicsResourceTableDxe/BootGraphicsResourceTableDxe.inf" "Mu_Basecore/MdeModulePkg/.../BootGraphicsResourceTableDxe.inf"
check "$B/MdeModulePkg/Universal/SetupBrowserDxe/SetupBrowserDxe.inf"       "Mu_Basecore/MdeModulePkg/.../SetupBrowserDxe.inf"
check "$B/MdeModulePkg/Application/BootManagerMenuApp/BootManagerMenuApp.inf" "Mu_Basecore/MdeModulePkg/.../BootManagerMenuApp.inf"
check "$B/PcBdsPkg/MsBootPolicy/MsBootPolicy.inf"                          "Mu_Basecore/PcBdsPkg/MsBootPolicy/MsBootPolicy.inf"
check "$S/Applications/UFPLoader/UFPLoader.inf"                           "SiliciumPkg/Applications/UFPLoader/UFPLoader.inf"
check "$S/Applications/UFP/ufpdevicefw.inf"                               "SiliciumPkg/Applications/UFP/ufpdevicefw.inf"
check "$S/Include/Resources/BootLogo.bmp"                                  "SiliciumPkg/Include/Resources/BootLogo.bmp"
check "$S/Include/Resources/NoBootOS.bmp"                                  "SiliciumPkg/Include/Resources/NoBootOS.bmp"
check "$S/Include/Resources/MassStorage.bmp"                               "SiliciumPkg/Include/Resources/MassStorage.bmp"
check "$S/Include/Resources/SecureBoot/SiPolicy.p7b"                       "SiliciumPkg/Include/Resources/SecureBoot/SiPolicy.p7b"

echo
echo "=== 按键驱动文件 ==="
ls "$S/Drivers/KeypadDeviceDxe" "$S/Drivers/KeypadDxe" 2>/dev/null | head -12

echo
echo "=== DSC 里是否已注册 按键/SetupBrowser/BootManagerMenuApp ==="
rg -n "KeypadDxe|KeypadDeviceDxe|SetupBrowserDxe|BootManagerMenuApp" "$U/Silicon/Silicium/SiliciumPkg/SiliciumPkg.dsc.inc" 2>/dev/null | head -8

echo
echo "=== BDS 里 SetupKeypad 找 STI 的代码 ==="
rg -rn -B10 "STI Device Path" "$B/MdeModulePkg/Universal/BdsDxe" "$B/MdeModulePkg/Library" 2>/dev/null | head -24

echo
echo "=== KeypadDevice 的设备路径定义 ==="
rg -n -B3 -A12 "KeypadDevicePath" "$S/Drivers/KeypadDeviceDxe"/*.c 2>/dev/null | head -30
