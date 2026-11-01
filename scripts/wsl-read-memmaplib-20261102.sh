#!/bin/bash
set -u
U=/home/ubuntu/rothko-upstream-20261102/uefi-full
echo "=== SiliciumPkg MemoryMapLib 实现位置 ==="
find "$U/Silicon/Silicium" -name "MemoryMapLib.c" | head -5
echo
echo "=== BuildResourceDescriptorHob 调用点 ==="
for f in $(find "$U/Silicon/Silicium" -name "MemoryMapLib.c" | head -3); do
  echo "### $f"
  grep -n -B6 -A12 "BuildResourceDescriptor" "$f" | head -60
done
