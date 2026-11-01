#!/bin/bash
# RothkoDisplayDxe：装 GOP 前清空所有扫描层（含 pitch 填充列），去掉 LK 开机 logo 残留
set -u
export PATH=/home/ubuntu/bin:$PATH
D=/home/ubuntu/rothko-upstream-20261102/uefi-full/Platforms/Xiaomi/rothkoPkg/Drivers/RothkoDisplayDxe
Q=/home/ubuntu/quarantine
cp -f "$D/RothkoDisplayDxe.c" "$Q/RothkoDisplayDxe.c.pre-clear-$(date +%Y%m%d-%H%M%S)"

python3 - "$D/RothkoDisplayDxe.c" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
if "ClearScanoutBuffers" in s:
    print("already patched"); raise SystemExit

# 1) 新增清屏函数（插在 Refresh 之前）
anchor = "Refresh (\n  IN EFI_EVENT  Event,\n  IN VOID       *Context\n  )\n{"
if anchor not in s:
    sys.exit("Refresh anchor missing")

helper = '''/**
  Wipe every scanout layer before the GOP takes over.

  LK leaves its boot logo in the framebuffer we are about to draw into, and the
  console only overwrites the pixels it actually uses. Without this the panel
  shows the LK artwork underneath the UEFI text. Each layer is wiped with its
  own stride, including the padding between the visible width and the stride
  (rothko's fullscreen layer has a 1248 pixel stride for a 1220 pixel panel),
  otherwise a 28 pixel column of stale pixels survives on every row.
**/
STATIC
VOID
ClearScanoutBuffers (
  VOID
  )
{
  UINTN   Index;
  UINTN   Bytes;

  for (Index = 0; Index < mScanoutCount; Index++) {
    Bytes = (UINTN)mScanoutPitch[Index] * PANEL_HEIGHT;

    if ((Bytes == 0) || (Bytes > mFbSize)) {
      Bytes = mFbSize;
    }

    if (!RothkoSpanFits (mFbBase, mFbSize, mScanouts[Index], Bytes)) {
      continue;
    }

    ZeroMem ((VOID *)(UINTN)mScanouts[Index], Bytes);
    WriteBackDataCacheRange ((VOID *)(UINTN)mScanouts[Index], Bytes);
  }

  MemoryFence ();
}

'''

s = s.replace(anchor, helper + anchor, 1)

# 2) 在 ProbeScanouts 之后、InstallGop 之前调用
call_anchor = "  RothkoStage (15);\n  Status = InstallGop (ImageHandle);"
if call_anchor not in s:
    sys.exit("install anchor missing")
s = s.replace(call_anchor,
              "  RothkoStage (15);\n"
              "  //\n"
              "  // [k70u-fix 2026-11-02] Wipe LK's boot logo out of the scanout layers\n"
              "  // before the GOP starts drawing into them.\n"
              "  //\n"
              "  ClearScanoutBuffers ();\n"
              "  Status = InstallGop (ImageHandle);", 1)

open(p, "w", encoding="utf-8").write(s)
print("patched")
PY

rg -n "ClearScanoutBuffers" "$D/RothkoDisplayDxe.c" | head -5
