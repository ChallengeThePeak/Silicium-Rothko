#!/bin/bash
set -u
U=/home/ubuntu/rothko-upstream-20261102/uefi-full
B=$(find "$U/Mu_Basecore" -path "*BdsDxe*" -name "BdsDxe.inf" | head -1)
H=$(find "$U/Mu_Basecore" -path "*HiiDatabaseDxe*" -name "HiiDatabaseDxe.inf" | head -1)
echo "BdsDxe.inf = $B"
echo "--- Depex ---"
grep -n -A8 "\[Depex" "$B" | head -20
echo
echo "HiiDatabaseDxe.inf = $H"
echo "--- Depex ---"
grep -n -A8 "\[Depex" "$H" | head -20
echo
echo "=== BdsDxe.inf 中 LibraryClasses 是否含 UefiHiiServicesLib ==="
grep -n "UefiHiiServicesLib" "$B"
