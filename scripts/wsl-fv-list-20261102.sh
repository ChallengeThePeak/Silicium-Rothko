#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
U=/home/ubuntu/rothko-upstream-20261102/uefi-full
OUT=/mnt/d/漏洞/UNIXNU/适配K70U/logs

{
echo "=== FVMAIN.inf 里所有 FFS 名（含 Setup/Form/Browser）==="
rg -o "Ffs/[^/]+" "$U/Build/rothkoPkg/DEBUG_CLANGDWARF/FV/FVMAIN.inf" | sort -u | head -60

echo
echo "=== FDF 里 SetupBrowserDxe 出现在哪 ==="
rg -rn "SetupBrowserDxe" "$U/Platforms/Xiaomi/rothkoPkg" "$U/Silicon/Silicium/SiliciumPkg" --glob "*.fdf" --glob "*.inc" 2>/dev/null | head -8

echo
echo "=== rothko.fdf 的 FV 段结构 ==="
sed -n '25,70p' "$U/Platforms/Xiaomi/rothkoPkg/rothko.fdf"
} > "$OUT/fv-list.txt" 2>&1
cat "$OUT/fv-list.txt" | head -90
