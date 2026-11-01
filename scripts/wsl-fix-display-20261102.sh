#!/bin/bash
# 修好显示：alpha 不透明 + stride 正确 + 发布真实几何
set -u
export PATH=/home/ubuntu/bin:$PATH
U=/home/ubuntu/rothko-upstream-20261102/uefi-full
LIB="$U/Silicon/Silicium/SiliciumPkg/Library/FrameBufferSerialPortLib/FrameBufferSerialPortLib.c"
DRV="$U/Platforms/Xiaomi/rothkoPkg/Drivers/RothkoDisplayDxe/RothkoDisplayDxe.c"
SEC="$U/Silicon/Silicium/SiliciumPkg/Library/MemoryInitPeiLib/MemoryInitPei.c"
Q=/home/ubuntu/quarantine
for f in "$LIB" "$DRV" "$SEC"; do cp -f "$f" "$Q/$(basename $f).pre-fbfix-$(date +%Y%m%d-%H%M%S)"; done

python3 - "$LIB" "$DRV" "$SEC" <<'PY'
import re, sys
lib, drv, sec = sys.argv[1], sys.argv[2], sys.argv[3]

# ============ 1) FrameBufferSerialPortLib ============
s = open(lib, encoding="utf-8").read()

# 1a) 背景像素必须不透明：LK 的 OVL 是 RGBA 合成，alpha=0 等于透明
old = "UINT32 PixelColor = (Data & 1) ? 0xFFFFFFFF : 0x00000000;"
new = ("//\n"
       "      // [k70u-fix 2026-11-02] LK leaves an RGBA overlay scanning the panel, so a\n"
       "      // zero reserved byte means fully transparent and LK's own splash shows\n"
       "      // through. Keep the background opaque, like the yunluo reference does.\n"
       "      UINT32 PixelColor = (Data & 1) ? 0xFFFFFFFF : 0xFF000000;")
if old in s:
    s = s.replace(old, new, 1); print("lib: background alpha fixed")
else:
    print("lib: background pattern not found")

# 1b) 清屏：按行距逐行写不透明黑，而不是按宽度 ZeroMem
helper = '''
/**
  Wipe the visible area with opaque black.

  Two mistakes are fixed here. The old code cleared Width * Height bytes
  contiguously, but the panel strides 1248 pixels per line for a 1220 pixel
  panel, so a contiguous clear wipes the wrong pixels. And a plain zero fill
  leaves the reserved byte at zero, which the inherited RGBA overlay treats as
  fully transparent, so LK's splash would show through the "cleared" screen.
**/
STATIC
VOID
ClearFrameBufferOpaque (
  VOID
  )
{
  UINTN   Row;
  UINTN   Col;
  UINT32  *Pixels;

  if ((mFbGeometry.Width == 0) || (mFbGeometry.Height == 0) ||
      (mFbGeometry.PitchBytes < mFbGeometry.Width * FB_BPP))
  {
    return;
  }

  Pixels = (UINT32 *)(VOID *)mFbGeometry.Base;

  for (Row = 0; Row < mFbGeometry.Height; Row++) {
    for (Col = 0; Col < mFbGeometry.Width; Col++) {
      Pixels[Col] = 0xFF000000U;
    }

    Pixels += mFbGeometry.PitchBytes / sizeof (UINT32);
  }

  WriteBackDataCacheRange (
    (VOID *)mFbGeometry.Base,
    (UINTN)mFbGeometry.PitchBytes * mFbGeometry.Height
    );
}

'''

anchor = "VOID\nEFIAPI\nPstoreLogBegin ("
if anchor in s and "ClearFrameBufferOpaque" not in s:
    s = s.replace(anchor, helper + anchor, 1)
    print("lib: clear helper added")

# 1c) 两处 ZeroMem 清屏换成不透明清屏
s = s.replace("ZeroMem ((VOID *)FbBase, FB_WIDTH * FB_HEIGHT * FB_BPP);",
              "ClearFrameBufferOpaque ();")
s = s.replace("ZeroMem ((VOID *)mFbGeometry.Base, (UINTN)FB_PITCH * FB_HEIGHT);",
              "ClearFrameBufferOpaque ();")
open(lib, "w", encoding="utf-8").write(s)

# ============ 2) RothkoDisplayDxe ============
d = open(drv, encoding="utf-8").read()

# 2a) GOP blt 之后强制不透明
blt_anchor = """             Delta
             );

  if (!EFI_ERROR (Status) && (BltOperation != EfiBltVideoToBltBuffer) &&"""
blt_new = """             Delta
             );

  //
  // [k70u-fix 2026-11-02] GOP has no alpha contract, but LK's inherited overlay
  // is an RGBA blend: a zero reserved byte is fully transparent and whatever LK
  // left in the frame buffer shows through instead of the console text. Force
  // the scanout opaque, the same way the yunluo reference does.
  //
  if (!EFI_ERROR (Status) && (BltOperation != EfiBltVideoToBltBuffer) &&
      (Width != 0) && (Height != 0))
  {
    UINTN   Row;
    UINTN   Col;
    UINT32  *Pixels;

    for (Row = 0; Row < Height; Row++) {
      Pixels = (UINT32 *)(VOID *)(UINTN)(mMode.FrameBufferBase +
               (UINT64)(DestinationY + Row) * mInfo.PixelsPerScanLine +
               (UINT64)DestinationX);

      for (Col = 0; Col < Width; Col++) {
        Pixels[Col] |= 0xFF000000U;
      }
    }
  }

  if (!EFI_ERROR (Status) && (BltOperation != EfiBltVideoToBltBuffer) &&"""
