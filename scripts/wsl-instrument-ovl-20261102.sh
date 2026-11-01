#!/bin/bash
# 给 RothkoDisplayDxe 加“否决原因码”打印（LayerIsLinear / CollectScanout）
set -u
export PATH=/home/ubuntu/bin:$PATH
D=/home/ubuntu/rothko-upstream-20261102/uefi-full/Platforms/Xiaomi/rothkoPkg/Drivers/RothkoDisplayDxe
Q=/home/ubuntu/quarantine
cp -f "$D/RothkoDisplayDxe.c" "$Q/RothkoDisplayDxe.c.pre-reason-$(date +%Y%m%d-%H%M%S)"

python3 - "$D/RothkoDisplayDxe.c" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
if "ROTHKO: LIN L%u reason=" in s:
    print("already instrumented"); raise SystemExit

# ---------- 1) LayerIsLinear：改成原因位掩码 ----------
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
  // [k70u-debug 2026-11-02] The original code rejected the layer in one go,
  // which hides the reason. Report a reason bitmask and the raw registers so
  // the MT6989 (rothko) semantics can be compared against the dali (MT6991)
  // assumptions this driver was written for.
  //
  {
    UINT32  Reason;
    UINT32  SrcSize;
    UINT32  Offset;
    UINT32  Clip;
    UINT32  DpCon;
    UINT32  DpExt;
    UINT32  ClrFmt;

    SrcSize = MmioRead32 (Base + OVL_SRC_SIZE (Layer));
    Offset  = MmioRead32 (Base + OVL_OFFSET (Layer));
    Clip    = MmioRead32 (Base + OVL_CLIP (Layer));
    DpCon   = MmioRead32 (Base + OVL_DATAPATH_CON);
    DpExt   = MmioRead32 (Base + OVL_DATAPATH_EXT);
    ClrFmt  = MmioRead32 (Base + OVL_CLRFMT_EXT);

    Reason = 0;
    if ((Con & L_CON_CFMT_MASK) != L_CON_CFMT_RGBA) {
      Reason |= 0x0001;
    }
    if ((Con & ~Allowed) != 0) {
      Reason |= 0x0002;
    }
    if (((Con & BIT8) != 0) && ((Con & 0xFFU) != 0xFFU)) {
      Reason |= 0x0004;
    }
    if ((PitchMsb & (BIT16 | BIT20)) != 0) {
      Reason |= 0x0008;
    }
    if ((Rdma & BIT0) == 0) {
      Reason |= 0x0010;
    }
    if ((Rdma & BIT4) != 0) {
      Reason |= 0x0020;
    }
    if (SrcSize != (PANEL_WIDTH | (PANEL_HEIGHT << 16))) {
      Reason |= 0x0040;
    }
    if (Offset != 0) {
      Reason |= 0x0080;
    }
    if (Clip != 0) {
      Reason |= 0x0100;
    }
    if ((DpCon & (1U << (Layer + 4))) != 0) {
      Reason |= 0x0200;
    }
    if ((DpExt & 7U) != 0) {
      Reason |= 0x0400;
    }
    if (((ClrFmt >> (Layer * 4)) & 3U) != 0) {
      Reason |= 0x0800;
    }

    DEBUG ((
      DEBUG_WARN,
      "ROTHKO: LIN L%u reason=%08x con=%08x pitchmsb=%08x rdma=%08x size=%08x off=%08x clip=%08x dpcon=%08x dpext=%08x clrfmt=%08x\\n",
      Layer, Reason, Con, PitchMsb, Rdma, SrcSize, Offset, Clip, DpCon, DpExt, ClrFmt
      ));

    if (Reason != 0) {
      return FALSE;
    }
  }

  return TRUE;'''
s = s[:m.start()] + new + s[m.end():]

# ---------- 2) CollectScanout：打印输入，便于人工判定 ----------
old2 = """  if (Address == 0) {
    return FALSE;
  }"""
new2 = """  //
  // [k70u-debug 2026-11-02] Print the inputs so the failing condition is
  // visible in the log instead of being inferred.
  //
  DEBUG ((
    DEBUG_WARN,
    "ROTHKO: CS addr=%lx pitch=%u con=%08x size=%08x fb=%lx fbsz=%lx\\n",
    Address, PitchBytes, Con, Size, mFbBase, mFbSize
    ));

  if (Address == 0) {
    return FALSE;
  }"""
if old2 not in s:
    sys.exit("CollectScanout anchor missing")
s = s.replace(old2, new2, 1)

open(p, "w", encoding="utf-8").write(s)
print("instrumented")
PY

rg -n "ROTHKO: LIN L%u reason|ROTHKO: CS addr" "$D/RothkoDisplayDxe.c" | head -4
