#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
U=/home/ubuntu/rothko-upstream-20261102/uefi-full

echo "=== rothko.fdf 全文（关键段）==="
sed -n '20,75p' "$U/Platforms/Xiaomi/rothkoPkg/rothko.fdf"

echo
echo "=== Extra.fdf.inc 里引用的东西是否存在 ==="
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
echo "=== 哪些平台 include 了 Extra.fdf.inc ==="
rg -rn "Extra.fdf.inc" "$U/Platforms" "$U/Silicon" 2>/dev/null | head -10