if blt_anchor in d and "Force the scanout opaque" not in d:
    d = d.replace(blt_anchor, blt_new, 1); print("drv: blt alpha fixed")
else:
    print("drv: blt anchor not found / already done")

# 2b) 发布真实几何给帧缓冲控制台
if "#include <Library/FrameBufferHandoff.h>" not in d:
    d = d.replace("#include <Library/MemoryMapHelperLib.h>",
                  "#include <Library/MemoryMapHelperLib.h>\n#include <Library/FrameBufferHandoff.h>", 1)

pub_anchor = '  DEBUG ((DEBUG_WARN, "ROTHKO: %u validated scanout layer(s)\\n", mScanoutCount));'
pub_new = pub_anchor + '''

  //
  // [k70u-fix 2026-11-02] Publish the geometry that is really scanned out.
  // The frame buffer console reads this record on every write and otherwise
  // falls back to Width * BPP (4880), while the panel strides 4992 bytes, so
  // every line would drift 28 pixels and the text would come out skewed.
  //
  if (mScanoutCount != 0)
  {
    FB_HANDOFF  *Handoff;

    Handoff = (FB_HANDOFF *)(UINTN)(mFbBase + mFbSize - FB_HANDOFF_OFFSET);
    Handoff->Width      = PANEL_WIDTH;
    Handoff->Height     = PANEL_HEIGHT;
    Handoff->PitchBytes = mScanoutPitch[0];
    Handoff->Base       = mFbBase;
    Handoff->Magic      = FB_HANDOFF_MAGIC;
    MemoryFence ();

    DEBUG ((
      DEBUG_WARN,
      "ROTHKO: published framebuffer geometry %ux%u pitch=%u base=%lx\\n",
      PANEL_WIDTH, PANEL_HEIGHT, mScanoutPitch[0], mFbBase
      ));
  }'''
if pub_anchor in d and "published framebuffer geometry" not in d:
    d = d.replace(pub_anchor, pub_new, 1); print("drv: handoff published")
else:
    print("drv: publish anchor not found / already done")
open(drv, "w", encoding="utf-8").write(d)

# ============ 3) SEC 早期发布几何 ============
c = open(sec, encoding="utf-8").read()
if "#include <Library/FrameBufferHandoff.h>" not in c:
    c = c.replace("#include <Library/DebugLib.h>",
                  "#include <Library/DebugLib.h>\n#include <Library/FrameBufferHandoff.h>\n#include <Library/MemoryMapHelperLib.h>\n#include <Library/PcdLib.h>", 1)

sec_anchor = '  DEBUG ((EFI_D_WARN, "MMU: enabled\\n"));'
sec_new = sec_anchor + '''

  //
  // [k70u-fix 2026-11-02] Publish the frame buffer geometry before anything is
  // drawn. The console in FrameBufferSerialPortLib reads this record on every
  // write; until it exists it falls back to Width * BPP (4880) while the panel
  // strides 4992, so every line drifts 28 pixels and the early log comes out
  // skewed.
  //
  {
    EFI_MEMORY_REGION_DESCRIPTOR  FbRegion;
    FB_HANDOFF                    *Handoff;

    if (EFI_ERROR (LocateMemoryRegionByName ("Display Reserved", &FbRegion)) &&
        EFI_ERROR (LocateMemoryRegionByName ("Display_Reserved", &FbRegion)))
    {
      FbRegion.Address = 0;
      FbRegion.Length  = 0;
    }

    if ((FbRegion.Address != 0) && (FbRegion.Length > FB_HANDOFF_OFFSET))
    {
      Handoff = (FB_HANDOFF *)(UINTN)(FbRegion.Address + FbRegion.Length - FB_HANDOFF_OFFSET);
      Handoff->Magic      = FB_HANDOFF_MAGIC;
      Handoff->Width      = FixedPcdGet32 (PcdFrameBufferWidth);
      Handoff->Height     = FixedPcdGet32 (PcdFrameBufferHeight);
      Handoff->PitchBytes = FixedPcdGet32 (PcdFrameBufferStride) * sizeof (UINT32);
      Handoff->Base       = FbRegion.Address;
      MemoryFence ();
    }
  }'''
if sec_anchor in c and "Publish the frame buffer geometry before" not in c:
    c = c.replace(sec_anchor, sec_new, 1); print("sec: handoff published")
else:
    print("sec: anchor not found / already done")
open(sec, "w", encoding="utf-8").write(c)
PY

echo
echo "=== 校验 ==="
rg -n "0xFF000000|ClearFrameBufferOpaque|published framebuffer geometry|Publish the frame buffer geometry" "$LIB" "$DRV" "$SEC" | head -12
