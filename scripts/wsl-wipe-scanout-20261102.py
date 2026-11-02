#!/usr/bin/env python3
"""
Wipe the scanout layers once the real OVL pitch is known.

Everything drawn into the frame buffer before RothkoDisplayDxe publishes the
geometry handoff used PitchBytes = Width * 4 = 4880, because the handoff record
did not exist yet. The panel actually scans 4992 bytes per row, so every one of
those early rows (the SEC/DXE log lines at the top of the screen) landed 112
bytes further left than it should, and the error compounded line by line. That
leaves patches of whatever LK had on screen - its green boot splash - visible
between the freshly written rows.

The driver only learns the true pitch after probing the OVL layers, so clear the
layers right there: after the handoff is published and before the GOP is
installed. From that point on every writer (GOP console, frame buffer logger)
sees the correct pitch, so the panel starts from a known state.
"""
from pathlib import Path
import sys

P = Path("/home/ubuntu/rothko-upstream-20261102/uefi-full/Platforms/Xiaomi/rothkoPkg/Drivers/RothkoDisplayDxe/RothkoDisplayDxe.c")
t = P.read_text(encoding="utf-8")

if "Wipe every scanout layer" in t:
    print("already applied")
    sys.exit(0)

# Make sure SetMem32 is available.
if "Library/BaseMemoryLib.h" not in t:
    print("ERROR: BaseMemoryLib.h not included")
    sys.exit(2)

anchor = """      "ROTHKO: published framebuffer geometry %ux%u pitch=%u base=%lx\\n",
      PANEL_WIDTH, PANEL_HEIGHT, mScanoutPitch[0], mFbBase
      ));
  }
"""

insert = """      "ROTHKO: published framebuffer geometry %ux%u pitch=%u base=%lx\\n",
      PANEL_WIDTH, PANEL_HEIGHT, mScanoutPitch[0], mFbBase
      ));

    //
    // [k70u 2026-11-02] Wipe every scanout layer with the pitch the OVL really
    // scans. Everything drawn so far went through PitchBytes = Width * 4
    // (4880) because the handoff record above did not exist yet, and the panel
    // scans mScanoutPitch[0] (4992) - so those rows drifted 112 bytes further
    // left each line and left patches of LK's green boot splash showing between
    // them. Clearing here, now that the true pitch is known, gives the panel a
    // known starting state.
    //
    for (UINTN Layer = 0; Layer < mScanoutCount; Layer++) {
      UINT8 *LayerBase  = (UINT8 *)(UINTN)mScanouts[Layer];
      UINTN  LayerPitch = mScanoutPitch[Layer];

      for (UINTN Row = 0; Row < PANEL_HEIGHT; Row++) {
        SetMem32 (LayerBase + Row * LayerPitch, PANEL_WIDTH * sizeof (UINT32), 0xFF000000U);
      }

      WriteBackDataCacheRange (LayerBase, LayerPitch * PANEL_HEIGHT);
    }

    DEBUG ((
      DEBUG_WARN,
      "ROTHKO: cleared %u scanout layer(s) with the real pitch\\n",
      mScanoutCount
      ));
  }
"""

if anchor not in t:
    print("ERROR: anchor not found")
    sys.exit(2)

P.write_text(t.replace(anchor, insert, 1), encoding="utf-8")
print("inserted scanout wipe")
