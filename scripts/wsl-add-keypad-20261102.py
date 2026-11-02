#!/usr/bin/env python3
"""
Add volume-key support to the rothko UEFI build.

Facts established offline (no hardware needed):

  * rothko device tree, DTBO fragment@19 -> /gpio_keys/volup-key
        label = "Volume_Up"
        gpios = <&pio 0xC4 0x1>      -> MTK GPIO 196, GPIO_ACTIVE_LOW
        linux,code = 0x73            -> KEY_VOLUMEUP
    and /fragment@20/__overlay__/key-default/pinkey
        pinmux = <0xc400>            -> pin 0xC4, function 0 (plain GPIO)
        input-enable, bias-pull-up
    So Volume Up is a plain MTK pinctrl GPIO, already configured as an input
    with a pull-up by LK. We only have to read it.

  * /pinctrl@10005000, reg[0] "gpio" = 0x10005000 + 0x1000
        GpioDxe locates its register block by the memory-region name "Pinctrl",
        so the memory map needs that window.

  * MTK GPIO blocks keep the same register layout across MT67xx/MT68xx/MT69xx:
        dir   +0x000 (+0x4 set / +0x8 clear)
        dout  +0x100
        din   +0x200
        mode  +0x300
    MT6789Pkg/Library/GpioImplLib describes exactly this; rothko differs only in
    MaxPin (dt gpio-ranges says 0xFB = 251 pins).

  * Volume Down and Power are MT6363 PMIC keys (/mt6363keys /power and /home).
    Those need the PMIC wrapper + MT6363 register map, which is NOT wired up in
    this tree (MT6358PmicDxe targets MT6358 with a different register map).
    The keypad library therefore treats the PMIC as optional: it is used when a
    PMIC protocol happens to be present and silently skipped otherwise, so a
    missing PMIC can never take the GPIO key down with it.

What this script does:
  1. MemoryMapLib: add {"Pinctrl", 0x10005000, 0x1000} as an MMIO window.
  2. Create rothkoPkg/Library/GpioImplLib (MT6989 platform info).
  3. Create rothkoPkg/Library/KeypadDeviceLib (Volume Up on GPIO 196).
  4. rothko.dsc: [Packages] MediaTekPkg, library mappings, three components.
  5. DXE.inc: the three INFs so they actually land in the FV.
"""
from pathlib import Path
import sys

ROOT = Path("/home/ubuntu/rothko-upstream-20261102/uefi-full")
PKG = ROOT / "Platforms/Xiaomi/rothkoPkg"
MEMMAP = PKG / "Library/MemoryMapLib/MemoryMapLib.c"
DSC = PKG / "rothko.dsc"
DXEINC = PKG / "Include/DXE.inc"


def read(p):
    raw = p.read_bytes()
    crlf = b"\r\n" in raw
    return raw.decode("utf-8", "surrogateescape").replace("\r\n", "\n"), crlf


def write(p, txt, crlf):
    data = txt.replace("\n", "\r\n") if crlf else txt
    p.write_bytes(data.encode("utf-8", "surrogateescape"))


# ------------------------------------------------------------ 1. MemoryMapLib
txt, crlf = read(MEMMAP)
if '"Pinctrl"' in txt:
    print("MemoryMapLib: Pinctrl already present")
else:
    anchor = '  {"GIC Redistributors",0x0C440000, 0x00200000, AddDev, MMAP_IO, UNCACHEABLE, MmIO, NS_DEVICE},\n'
    if anchor not in txt:
        print("ERROR: MemoryMapLib anchor not found")
        sys.exit(2)
    block = anchor + """  //
  // [k70u 2026-11-02] MT6989 pinctrl / GPIO block. Volume Up on rothko is
  // GPIO 196 (0xC4, active low) per the stock DTBO fragment@19 /volup-key,
  // and GpioDxe finds this window by the name "Pinctrl". DT node
  // /pinctrl@10005000, reg[0] "gpio" = 0x10005000 + 0x1000.
  //
  {"Pinctrl", 0x10005000, 0x1000, AddDev, MMAP_IO, UNCACHEABLE, MmIO, NS_DEVICE},
"""
    txt = txt.replace(anchor, block, 1)
    write(MEMMAP, txt, crlf)
    print("MemoryMapLib: added Pinctrl window")

# ------------------------------------------------------------ 2. GpioImplLib
gpio_dir = PKG / "Library/GpioImplLib"
gpio_dir.mkdir(parents=True, exist_ok=True)

(gpio_dir / "GpioImplLib.c").write_text("""/**
  [k70u 2026-11-02] MT6989 GPIO platform description.

  MTK keeps one register layout for the whole GPIO controller generation
  (MT67xx .. MT69xx): direction / data-out / data-in / mode blocks indexed by
  pin number. The MT6789 package uses exactly the same offsets, so only the
  pin count differs: rothko's DT says gpio-ranges = <..., 0xFB> = 251 pins.

  SPDX-License-Identifier: BSD-2-Clause-Patent
**/

#include <Library/GpioImplLib.h>

MTK_GPIO_PLATFORM_INFO gPlatformInfo = {
  .SetOffset     = 0x4,
  .ResetOffset   = 0x8,
  .DirOffset     = 0x0,
  .DataOutOffset = 0x100,
  .DataInOffset  = 0x200,
  .ModeOffset    = 0x300,
  .MaxPin        = 251,
};
""", encoding="utf-8")

