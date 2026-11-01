#!/bin/bash
# 给 SEC 模块补上帧缓冲 PCD 声明
set -u
export PATH=/home/ubuntu/bin:$PATH
I=/home/ubuntu/rothko-upstream-20261102/uefi-full/Silicon/Silicium/SiliciumPkg/Library/MemoryInitPeiLib/MemoryInitPeiLib.inf
Q=/home/ubuntu/quarantine
cp -f "$I" "$Q/MemoryInitPeiLib.inf.orig-$(date +%Y%m%d-%H%M%S)"

echo "=== 改前 ==="
cat "$I"

python3 - "$I" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
if "PcdFrameBufferWidth" in s:
    print("already declared"); raise SystemExit
anchor = "[LibraryClasses]"
add = """[FixedPcd]
  gSiliciumPkgTokenSpaceGuid.PcdFrameBufferWidth
  gSiliciumPkgTokenSpaceGuid.PcdFrameBufferHeight
  gSiliciumPkgTokenSpaceGuid.PcdFrameBufferStride

"""
if anchor not in s:
    sys.exit("anchor missing")
s = s.replace(anchor, add + anchor, 1)
open(p, "w", encoding="utf-8").write(s)
print("pcds declared")
PY

echo
echo "=== 改后 ==="
cat "$I"
