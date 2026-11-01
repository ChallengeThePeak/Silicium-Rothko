#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
U=/home/ubuntu/rothko-upstream-20261102/uefi-full

echo "=== ArmGetPhysicalAddressBits 定义 ==="
rg -n --no-heading -A22 "^ArmGetPhysicalAddressBits \(" "$U/Mu_Basecore" -g "*.c" | head -35

echo
echo "=== MAX_VA_BITS ==="
rg -n "MAX_VA_BITS" "$U/Mu_Basecore" -g "*.c" -g "*.h" | head -10

echo
echo "=== TCR_T0SZ_MASK / ArmGetTCR ==="
rg -n "TCR_T0SZ_MASK|ArmGetTCR \(" "$U/Mu_Basecore" -g "*.c" | head -8
