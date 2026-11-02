#!/usr/bin/env python3
"""
Two real bugs, both found in source, no hardware guessing.

BUG 1 (the one that draws green/colour garbage at the TOP of the screen):
    RothkoDisplayDxe.c, the alpha post-pass in Blt():

        Pixels = (UINT32 *)(VOID *)(UINTN)(mMode.FrameBufferBase +
                 (UINT64)(DestinationY + Row) * mInfo.PixelsPerScanLine +
                 (UINT64)DestinationX);

    FrameBufferBase is a BYTE address and Pixels is a UINT32*, so the offset
    must be scaled by sizeof(UINT32). As written it advances
    PixelsPerScanLine bytes per row instead of PixelsPerScanLine * 4, i.e. the
    whole pass lands at a quarter of the intended height. Every Blt therefore
    scribbles over the upper quarter of the panel - "a broken green strip at the
    top" - and also overwrites alpha bytes of unrelated pixels.

    The cache flush right below it gets this right
    (Pitch = PixelsPerScanLine * sizeof (UINT32)), which is what makes the
    mistake obvious.

BUG 2 (BTSW): the previous build set L_CON_BTSW on every layer on the theory
    that red and blue were swapped. But the alpha post-pass deliberately forces
    the TOP byte to 0xFF, and BTSW reverses the whole 32-bit word, which would
    move that 0xFF into the red channel (0xFF000000 -> 0x000000FF = red and
    fully transparent). Undo it; menus are black/white/grey, where R/B order
    does not matter.
"""
from pathlib import Path
import sys

P = Path("/home/ubuntu/rothko-upstream-20261102/uefi-full/Platforms/Xiaomi/rothkoPkg/Drivers/RothkoDisplayDxe/RothkoDisplayDxe.c")
t = P.read_text(encoding="utf-8")


def sub(old, new, why, optional=False):
    global t
    if old not in t:
        if optional:
            print(f"skip: {why}")
            return
        print(f"ERROR: anchor not found: {why}")
        sys.exit(2)
    t = t.replace(old, new, 1)
    print(f"ok: {why}")


# ---- BUG 1: scale the alpha post-pass offset by the pixel size -------------
sub(
    """      Pixels = (UINT32 *)(VOID *)(UINTN)(mMode.FrameBufferBase +
               (UINT64)(DestinationY + Row) * mInfo.PixelsPerScanLine +
               (UINT64)DestinationX);
""",
    """      //
      // [k70u 2026-11-02] FrameBufferBase is a byte address and Pixels is a
      // UINT32*, so both the row stride and the column offset must be scaled by
      // sizeof (UINT32). Without that the whole pass lands at a quarter of the
      // intended height and scribbles over the upper part of the panel - which
      // is exactly the broken coloured strip seen at the top of the screen.
      //
      Pixels = (UINT32 *)(VOID *)(UINTN)(mMode.FrameBufferBase +
               (UINT64)(DestinationY + Row) * mInfo.PixelsPerScanLine * sizeof (UINT32) +
               (UINT64)DestinationX * sizeof (UINT32));
""",
    "alpha post-pass address scaling",
)

# ---- BUG 2: revert BTSW ---------------------------------------------------
sub(
    """        //
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

""",
    """        //
        // [k70u 2026-11-02] L_CON_BTSW deliberately NOT enabled.
        //
        // The Blt alpha post-pass forces the top byte to 0xFF. BTSW reverses the
        // entire 32-bit word, which would move that 0xFF into the red channel
        // (0xFF000000 -> 0x000000FF = red and fully transparent). Red/blue order
        // is irrelevant for the boot menu, which is black/white/grey, so leave
        // the LK setting alone.
        //
""",
    "revert BTSW",
)

P.write_text(t, encoding="utf-8")
print("done")
