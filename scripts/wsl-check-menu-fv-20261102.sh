#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
U=/home/ubuntu/rothko-upstream-20261102/uefi-full
OUT=/mnt/d/漏洞/UNIXNU/适配K70U/logs

{
echo "=== FV 里是否有菜单 FFS（GUID EEC25BDC-…）与 SetupBrowserDxe ==="
rg -n "EEC25BDC|SetupBrowserDxe" "$U/Build/rothkoPkg/DEBUG_CLANGDWARF/FV/FVMAIN.inf" | head -6

echo
echo "=== 我们平台用的 PlatformBootManagerLib 是哪个 ==="
rg -n "PlatformBootManagerLib" "$U/Silicon/Silicium/SiliciumPkg/SiliciumPkg.dsc.inc" "$U/Platforms/Xiaomi/rothkoPkg/rothko.dsc" | head -4

echo
echo "=== Silicium 的 PlatformBootManagerLib：有没有自动弹菜单/音量键逻辑 ==="
rg -rn "BootManagerMenu|KeyCallback|KeypadBuffer|EfiResetShutdown|Volume" \
   "$U/Silicon/Silicium/SiliciumPkg/Library" --glob "*.c" -l 2>/dev/null | head -6

echo
echo "=== KeyCallback.c 的调用者与作用（前 40 行）==="
rg -rn -B4 "KeyCallback|KeypadBuffer\[" \
   "$U/Silicon/Silicium/SiliciumPkg/Library" --glob "*.c" 2>/dev/null | head -30
} > "$OUT/menu-fv-check.txt" 2>&1
cat "$OUT/menu-fv-check.txt" | head -60
