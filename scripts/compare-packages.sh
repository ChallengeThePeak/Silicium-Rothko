#!/bin/bash
# Compare the rothko board package against the working yunluo one.
#
# yunluo boots successfully with the same Mu-Silicium and the same MTK boot
# chain, so any structural difference in the memory map or the DSC wiring is a
# prime suspect when rothko never reaches DXE.
set -uo pipefail

YU=/mnt/d/漏洞/UNIXNU/src/Mu-Silicium/Platforms/Xiaomi/yunluoPkg
RO=/home/ubuntu/rothko/Mu-Silicium/Platforms/Xiaomi/rothkoPkg

for pkg in "$YU" "$RO"; do
  echo "=================================================================="
  echo "package: $pkg"
  echo "=================================================================="
  if [ ! -d "$pkg" ]; then
    echo "  MISSING"
    continue
  fi
  echo "--- files ---"
  find "$pkg" -type f | sed "s|$pkg/||" | sort
  echo
  echo "--- MemoryMapLib ---"
  f=$(find "$pkg" -name 'MemoryMapLib.c' | head -1)
  if [ -n "$f" ]; then
    sed -n '1,80p' "$f"
  else
    echo "  none"
  fi
  echo
done
