#!/bin/bash
set -u
U=/home/ubuntu/rothko-upstream-20261102/uefi-full
echo "=== BdsDxe.inf 的 Depex ==="
F=$(find "$U/Mu_Basecore" -path "*BdsDxe*" -name "BdsDxe.inf" | head -1)
echo "$F"
awk '/\[Depex\]/,0' "$F" | head -15

echo
echo "=== UefiHiiServicesLib.c 70-95 ==="
L=$(find "$U/Mu_Basecore" -name "UefiHiiServicesLib.c" | head -1)
echo "$L"
sed -n '60,95p' "$L"

echo
echo "=== DXE.inc 中的 HiiDatabase / BdsDxe 行 ==="
grep -n "HiiDatabase\|BdsDxe\|PrintDxe" "$U/Platforms/Xiaomi/rothkoPkg/Include/DXE.inc"

echo
echo "=== APRIORI.inc 全文 ==="
cat "$U/Platforms/Xiaomi/rothkoPkg/Include/APRIORI.inc"

echo
echo "=== 最终 FV 里是否有 HiiDatabaseDxe ==="
X=$(find "$U/Build/rothkoPkg" -name "Guid.xref" | head -1)
echo "xref=$X"
grep -i "HiiDatabase\|BdsDxe" "$X" 2>/dev/null | head -5
