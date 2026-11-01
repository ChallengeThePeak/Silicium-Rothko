#!/bin/bash
# 1) 撤掉 SEC 的 handoff 发布与 [FixedPcd]（SEC 阶段嫌疑最大，先撤）
# 2) 日志库加几何合法性校验：垃圾 handoff 一律忽略
set -u
export PATH=/home/ubuntu/bin:$PATH
U=/home/ubuntu/rothko-upstream-20261102/uefi-full
SEC_C="$U/Silicon/Silicium/SiliciumPkg/Library/MemoryInitPeiLib/MemoryInitPei.c"
SEC_I="$U/Silicon/Silicium/SiliciumPkg/Library/MemoryInitPeiLib/MemoryInitPeiLib.inf"
LIB="$U/Silicon/Silicium/SiliciumPkg/Library/FrameBufferSerialPortLib/FrameBufferSerialPortLib.c"
Q=/home/ubuntu/quarantine
for f in "$SEC_C" "$SEC_I" "$LIB"; do cp -f "$f" "$Q/$(basename $f).pre-sec-revert-$(date +%Y%m%d-%H%M%S)"; done

python3 - "$SEC_C" "$SEC_I" "$LIB" <<'PY'
import re, sys
sec_c, sec_i, lib = sys.argv[1], sys.argv[2], sys.argv[3]

# ---------- 1) SEC 源码：去掉发布代码 ----------
s = open(sec_c, encoding="utf-8").read()
m = re.search(r"\n  //\n  // \[k70u-fix 2026-11-02\] Publish the frame buffer geometry before anything is.*?\n  \}\n", s, re.S)
if m:
    s = s[:m.start()] + "\n" + s[m.end():]
    print("sec: publish code removed")
s = s.replace("#include <Library/FrameBufferHandoff.h>\n", "")
s = s.replace("#include <Library/MemoryMapHelperLib.h>\n", "")
open(sec_c, "w", encoding="utf-8").write(s)

# ---------- 2) SEC .inf：去掉 [FixedPcd] ----------
t = open(sec_i, encoding="utf-8").read()
t = re.sub(r"\[FixedPcd\]\n(  gSiliciumPkgTokenSpaceGuid\.PcdFrameBuffer\w+\n)+", "", t)
open(sec_i, "w", encoding="utf-8").write(t)
print("sec: inf pcds removed")

# ---------- 3) 日志库：校验 handoff 几何 ----------
u = open(lib, encoding="utf-8").read()
old = """  // Handed-off Geometry, valid only once its Magic is set
  Handoff = (CONST volatile FB_HANDOFF *)(UINTN)(FbBase + FbLength - FB_HANDOFF_OFFSET);
  if (Handoff->Magic == FB_HANDOFF_MAGIC) {
    mFbGeometry.Base       = (UINTN)Handoff->Base;
    mFbGeometry.Width      = Handoff->Width;
    mFbGeometry.Height     = Handoff->Height;
    mFbGeometry.PitchBytes = Handoff->PitchBytes;
  }"""
new = """  // Handed-off Geometry, valid only once its Magic is set
  Handoff = (CONST volatile FB_HANDOFF *)(UINTN)(FbBase + FbLength - FB_HANDOFF_OFFSET);
  if (Handoff->Magic == FB_HANDOFF_MAGIC) {
    //
    // [k70u-fix 2026-11-02] The record lives in DRAM that a previous boot (or
    // the stock bootloader) left behind, so a stale or random value can look
    // like a valid magic. Only accept a geometry that is self-consistent and
    // fits the carveout, otherwise a bogus Width or Pitch would send the
    // console walking far outside the frame buffer.
    //
    if ((Handoff->Width != 0) && (Handoff->Height != 0) &&
        (Handoff->PitchBytes >= Handoff->Width * FB_BPP) &&
        (Handoff->PitchBytes <= (16U * 1024U * 1024U)) &&
        (Handoff->Base >= FbBase) && (Handoff->Base < FbBase + FbLength))
    {
      mFbGeometry.Base       = (UINTN)Handoff->Base;
      mFbGeometry.Width      = Handoff->Width;
      mFbGeometry.Height     = Handoff->Height;
      mFbGeometry.PitchBytes = Handoff->PitchBytes;
    }
  }"""
if old in u:
    u = u.replace(old, new, 1); print("lib: handoff validated")
else:
    print("lib: handoff block not found")
open(lib, "w", encoding="utf-8").write(u)
PY

echo
echo "=== 校验 ==="
rg -n "Publish the frame buffer geometry" "$SEC_C" || echo "SEC 发布代码已移除"
rg -n "PcdFrameBuffer" "$SEC_I" || echo "SEC .inf 的 PCD 已移除"
rg -n "Handoff->Width != 0" "$LIB" | head -2
