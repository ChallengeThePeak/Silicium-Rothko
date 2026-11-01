#!/bin/bash
set -u
F=/home/ubuntu/rothko-upstream-20261102/uefi-full/Silicon/Silicium/SiliciumPkg/Library/MemoryInitPeiLib/MemoryInitPei.c
echo "=== 行数 ==="; wc -l "$F"
echo "=== BuildResourceDescriptorHob 上下文 ==="
grep -n -B25 -A20 "BuildResourceDescriptorHob" "$F" | head -90
