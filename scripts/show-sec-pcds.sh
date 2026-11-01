#!/bin/bash
# Print the PCD values that actually ended up in the SEC build.
#
# These decide where SEC thinks the firmware volume is, where its stack lives
# and how much DCache it maintains at entry. A wrong PcdFdBaseAddress makes
# SecEntry clean the wrong 2 MiB, which faults or hangs before DXE.
set -uo pipefail

BUILD="${1:-/home/ubuntu/rothko/Mu-Silicium/Build/rothkoPkg/DEBUG_CLANGPDB/AARCH64}"

f=$(find "$BUILD" -path '*Sec/DEBUG/AutoGen.h' | head -1)
if [ -z "$f" ]; then
  echo "AutoGen.h for Sec not found under $BUILD" >&2
  exit 1
fi

echo "file: $f"
echo "---------------------------------------------------"
grep -E 'PcdFdBaseAddress|PcdFdSize|PcdCPUCoresStackBase|PcdCPUCorePrimaryStackSize|PcdSystemMemoryBase|PcdFvBaseAddress|PcdFvSize|PcdCoreCount|PcdClusterCount' "$f"
