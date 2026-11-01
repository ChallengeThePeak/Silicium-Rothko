#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
U=/home/ubuntu/rothko-upstream-20261102/uefi-full
F=$(rg -l "BmDriverHealth" "$U/Mu_Basecore" -g "*.c" | grep -i bmdriverhealth | head -1)
echo "F=$F"
echo
echo "=== 540-575 ==="
sed -n '540,575p' "$F"
echo
echo "=== 该函数名 ==="
awk 'NR<=560 && /^[A-Za-z_].*\(/ {line=NR": "$0} END{}' "$F" >/dev/null
rg -n "^[A-Za-z_][A-Za-z0-9_]* \(" "$F" | awk -F: '$1 < 560' | tail -3
