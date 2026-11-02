#!/usr/bin/env python3
"""
Make the Volume Up key layout-agnostic.

Problem: the tree only ships one MediaTek GPIO description
(MT6789Pkg/Library/GpioImplLib): dir +0x000, dout +0x100, din +0x200, mode +0x300.
That is NOT what the Linux driver on this device uses. The device runs
`pinctrl_mtk_v2` (dmesg: "10005000.pinctrl: mtk_eint_do_init ...", debugfs node
"10005000.pinctrl-pinctrl_mtk_v2"), whose register block is
    mode 0x000 / dir 0x400 / dout 0x500 / din 0x600.
Neither layout has ever been proven on MT6989, so instead of guessing we read
BOTH candidate data-in registers and lock onto whichever one actually shows the
key pulling low.

Volume Up is pin 196 (0xC4), active low, with an internal pull-up (confirmed on
the device: pinconf-pins shows "pin 196 (GPIO196): input bias pull up (101 ohms),
input enabled" - the only pulled-up pin in the whole table).

So the probe is simple: an idle key reads 1, a pressed key reads 0. The first
layout that reports a 0 while the other does not wins, and is logged once.

Also drops the GpioDxe protocol dependency from the keypad library: reading the
data-in register directly is both simpler and immune to GpioDxe's own layout
assumption.
"""
from pathlib import Path
import sys

ROOT = Path("/home/ubuntu/rothko-upstream-20261102/uefi-full")
LIB = ROOT / "Platforms/Xiaomi/rothkoPkg/Library/KeypadDeviceLib"

