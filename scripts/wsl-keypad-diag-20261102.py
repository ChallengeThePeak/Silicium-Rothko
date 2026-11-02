#!/usr/bin/env python3
"""
One-shot diagnostics for the next flash.

Nothing here changes behaviour, it only explains what is happening:

  * BootManager.c logs whether RegisterKeyCallback() succeeded and what
    EnterBootManager() reported. Right now the log is silent about both, so we
    cannot tell "notify never registered" from "notify registered but the GPIO
    never changed".
  * KeypadDeviceLib samples both candidate data-in registers every ~2 s for the
    first ~20 s and prints them, so one boot tells us which layout is live and
    what the pin actually reads while the key is held.
"""
from pathlib import Path
import sys

ROOT = Path("/home/ubuntu/rothko-upstream-20261102/uefi-full")
BM = ROOT / "Silicon/Silicium/SiliciumPkg/Library/BootManagerLib/BootManager.c"
LIB = ROOT / "Platforms/Xiaomi/rothkoPkg/Library/KeypadDeviceLib/KeypadDeviceLib.c"


def sub(path, old, new, why):
    t = path.read_text(encoding="utf-8")
    if new.split("\n")[0] in t and old not in t:
        print(f"skip (already applied): {why}")
        return
    if old not in t:
        print(f"ERROR: anchor not found: {why}")
        sys.exit(2)
    path.write_text(t.replace(old, new, 1), encoding="utf-8")
    print(f"ok: {why}")


# --- BootManager.c: report the key callback result --------------------------
sub(
    BM,
    """  Status = RegisterKeyCallback ((EFI_DEVICE_PATH_PROTOCOL *)&KeypadDevicePath);
  if (!EFI_ERROR (Status) && GopProtocol != NULL) {""",
    """  Status = RegisterKeyCallback ((EFI_DEVICE_PATH_PROTOCOL *)&KeypadDevicePath);
  DEBUG ((DEBUG_ERROR, "K70U-BDS: RegisterKeyCallback -> %r\\n", Status));
  if (!EFI_ERROR (Status) && GopProtocol != NULL) {""",
    "log RegisterKeyCallback result",
)

sub(
    BM,
    """  // Get Boot Manager Flag
  BootManagerFlag = EnterBootManager ();
  if (BootManagerFlag == FALSE) {""",
    """  // Get Boot Manager Flag
  BootManagerFlag = EnterBootManager ();
  DEBUG ((DEBUG_ERROR, "K70U-BDS: EnterBootManager = %u\\n", BootManagerFlag));
  if (BootManagerFlag == FALSE) {""",
    "log EnterBootManager result",
)

# --- KeypadDeviceLib: periodic register sampling ---------------------------
sub(
    LIB,
    "STATIC UINT32                       mIdleLevel[LAYOUT_COUNT];",
    "STATIC UINT32                       mIdleLevel[LAYOUT_COUNT];\nSTATIC UINT32                       mSampleTick;\nSTATIC UINT32                       mSamplePrinted;",
    "sampler state",
)

sub(
    LIB,
    """  for (Index = 0; Index < (sizeof (KeyList) / sizeof (KeyList[0])); Index++) {
    Context   = KeyList[Index];
    IsPressed = FALSE;
""",
    """  //
  // [k70u 2026-11-02] One-shot diagnostic: sample both candidate data-in
  // registers every ~2 s (100 polls at 20 ms) for the first ~20 s, so a single
  // flash tells us which layout is live and what the pin reads when pressed.
  // This disappears on its own after 10 samples.
  //
  mSampleTick++;
  if ((mSamplePrinted < 10) && ((mSampleTick % 100) == 0)) {
    UINT32 SampleA = MmioRead32 (mPinctrlRegion.Address + mDinOffset[0] + PIN_WORD (ROTHKO_VOLUME_UP_GPIO));
    UINT32 SampleB = MmioRead32 (mPinctrlRegion.Address + mDinOffset[1] + PIN_WORD (ROTHKO_VOLUME_UP_GPIO));

    DEBUG ((
      DEBUG_ERROR,
      "ROTHKO-KEYPAD: probe A(0x600)=0x%08x bit%u=%u  B(0x200)=0x%08x bit%u=%u  locked=%d\\n",
      SampleA,
      PIN_BIT (ROTHKO_VOLUME_UP_GPIO),
      (SampleA >> PIN_BIT (ROTHKO_VOLUME_UP_GPIO)) & 1,
      SampleB,
      PIN_BIT (ROTHKO_VOLUME_UP_GPIO),
      (SampleB >> PIN_BIT (ROTHKO_VOLUME_UP_GPIO)) & 1,
      mLockedLayout
      ));
    mSamplePrinted++;
  }

  for (Index = 0; Index < (sizeof (KeyList) / sizeof (KeyList[0])); Index++) {
    Context   = KeyList[Index];
    IsPressed = FALSE;
""",
    "periodic register sampling",
)

print("done")
