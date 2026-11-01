#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
U=/home/ubuntu/rothko-upstream-20261102/uefi-full
OUT=/mnt/d/漏洞/UNIXNU/适配K70U/logs

{
echo "=== BootManagerMenuApp.inf 头部 ==="
head -20 "$U/Mu_Basecore/MdeModulePkg/Application/BootManagerMenuApp/BootManagerMenuApp.inf"

echo
echo "=== MdeModulePkg.dec 里 PcdBootManagerMenuFile ==="
rg -n "PcdBootManagerMenuFile" "$U/Mu_Basecore/MdeModulePkg/MdeModulePkg.dec"

echo
echo "=== KeypadDeviceLib 在哪、实现读什么地址 ==="
rg --files "$U" 2>/dev/null | rg "KeypadDeviceLib" | head -6
for f in $(rg --files "$U" 2>/dev/null | rg "KeypadDeviceLib/.*\.c$" | head -2); do
  echo "--- $f"
  rg -n "0x[0-9A-Fa-f]{6,}|MmioRead|ReadKey|GetKeys|KEYPAD" "$f" | head -14
done

echo
echo "=== KeypadDeviceDxe.inf 的依赖 ==="
cat "$U/Silicon/Silicium/SiliciumPkg/Drivers/KeypadDeviceDxe/KeypadDeviceDxe.inf"
} > "$OUT/menu-keypad-facts.txt" 2>&1

cat "$OUT/menu-keypad-facts.txt"
