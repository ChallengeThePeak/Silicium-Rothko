#!/usr/bin/env python3
"""
Enable L_CON_BTSW on every scanned OVL layer.

Evidence for the fix (offline, no hardware guesswork):

  work/mtkfb.txt, the vendor DRM log on THIS panel:
      mtk_ovl_layer_config OVL0_2L idx:0 fmt:0x34324258(XB24) con:0x10021ff offset:0x0

  0x10021ff has BIT24 set. Our driver reads what LK left behind: con=0x000021FF,
  where BIT24 is clear.

  BIT24 is L_CON_BTSW (the driver already defines it at line 154 and even records
  it into mScanoutByteSwap, but never used it for anything).

EDK2 hands out EFI_GRAPHICS_OUTPUT_BLT_PIXEL, whose byte order is
Blue, Green, Red, Reserved. Without BTSW the OVL interprets the layer as
R, G, B, A, so red and blue swap - which is exactly the magenta / blue / green
mess on screen while the geometry, text and menu are all correct.

Linux programs BTSW=1 for this panel, so the hardware path both LK and Linux use
has it on. Turn it on before the layer is collected, so mScanoutByteSwap records
the truth as well.
"""
from pathlib import Path
import sys

P = Path("/home/ubuntu/rothko-upstream-20261102/uefi-full/Platforms/Xiaomi/rothkoPkg/Drivers/RothkoDisplayDxe/RothkoDisplayDxe.c")
t = P.read_text(encoding="utf-8")

if "Enable byte swap on every scanned layer" in t:
    print("already applied")
    sys.exit(0)

old = """        CollectScanout (
          Address,
          Pitch,
          MmioRead32 (Base + OVL_CON (Layer)),
          MmioRead32 (Base + OVL_SRC_SIZE (Layer))
          );
"""

new = """        //
        // [k70u 2026-11-02] Turn on L_CON_BTSW for every scanned layer.
        //
        // EDK2 writes EFI_GRAPHICS_OUTPUT_BLT_PIXEL: Blue, Green, Red,
        // Reserved. Without BTSW the OVL reads the layer as R, G, B, A, so red
        // and blue swap and the screen turns magenta / blue / green even though
        // the layout and text are correct.
        //
        // The vendor driver programs con = 0x10021ff for this exact panel
        // (work/mtkfb.txt, mtk_ovl_layer_config OVL0_2L), and 0x1000000 is
        // L_CON_BTSW - so the hardware path LK and Linux both use has it on.
        // LK left it off in the handoff we inherited.
        //
        MmioWrite32 (
          Base + OVL_CON (Layer),
          MmioRead32 (Base + OVL_CON (Layer)) | L_CON_BTSW
          );
        MemoryFence ();

        DEBUG ((
          DEBUG_WARN,
          "ROTHKO: OVL %x L%u con byte-swap enabled -> %08x\\n",
          Base, Layer, MmioRead32 (Base + OVL_CON (Layer))
          ));

        CollectScanout (
          Address,
          Pitch,
          MmioRead32 (Base + OVL_CON (Layer)),
          MmioRead32 (Base + OVL_SRC_SIZE (Layer))
          );
"""

if old not in t:
    print("ERROR: CollectScanout anchor not found")
    sys.exit(2)

t = t.replace(old, new, 1)
P.write_text(t, encoding="utf-8")
print("BTSW enabled on scanned layers")