(gpio_dir / "GpioImplLib.inf").write_text("""[Defines]
  INF_VERSION                    = 0x00010005
  BASE_NAME                      = GpioImplLib
  FILE_GUID                      = 3F9A6C41-8E27-4D53-A0B9-6C1D4E72F5A8
  MODULE_TYPE                    = BASE
  VERSION_STRING                 = 1.0
  LIBRARY_CLASS                  = GpioImplLib

[Sources]
  GpioImplLib.c

[Packages]
  MdePkg/MdePkg.dec
  MediaTekPkg/MediaTekPkg.dec
  SiliciumPkg/SiliciumPkg.dec
""", encoding="utf-8")
print("created rothkoPkg/Library/GpioImplLib")

# ------------------------------------------------------ 3. KeypadDeviceLib
kp_dir = PKG / "Library/KeypadDeviceLib"
kp_dir.mkdir(parents=True, exist_ok=True)

(kp_dir / "KeypadDeviceLib.c").write_text(r"""/**
  [k70u 2026-11-02] rothko keypad backend.

  Volume Up is a plain MTK pinctrl GPIO (196 / 0xC4, active low, pull-up done by
  LK), so the GPIO protocol alone is enough to register the key that opens the
  Boot Manager menu.

  Volume Down and Power live on the MT6363 PMIC (/mt6363keys /home and /power).
  This tree only ships MT6358PmicDxe, whose register map does not match MT6363,
  so the PMIC path is treated as optional: when no PMIC protocol is present the
  keys are simply not registered and the GPIO key keeps working.

  SPDX-License-Identifier: BSD-2-Clause-Patent
**/

#include <Uefi.h>

#include <Library/BaseMemoryLib.h>
#include <Library/BitmapLib.h>
#include <Library/KeypadDeviceLib.h>
#include <Library/DebugLib.h>

#include <Protocol/MtkGpio.h>
#include <Protocol/MtkPmic.h>

//
// Stock DTBO fragment@19: /volup-key gpios = <&pio 0xC4 0x1>, i.e. GPIO 196
// with GPIO_ACTIVE_LOW.
//
#define ROTHKO_VOLUME_UP_GPIO  196

STATIC MTK_GPIO_PROTOCOL *mGpioProtocol;
STATIC MTK_PMIC_PROTOCOL *mPmicProtocol;

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
        // Repeat after 500 ms, then every 100 ms while held down.
        //
        if (Context->Repeat && Context->Time >= MS2NS (100)) {
          KeypadReturnApi->PushEfikeyBufTail (KeypadReturnApi, &Context->KeyData);
          Context->Time = 0;
        } else if (!Context->Repeat && Context->Time >= MS2NS (500)) {
          KeypadReturnApi->PushEfikeyBufTail (KeypadReturnApi, &Context->KeyData);
          Context->Time   = 0;
          Context->Repeat = TRUE;
        }
      } else {
        //
        // Report a short press on release so a tap is never lost.
        //
        if (!Context->Repeat) {
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

STATIC KEY_CONTEXT_PRIVATE KeyContextVolumeUp;
STATIC KEY_CONTEXT_PRIVATE KeyContextVolumeDown;
STATIC KEY_CONTEXT_PRIVATE KeyContextPower;

STATIC KEY_CONTEXT_PRIVATE *KeyList[] = { &KeyContextVolumeUp, &KeyContextVolumeDown, &KeyContextPower };

RETURN_STATUS
EFIAPI
KeypadDeviceConstructor ()
{
  EFI_STATUS Status;

  KeyContextVolumeUp.Type   = KEY_TYPE_UNKNOWN;
  KeyContextVolumeDown.Type = KEY_TYPE_UNKNOWN;
  KeyContextPower.Type      = KEY_TYPE_UNKNOWN;

  //
  // GPIO is mandatory: it carries Volume Up.
  //
  Status = gBS->LocateProtocol (&gMediaTekGpioProtocolGuid, NULL, (VOID *)&mGpioProtocol);
  if (EFI_ERROR (Status)) {
    DEBUG ((DEBUG_ERROR, "ROTHKO-KEYPAD: no GPIO protocol (%r), keypad disabled\n", Status));
    mGpioProtocol = NULL;
    return RETURN_NOT_FOUND;
  }

  KeyContextVolumeUp.Type = KEY_TYPE_GPIO;
  KeyContextVolumeUp.Pin  = ROTHKO_VOLUME_UP_GPIO;

  //
  // PMIC is optional: it would carry Volume Down and Power, but this tree has
  // no MT6363 driver yet, so a missing protocol is a normal outcome.
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

  DEBUG ((
    DEBUG_ERROR,
    "ROTHKO-KEYPAD: Volume Up = GPIO %u (active low), PMIC keys %a\n",
    ROTHKO_VOLUME_UP_GPIO,
    (mPmicProtocol != NULL) ? "enabled" : "unavailable"
    ));

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
  EFI_STATUS           Status;
  BOOLEAN              IsPressed;
  KEY_CONTEXT_PRIVATE *Context;

  for (UINTN Index = 0; Index < (sizeof (KeyList) / sizeof (KeyList[0])); Index++) {
    Context   = KeyList[Index];
    IsPressed = FALSE;

    if (Context->Type == KEY_TYPE_GPIO) {
      if (mGpioProtocol == NULL) {
        continue;
      }

      Status = mGpioProtocol->GetState (Context->Pin, &IsPressed);
      if (EFI_ERROR (Status)) {
        continue;
      }

      //
      // The DT marks the key GPIO_ACTIVE_LOW, so a pressed key reads as 0.
      //
      IsPressed = !IsPressed;
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
""", encoding="utf-8")

