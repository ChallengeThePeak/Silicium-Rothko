#!/bin/bash
# 修复 FrameBufferSerialPortLib：未初始化 FbRegion + 越界缓存刷新
set -u
F=/home/ubuntu/rothko-upstream-20261102/uefi-full/Silicon/Silicium/SiliciumPkg/Library/FrameBufferSerialPortLib/FrameBufferSerialPortLib.c
Q=/home/ubuntu/quarantine
mkdir -p "$Q"
cp -f "$F" "$Q/FrameBufferSerialPortLib.c.orig-$(date +%Y%m%d-%H%M%S)"

python3 - "$F" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
if "k70u-fix 2026-11-02" in s:
    print("already patched"); raise SystemExit

old1 = '''  EFI_MEMORY_REGION_DESCRIPTOR FbRegion;

  // Locate "Display Reserved" Memory Region
  LocateMemoryRegionByName ("Display Reserved", &FbRegion);
  LocateMemoryRegionByName ("Display_Reserved", &FbRegion);
  if (!FbRegion.Address && !FbRegion.Length) {
    return EFI_NOT_FOUND;
  }'''
new1 = '''  //
  // [k70u-fix 2026-11-02] LocateMemoryRegionByName() does not touch its output
  // parameter when the region is absent, so an uninitialised FbRegion left stack
  // garbage that was then used as the framebuffer base: the pixel writes and the
  // DC-by-MVA flush went to an untranslated address and raised a synchronous
  // exception. Zero it and honour the lookup status instead.
  //
  EFI_MEMORY_REGION_DESCRIPTOR FbRegion = { 0 };

  // Locate "Display Reserved" Memory Region
  if (EFI_ERROR (LocateMemoryRegionByName ("Display Reserved", &FbRegion)) &&
      EFI_ERROR (LocateMemoryRegionByName ("Display_Reserved", &FbRegion)))
  {
    return EFI_NOT_FOUND;
  }

  if ((FbRegion.Address == 0) || (FbRegion.Length == 0)) {
    return EFI_NOT_FOUND;
  }'''
if old1 not in s:
    sys.exit("patch1 anchor not found")
s = s.replace(old1, new1, 1)

old2 = '''  // Flush Frame Buffer
  WriteBackInvalidateDataCacheRange ((VOID *)mFbGeometry.Base, (UINTN)FB_PITCH * FB_HEIGHT);'''
new2 = '''  //
  // [k70u-fix 2026-11-02] Clamp the flush to the mapped display region. A cache
  // maintenance operation on an untranslated address traps, and doing it from the
  // logger turns a single fault into the recursive exception seen on device.
  //
  if ((mFbGeometry.Base >= (UINTN)FbBase) &&
      (mFbGeometry.Base < (UINTN)(FbBase + FbLength)))
  {
    UINTN FlushLength = (UINTN)mFbGeometry.PitchBytes * (UINTN)mFbGeometry.Height;

    if ((FlushLength == 0) || (FlushLength > (UINTN)FbLength)) {
      FlushLength = (UINTN)FbLength;
    }

    WriteBackInvalidateDataCacheRange ((VOID *)mFbGeometry.Base, FlushLength);
  }'''
if old2 not in s:
    sys.exit("patch2 anchor not found")
s = s.replace(old2, new2, 1)

open(p, "w", encoding="utf-8").write(s)
print("patched both")
PY

echo "=== 确认 ==="
grep -n "k70u-fix 2026-11-02" "$F" | head -4
