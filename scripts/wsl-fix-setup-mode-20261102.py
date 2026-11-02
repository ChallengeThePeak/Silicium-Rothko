#!/usr/bin/env python3
"""
Fix the console mode switch that killed the Boot Manager menu, and give the
user time to press Volume Up.

1) PcdSetupVideoHorizontalResolution / VerticalResolution / PcdSetupConOutColumn /
   PcdSetupConOutRow were never set for rothko, so they are 0.
   BootManagerMenuApp calls BdsSetConsoleMode(TRUE) before drawing the menu;
   that reads those PCDs, looks for a GOP mode of 0x0, finds none, and falls
   into the "resolution changed, restart the whole console driver" path. The
   console gets torn down and the menu ends up drawing into a dead device -
   which is why the screen kept showing the boot splash / empty frame while the
   application was clearly running.

   Panel is 1220x2712, the UEFI glyph is 8x19, so the text mode is 152x142.

2) PcdPlatformBootTimeOut is 3 seconds, which is not enough time to notice the
   "[Volume Up] Boot Manager" line and press. Raise it to 10.
"""
from pathlib import Path
import sys

ROOT = Path("/home/ubuntu/rothko-upstream-20261102/uefi-full")
DSC = ROOT / "Platforms/Xiaomi/rothkoPkg/rothko.dsc"
INC = ROOT / "Silicon/Silicium/SiliciumPkg/SiliciumPkg.dsc.inc"

# ---- 1. setup video / text mode PCDs --------------------------------------
t = DSC.read_text(encoding="utf-8")

if "PcdSetupVideoHorizontalResolution" in t:
    print("dsc: setup resolution already set")
else:
    anchor = "  gSiliciumPkgTokenSpaceGuid.PcdFrameBufferDelay|0\n"
    if anchor not in t:
        print("ERROR: dsc anchor not found")
        sys.exit(2)
    addition = anchor + """  #
  # [k70u 2026-11-02] BootManagerMenuApp calls BdsSetConsoleMode(TRUE) before
  # drawing its menu. With these four PCDs left at 0 it looks for a 0x0 GOP
  # mode, fails, and restarts the whole console stack - the menu then draws into
  # a dead device and the screen never shows it. 1220x2712 at 8x19 glyphs is
  # 152x142 text cells.
  #
  gEfiMdeModulePkgTokenSpaceGuid.PcdSetupVideoHorizontalResolution|1220
  gEfiMdeModulePkgTokenSpaceGuid.PcdSetupVideoVerticalResolution|2712
  gEfiMdeModulePkgTokenSpaceGuid.PcdSetupConOutColumn|152
  gEfiMdeModulePkgTokenSpaceGuid.PcdSetupConOutRow|142
"""
    DSC.write_text(t.replace(anchor, addition, 1), encoding="utf-8")
    print("dsc: setup resolution 1220x2712 / 152x142")

# ---- 2. boot timeout ------------------------------------------------------
t = INC.read_text(encoding="utf-8")

old = "  gEfiMdePkgTokenSpaceGuid.PcdPlatformBootTimeOut|3"
new = "  gEfiMdePkgTokenSpaceGuid.PcdPlatformBootTimeOut|10"
if old in t:
    INC.write_text(t.replace(old, new, 1), encoding="utf-8")
    print("timeout: 3 -> 10 s")
elif new in t:
    print("timeout: already 10")
else:
    print("ERROR: timeout PCD not found")
    sys.exit(2)

print("done")
