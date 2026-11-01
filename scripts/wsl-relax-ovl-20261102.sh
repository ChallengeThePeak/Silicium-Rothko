#!/bin/bash
# RothkoDisplayDxe：把 dali(MT6991) 专属的图层检查在 rothko(MT6989) 上降级为告警
set -u
export PATH=/home/ubuntu/bin:$PATH
D=/home/ubuntu/rothko-upstream-20261102/uefi-full/Platforms/Xiaomi/rothkoPkg/Drivers/RothkoDisplayDxe
Q=/home/ubuntu/quarantine
cp -f "$D/RothkoDisplayDxe.c" "$Q/RothkoDisplayDxe.c.pre-relax-$(date +%Y%m%d-%H%M%S)"

python3 - "$D/RothkoDisplayDxe.c" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
if "ROTHKO: LIN L%u soft=" in s:
    print("already relaxed"); raise SystemExit

pat = re.compile(
    r"  Con      = MmioRead32 \(Base \+ OVL_CON \(Layer\)\);.*?\n  \}\n\n  return TRUE;",
    re.S)
m = pat.search(s)
if not m:
    sys.exit("LayerIsLinear block not found")

new = '''  Con      = MmioRead32 (Base + OVL_CON (Layer));
  PitchMsb = MmioRead32 (Base + OVL_PITCH_MSB (Layer));
  Rdma     = MmioRead32 (Base + OVL_RDMA_CTRL (Layer));
  Allowed  = L_CON_CFMT_RGBA | L_CON_BTSW | BIT8 | 0xFFU;

  //
  // [k70u-fix 2026-11-02] This driver was written against dali (MT6991) and has
  // never run on rothko (MT6989): the layer was never in the FD, so the dali
  // register rules were never exercised here.
  //
  // Evidence from the stock rothko kernel (work/mtkfb.txt, mtk_ovl_layer_config):
  //   OVL0_2L idx:0 fmt:0x34324258(XB24) addr:0x3ef000000 con:0x10021ff offset:0x0
  //   mtk_plane_atomic_update en1 pitch4992 fmt:XB24 x0 y0 w1220 h2712
  // i.e. the fullscreen scanout layer is a plain linear RGBA layer with the
  // framebuffer address, 1220x2712 and a 4992-byte (1248 px) stride.
  //
  // Only the checks that actually identify the scanout layer stay hard: the
  // colour format, the source size, and (in CollectScanout) the address, the
  // pitch and the containment in the framebuffer carveout. The remaining bits
  // describe how a *composition* is wired, and their encoding differs between
  // the two SoCs, so they are reported instead of vetoing the layer.
  //
  {
    UINT32  SrcSize;
    UINT32  Offset;
    UINT32  Clip;
    UINT32  DpCon;
    UINT32  DpExt;
    UINT32  ClrFmt;
    UINT32  Soft;

    SrcSize = MmioRead32 (Base + OVL_SRC_SIZE (Layer));
    Offset  = MmioRead32 (Base + OVL_OFFSET (Layer));
    Clip    = MmioRead32 (Base + OVL_CLIP (Layer));
    DpCon   = MmioRead32 (Base + OVL_DATAPATH_CON);
    DpExt   = MmioRead32 (Base + OVL_DATAPATH_EXT);
    ClrFmt  = MmioRead32 (Base + OVL_CLRFMT_EXT);

    Soft = 0;
    if ((Con & ~Allowed) != 0) {
      Soft |= 0x0001;
    }
    if (((Con & BIT8) != 0) && ((Con & 0xFFU) != 0xFFU)) {
      Soft |= 0x0002;
    }
    if ((PitchMsb & (BIT16 | BIT20)) != 0) {
      Soft |= 0x0004;
    }
    if ((Rdma & BIT0) == 0) {
      Soft |= 0x0008;
    }
    if ((Rdma & BIT4) != 0) {
      Soft |= 0x0010;
    }
    if (Offset != 0) {
      Soft |= 0x0020;
    }
    if (Clip != 0) {
      Soft |= 0x0040;
    }
    if ((DpCon & (1U << (Layer + 4))) != 0) {
      Soft |= 0x0080;
    }
    if ((DpExt & 7U) != 0) {
      Soft |= 0x0100;
    }
    if (((ClrFmt >> (Layer * 4)) & 3U) != 0) {
      Soft |= 0x0200;
    }

    DEBUG ((
      DEBUG_WARN,
      "ROTHKO: LIN L%u soft=%08x con=%08x pitchmsb=%08x rdma=%08x size=%08x off=%08x clip=%08x dpcon=%08x dpext=%08x clrfmt=%08x\\n",
      Layer, Soft, Con, PitchMsb, Rdma, SrcSize, Offset, Clip, DpCon, DpExt, ClrFmt
      ));

    //
    // Hard gates: the layer must be a linear RGBA layer of exactly the panel
    // size. Everything else is reported, not vetoed.
    //
    if ((Con & L_CON_CFMT_MASK) != L_CON_CFMT_RGBA) {
      DEBUG ((DEBUG_WARN, "ROTHKO: LIN L%u reject: colour format\\n", Layer));
      return FALSE;
    }

    if (SrcSize != (PANEL_WIDTH | (PANEL_HEIGHT << 16))) {
      DEBUG ((DEBUG_WARN, "ROTHKO: LIN L%u reject: source size\\n", Layer));
      return FALSE;
    }
  }

  return TRUE;'''
s = s[:m.start()] + new + s[m.end():]
open(p, "w", encoding="utf-8").write(s)
print("relaxed")
PY

rg -n "ROTHKO: LIN L%u soft=|reject: colour format" "$D/RothkoDisplayDxe.c" | head -4