C = r"""/**
  [k70u 2026-11-02] rothko keypad backend - direct pinctrl register access.

  Volume Up is MTK GPIO 196 (0xC4), active low, pull-up enabled, on
  /pinctrl@10005000 (stock DTBO fragment@19 /volup-key:
  gpios = <&pio 0xC4 0x1>). Confirmed on the running device: pinconf-pins shows
  "pin 196 (GPIO196): input bias pull up (101 ohms), input enabled", which is the
  only pulled-up pin in the entire table.

  Two register layouts exist for the MediaTek GPIO block and this platform has
  never been validated against either one:

     A) Linux pinctrl-mtk-common-v2 (what this device actually runs,
        debugfs: "10005000.pinctrl-pinctrl_mtk_v2")
             mode 0x000 / dir 0x400 / dout 0x500 / din 0x600
     B) the MT6789Pkg description inherited from the older UEFI tree
             mode 0x300 / dir 0x000 / dout 0x100 / din 0x200

  Instead of assuming, both data-in registers are sampled. An idle key reads 1
  because of the pull-up, a pressed key reads 0. The first layout that reports 0
  is locked in and logged, and stays in effect for the rest of the boot.

  Volume Down and Power are MT6363 PMIC keys (/mt6363keys /home and /power).
  This tree has no MT6363 driver yet, so those are registered only when a PMIC
  protocol happens to be present; a missing PMIC never disables Volume Up.

  SPDX-License-Identifier: BSD-2-Clause-Patent
**/

#include <Uefi.h>

#include <Library/BaseMemoryLib.h>
#include <Library/DebugLib.h>
#include <Library/IoLib.h>
#include <Library/KeypadDeviceLib.h>
#include <Library/MemoryMapHelperLib.h>
#include <Library/UefiBootServicesTableLib.h>

#include <Protocol/MtkPmic.h>

#define ROTHKO_VOLUME_UP_GPIO  196

#define PIN_WORD(pin)  (((pin) / 32) * 0x10)
#define PIN_BIT(pin)   ((pin) % 32)

//
// Candidate data-in offsets, most likely first.
//
#define LAYOUT_COUNT  2

STATIC CONST UINT32 mDinOffset[LAYOUT_COUNT] = { 0x600, 0x200 };
STATIC CONST CHAR8 *mLayoutName[LAYOUT_COUNT] = { "mtk-v2 din@0x600", "legacy din@0x200" };

STATIC EFI_MEMORY_REGION_DESCRIPTOR mPinctrlRegion;
STATIC MTK_PMIC_PROTOCOL           *mPmicProtocol;
STATIC INTN                         mLockedLayout = -1;

typedef enum {
  KEY_TYPE_UNKNOWN,
  KEY_TYPE_GPIO,
  KEY_TYPE_PMIC,
} KEY_TYPE;

typedef struct {
  KEY_CONTEXT EfiKeyContext;
  KEY_TYPE    Type;
  UINT32      Pin;
} KEY_CONTEXT_PRIVATE;

#define MS2NS(ms) (((UINT64)(ms)) * 1000000ULL)

STATIC
inline
VOID
LibKeyInitializeKeyContext (
  KEY_CONTEXT *Context)
{
  ZeroMem (&Context->KeyData, sizeof (Context->KeyData));

  Context->Time      = 0;
  Context->State     = KEYSTATE_RELEASED;
  Context->Repeat    = FALSE;
  Context->Longpress = FALSE;
}

STATIC
inline
VOID
LibKeyUpdateKeyStatus (
  KEY_CONTEXT       *Context,
  KEYPAD_RETURN_API *KeypadReturnApi,
  BOOLEAN            IsPressed,
  UINT64             Delta)
{
  Context->Time += Delta;

  switch (Context->State) {
    case KEYSTATE_RELEASED:
      if (IsPressed) {
        Context->Time  = 0;
        Context->State = KEYSTATE_PRESSED;
      }

      break;

    case KEYSTATE_PRESSED:
      if (IsPressed) {
        //
        // Report on the first poll of a press, then repeat after 500 ms and
        // every 100 ms while the key stays down, so a short tap is never lost
        // but a held key still walks through the menu.
        //
        if (!Context->Repeat && Context->Time >= MS2NS (500)) {
          KeypadReturnApi->PushEfikeyBufTail (KeypadReturnApi, &Context->KeyData);
          Context->Time   = 0;
          Context->Repeat = TRUE;
        } else if (Context->Repeat && Context->Time >= MS2NS (100)) {
          KeypadReturnApi->PushEfikeyBufTail (KeypadReturnApi, &Context->KeyData);
          Context->Time = 0;
        }
      } else {
        if (!Context->Repeat) {
          //
          // Short press: report once on release.
          //
          KeypadReturnApi->PushEfikeyBufTail (KeypadReturnApi, &Context->KeyData);
        }

        Context->Time   = 0;
        Context->Repeat = FALSE;
        Context->State  = KEYSTATE_RELEASED;
      }

      break;

    default:
      Context->State = KEYSTATE_RELEASED;
      break;
  }
}

STATIC
BOOLEAN
ReadPinLevel (
  IN  UINTN  Layout,
  IN  UINT32 Pin)
{
  UINT32 Value;

  Value = MmioRead32 (mPinctrlRegion.Address + mDinOffset[Layout] + PIN_WORD (Pin));

  return ((Value >> PIN_BIT (Pin)) & 1) != 0;
}

STATIC KEY_CONTEXT_PRIVATE KeyContextVolumeUp;
STATIC KEY_CONTEXT_PRIVATE KeyContextVolumeDown;
STATIC KEY_CONTEXT_PRIVATE KeyContextPower;

STATIC KEY_CONTEXT_PRIVATE *KeyList[] = { &KeyContextVolumeUp, &KeyContextVolumeDown, &KeyContextPower };

RETURN_STATUS
EFIAPI
KeypadDeviceConstructor ()
{
  EFI_STATUS Status;
  UINT32     Idle[LAYOUT_COUNT];
  UINTN      Index;

  KeyContextVolumeUp.Type   = KEY_TYPE_UNKNOWN;
  KeyContextVolumeDown.Type = KEY_TYPE_UNKNOWN;
  KeyContextPower.Type      = KEY_TYPE_UNKNOWN;

  Status = LocateMemoryRegionByName ("Pinctrl", &mPinctrlRegion);
  if (EFI_ERROR (Status)) {
    DEBUG ((DEBUG_ERROR, "ROTHKO-KEYPAD: no Pinctrl region (%r), keypad disabled\n", Status));
    return RETURN_NOT_FOUND;
  }

  //
  // Sample both candidate registers so the log shows exactly what this
  // platform returns; an idle (pulled-up) key must read 1.
  //
  for (Index = 0; Index < LAYOUT_COUNT; Index++) {
    Idle[Index] = MmioRead32 (mPinctrlRegion.Address + mDinOffset[Index] + PIN_WORD (ROTHKO_VOLUME_UP_GPIO));
  }

  DEBUG ((
    DEBUG_ERROR,
    "ROTHKO-KEYPAD: pin %u idle din: %a=0x%08x bit%u=%u  %a=0x%08x bit%u=%u\n",
    ROTHKO_VOLUME_UP_GPIO,
    mLayoutName[0],
    Idle[0],
    PIN_BIT (ROTHKO_VOLUME_UP_GPIO),
    (Idle[0] >> PIN_BIT (ROTHKO_VOLUME_UP_GPIO)) & 1,
    mLayoutName[1],
    Idle[1],
    PIN_BIT (ROTHKO_VOLUME_UP_GPIO),
    (Idle[1] >> PIN_BIT (ROTHKO_VOLUME_UP_GPIO)) & 1
    ));

  KeyContextVolumeUp.Type = KEY_TYPE_GPIO;
  KeyContextVolumeUp.Pin  = ROTHKO_VOLUME_UP_GPIO;

  //
  // PMIC keys are optional: no MT6363 driver in this tree yet.
  //
  Status = gBS->LocateProtocol (&gMediaTekPmicProtocolGuid, NULL, (VOID *)&mPmicProtocol);
  if (EFI_ERROR (Status)) {
    mPmicProtocol = NULL;
    DEBUG ((DEBUG_WARN, "ROTHKO-KEYPAD: no PMIC protocol (%r), only Volume Up available\n", Status));
  } else {
    KeyContextVolumeDown.Type = KEY_TYPE_PMIC;
    KeyContextVolumeDown.Pin  = 0;   // MT6363 HOME
    KeyContextPower.Type      = KEY_TYPE_PMIC;
    KeyContextPower.Pin       = 1;   // MT6363 PWRKEY
  }

  return RETURN_SUCCESS;
}

EFI_STATUS
EFIAPI
KeypadDeviceReset (
  KEYPAD_DEVICE_PROTOCOL *This)
{
  LibKeyInitializeKeyContext (&KeyContextVolumeUp.EfiKeyContext);
  KeyContextVolumeUp.EfiKeyContext.KeyData.Key.ScanCode = SCAN_UP;

  LibKeyInitializeKeyContext (&KeyContextVolumeDown.EfiKeyContext);
  KeyContextVolumeDown.EfiKeyContext.KeyData.Key.ScanCode = SCAN_DOWN;

  LibKeyInitializeKeyContext (&KeyContextPower.EfiKeyContext);
  KeyContextPower.EfiKeyContext.KeyData.Key.UnicodeChar = CHAR_CARRIAGE_RETURN;

  return EFI_SUCCESS;
}

EFI_STATUS
KeypadDeviceGetKeys (
  KEYPAD_DEVICE_PROTOCOL *This,
  KEYPAD_RETURN_API      *KeypadReturnApi,
  UINT64                  Delta)
{
  BOOLEAN              IsPressed;
  UINTN                Index;
  KEY_CONTEXT_PRIVATE *Context;

  for (Index = 0; Index < (sizeof (KeyList) / sizeof (KeyList[0])); Index++) {
    Context   = KeyList[Index];
    IsPressed = FALSE;

    if (Context->Type == KEY_TYPE_GPIO) {
      if (mLockedLayout < 0) {
        //
        // Both registers are read until one of them shows the key pulled low.
        // The pull-up guarantees that only the real data-in register can ever
        // report 0 here.
        //
        for (UINTN Candidate = 0; Candidate < LAYOUT_COUNT; Candidate++) {
          if (!ReadPinLevel (Candidate, Context->Pin)) {
            mLockedLayout = (INTN)Candidate;
            DEBUG ((DEBUG_ERROR, "ROTHKO-KEYPAD: locked %a (pin %u read 0)\n", mLayoutName[Candidate], Context->Pin));
            break;
          }
        }

        if (mLockedLayout < 0) {
          //
          // Nothing pressed yet, nothing to report.
          //
          continue;
        }
      }

      //
      // GPIO_ACTIVE_LOW: pressed means the line is pulled to 0.
      //
      IsPressed = !ReadPinLevel ((UINTN)mLockedLayout, Context->Pin);
    } else if (Context->Type == KEY_TYPE_PMIC) {
      if (mPmicProtocol == NULL) {
        continue;
      }

      if (Context->Pin == 0) {
        mPmicProtocol->HomeButtonPressed (&IsPressed);
      } else {
        mPmicProtocol->PowerButtonPressed (&IsPressed);
      }
    } else {
      continue;
    }

    LibKeyUpdateKeyStatus (&Context->EfiKeyContext, KeypadReturnApi, IsPressed, Delta);
  }

  return EFI_SUCCESS;
}
"""

inf = """[Defines]
  INF_VERSION                    = 0x00010005
  BASE_NAME                      = KeypadDeviceLib
  FILE_GUID                      = 7C4B2E19-5A3D-4F82-9B61-2D8E5A0C74B3
  MODULE_TYPE                    = BASE
  VERSION_STRING                 = 1.0
  LIBRARY_CLASS                  = KeypadDeviceLib
  CONSTRUCTOR                    = KeypadDeviceConstructor

[Sources.common]
  KeypadDeviceLib.c

[Packages]
  MdePkg/MdePkg.dec
  MediaTekPkg/MediaTekPkg.dec
  SiliciumPkg/SiliciumPkg.dec

[LibraryClasses]
  BaseMemoryLib
  DebugLib
  IoLib
  MemoryMapHelperLib
  UefiBootServicesTableLib

[Protocols]
  gMediaTekPmicProtocolGuid
"""

(LIB / "KeypadDeviceLib.c").write_text(C, encoding="utf-8")
(LIB / "KeypadDeviceLib.inf").write_text(inf, encoding="utf-8")
print("rewrote KeypadDeviceLib (dual-layout auto lock)")
