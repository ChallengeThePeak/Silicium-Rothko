#!/bin/bash
# 移植 RothkoDisplayDxe（GOP + DSI CMD 主动推帧）到上游 rothko 树
set -u
export PATH=/home/ubuntu/bin:$PATH
U=/home/ubuntu/rothko-upstream-20261102/uefi-full
OLD=/home/ubuntu/rothko-evidence-20261101/Mu-Silicium-fv-membership-fixed
Q=/home/ubuntu/quarantine
mkdir -p "$Q"

echo "=== 1) Mu_Basecore: 移植 RothkoStage.h ==="
mkdir -p "$U/Mu_Basecore/MdePkg/Include/Library"
cp -f "$OLD/Mu_Basecore/MdePkg/Include/Library/RothkoStage.h" \
      "$U/Mu_Basecore/MdePkg/Include/Library/RothkoStage.h"
cp -f "$U/Mu_Basecore/MdePkg/Include/Library/RothkoStage.h" \
      "$Q/RothkoStage.h.orig-$(date +%Y%m%d-%H%M%S)"
ls -l "$U/Mu_Basecore/MdePkg/Include/Library/RothkoStage.h"

echo
echo "=== 2) 移植驱动到 rothkoPkg/Drivers ==="
D="$U/Platforms/Xiaomi/rothkoPkg/Drivers/RothkoDisplayDxe"
mkdir -p "$D"
cp -f "$OLD/Platforms/Xiaomi/rothkoPkg/Drivers/RothkoDisplayDxe/RothkoDisplayDxe.c" "$D/"
cp -f "$OLD/Platforms/Xiaomi/rothkoPkg/Drivers/RothkoDisplayDxe/RothkoDisplayBounds.h" "$D/"
cp -f "$OLD/Platforms/Xiaomi/rothkoPkg/Drivers/RothkoDisplayDxe/RothkoDisplayDxe.inf" "$D/"
ls -l "$D"

echo
echo "=== 3) SiliciumPkg.dec 增加 PcdFrameBufferStride ==="
DEC="$U/Silicon/Silicium/SiliciumPkg/SiliciumPkg.dec"
cp -f "$DEC" "$Q/SiliciumPkg.dec.orig-$(date +%Y%m%d-%H%M%S)"
python3 - "$DEC" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
if "PcdFrameBufferStride" in s:
    print("already present"); raise SystemExit
anchor = "  gSiliciumPkgTokenSpaceGuid.PcdFrameBufferFreezeWhenFull|FALSE|BOOLEAN|0x0000A005"
if anchor not in s:
    sys.exit("dec anchor missing")
s = s.replace(anchor, anchor + "\n  gSiliciumPkgTokenSpaceGuid.PcdFrameBufferStride|0|UINT32|0x0000A006", 1)
open(p, "w", encoding="utf-8").write(s)
print("dec updated")
PY

echo
echo "=== 4) SiliciumPkg.dsc.inc 增加 Stride 默认值 ==="
DSC="$U/Silicon/Silicium/SiliciumPkg/SiliciumPkg.dsc.inc"
cp -f "$DSC" "$Q/SiliciumPkg.dsc.inc.orig-$(date +%Y%m%d-%H%M%S)"
python3 - "$DSC" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
if "PcdFrameBufferStride" in s:
    print("already present"); raise SystemExit
anchor = "  gSiliciumPkgTokenSpaceGuid.PcdFrameBufferDelay|10000          # In Microseconds"
if anchor not in s:
    sys.exit("dsc anchor missing")
s = s.replace(anchor, anchor + "\n  gSiliciumPkgTokenSpaceGuid.PcdFrameBufferStride|0", 1)
open(p, "w", encoding="utf-8").write(s)
print("dsc.inc updated")
PY

echo
echo "=== 5) rothkoPkg DXE.inc / APRIORI.inc 挂载驱动 ==="
for f in "$U/Platforms/Xiaomi/rothkoPkg/Include/DXE.inc" "$U/Platforms/Xiaomi/rothkoPkg/Include/APRIORI.inc"; do
  cp -f "$f" "$Q/$(basename $f).orig-$(date +%Y%m%d-%H%M%S)"
  python3 - "$f" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
line = "  INF Platforms/Xiaomi/rothkoPkg/Drivers/RothkoDisplayDxe/RothkoDisplayDxe.inf\n"
if "RothkoDisplayDxe.inf" in s:
    print("already mounted", p); raise SystemExit
if p.endswith("APRIORI.inc"):
    # GOP 必须在 GraphicsConsoleDxe 之前就位，否则控制台不会切到图形
    anchor = "  INF MdeModulePkg/Universal/Variable/RuntimeDxe/VariableRuntimeDxe.inf\n"
else:
    anchor = "  INF MdeModulePkg/Universal/PrintDxe/PrintDxe.inf\n"
if anchor not in s:
    sys.exit("anchor missing in " + p)
s = s.replace(anchor, anchor + line, 1)
open(p, "w", encoding="utf-8").write(s)
print("mounted", p)
PY
done

echo
echo "=== 6) rothko.dsc 增加 framebuffer PCD ==="
R="$U/Platforms/Xiaomi/rothkoPkg/rothko.dsc"
cp -f "$R" "$Q/rothko.dsc.orig-$(date +%Y%m%d-%H%M%S)"
python3 - "$R" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
if "PcdFrameBufferWidth" in s:
    print("already present"); raise SystemExit
anchor = "  gSiliciumPkgTokenSpaceGuid.PcdDriverHealthConfigureForm|{0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0}"
if anchor not in s:
    sys.exit("dsc anchor missing")
add = anchor + """
  #
  # [k70u-fix 2026-11-02] Panel geometry validated on dali (MT6991) and on the
  # stock LK handoff for rothko: DSC + DSI command mode, 1220x2712, 32bpp.
  # Stride is the pitch the OVL layer actually uses (1248 = 1220 * 4 + 128).
  # Delay 0: the framebuffer console must not slow the log down.
  #
  gSiliciumPkgTokenSpaceGuid.PcdFrameBufferWidth|1220
  gSiliciumPkgTokenSpaceGuid.PcdFrameBufferHeight|2712
  gSiliciumPkgTokenSpaceGuid.PcdFrameBufferColorDepth|32
  gSiliciumPkgTokenSpaceGuid.PcdFrameBufferStride|1248
  gSiliciumPkgTokenSpaceGuid.PcdFrameBufferDelay|0"""
s = s.replace(anchor, add, 1)
open(p, "w", encoding="utf-8").write(s)
print("rothko.dsc updated")
PY
echo "DONE-PORT-1"