(kp_dir / "KeypadDeviceLib.inf").write_text("""[Defines]
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
  BitmapLib
  DebugLib

[Protocols]
  gMediaTekGpioProtocolGuid
  gMediaTekPmicProtocolGuid
""", encoding="utf-8")
print("created rothkoPkg/Library/KeypadDeviceLib")

# ------------------------------------------------------------------ 4. DSC
txt, crlf = read(DSC)

if "GpioImplLib|rothkoPkg" in txt:
    print("rothko.dsc: already wired")
else:
    # [Packages] section: MediaTekPkg must be visible to the platform
    if "[Packages]" not in txt:
        txt = txt.replace(
            "[LibraryClasses]",
            "[Packages]\n  MediaTekPkg/MediaTekPkg.dec\n\n[LibraryClasses]",
            1,
        )
    else:
        txt = txt.replace(
            "[Packages]\n",
            "[Packages]\n  MediaTekPkg/MediaTekPkg.dec\n",
            1,
        )

    txt = txt.replace(
        "  MemoryMapLib|rothkoPkg/Library/MemoryMapLib/MemoryMapLib.inf\n",
        "  MemoryMapLib|rothkoPkg/Library/MemoryMapLib/MemoryMapLib.inf\n"
        "  GpioImplLib|rothkoPkg/Library/GpioImplLib/GpioImplLib.inf\n"
        "  KeypadDeviceLib|rothkoPkg/Library/KeypadDeviceLib/KeypadDeviceLib.inf\n",
        1,
    )

    comp = """  rothkoPkg/Drivers/RothkoDisplayDxe/RothkoDisplayDxe.inf
"""
    new_comp = """  rothkoPkg/Drivers/RothkoDisplayDxe/RothkoDisplayDxe.inf
  #
  # [k70u 2026-11-02] Volume Up. GpioDxe publishes the MediaTek GPIO protocol
  # (Volume Up = GPIO 196 per the stock DTBO), KeypadDeviceDxe wraps it into the
  # keypad protocol and KeypadDxe turns that into SimpleTextIn/SimpleTextInputEx,
  # which is what BootManagerLib registers the menu hotkey (SCAN_UP) against.
  #
  MediaTekPkg/Drivers/GpioDxe/GpioDxe.inf
  SiliciumPkg/Drivers/KeypadDeviceDxe/KeypadDeviceDxe.inf
  SiliciumPkg/Drivers/KeypadDxe/KeypadDxe.inf
"""
    if comp not in txt:
        print("ERROR: rothko.dsc component anchor not found")
        sys.exit(2)
    txt = txt.replace(comp, new_comp, 1)

    write(DSC, txt, crlf)
    print("rothko.dsc: wired MediaTekPkg, GpioImplLib, KeypadDeviceLib, 3 components")

# --------------------------------------------------------------- 5. DXE.inc
txt, crlf = read(DXEINC)
if "GpioDxe.inf" in txt:
    print("DXE.inc: already lists the drivers")
else:
    anchor = "INF MdeModulePkg/Universal/SetupBrowserDxe/SetupBrowserDxe.inf\n"
    if anchor not in txt:
        print("ERROR: DXE.inc anchor not found")
        sys.exit(2)
    txt = txt.replace(anchor, anchor + """#
# [k70u 2026-11-02] Keys: GPIO -> keypad protocol -> SimpleTextInputEx.
# Volume Up (GPIO 196) is what opens the Boot Manager menu.
#
INF MediaTekPkg/Drivers/GpioDxe/GpioDxe.inf
INF SiliciumPkg/Drivers/KeypadDeviceDxe/KeypadDeviceDxe.inf
INF SiliciumPkg/Drivers/KeypadDxe/KeypadDxe.inf
""", 1)
    write(DXEINC, txt, crlf)
    print("DXE.inc: added 3 INF entries")

print("done")
