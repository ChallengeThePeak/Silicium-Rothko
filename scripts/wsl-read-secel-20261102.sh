#!/bin/bash
set -u
U=/home/ubuntu/rothko-upstream-20261102/uefi-full
echo "=== ArchPeilessSec.c 1-70 ==="
sed -n '1,70p' "$U/Mu_Basecore/ArmPlatformPkg/PeilessSec/AArch64/ArchPeilessSec.c"
echo
echo "=== Silicium Sec ModuleEntryPoint.S（前 60 行）==="
sed -n '1,60p' "$U/Silicon/Silicium/SiliciumPkg/Sec/AArch64/ModuleEntryPoint.S"
