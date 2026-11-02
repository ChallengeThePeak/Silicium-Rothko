#!/usr/bin/env python3
"""
Give the Boot Manager menu something to show.

MsBootOptionsLibRegisterDefaultBootOptions() registers three entries:

    MsBootPolicy   -> "Internal Storage", "USB Storage"
    UFPLoader      -> "FFU Mode"

None of those modules exist in this tree (PcBdsPkg/MsBootPolicy and the UFP
loader are not part of the rothko build), so all three CreateFvBootOption calls
fail with EFI_NOT_FOUND:

    CreateFvBootOption: Failed to Read EFI Application Section from q! Status = Not Found
    RegisterFvBootOption: Failed to Create a New FV Boot Option! Status = Not Found   (x3)

The BootOrder therefore stays empty, BootManagerMenuApp runs with
BootMenuData.ItemCount == 0 and DrawBootPopupMenu paints an empty frame - which
is exactly the "box on screen, pressing Volume Up does nothing" symptom.

The one bootable application this platform really ships is UniXNU
(SiliciumPkg/Applications/UniXNU/UniXNU.inf, FILE_GUID
9B665204-A133-47A2-9396-9E2B370A4E25), and it is already in the FV. Register
that instead, so the menu has a real, selectable entry.
"""
from pathlib import Path
import sys

P = Path("/home/ubuntu/rothko-upstream-20261102/uefi-full/Silicon/Silicium/SiliciumPkg/Library/MsBootOptionsLib/MsBootOptionsLib.c")
t = P.read_text(encoding="utf-8")

if "gK70uUniXNUFileGuid" in t:
    print("already applied")
    sys.exit(0)

old = """  // Register Default Boot Options
  RegisterFvBootOption (&gMsBootPolicyFileGuid,            L"Internal Storage", (UINTN)-1, LOAD_OPTION_ACTIVE, (UINT8 *)"SSD", sizeof ("SSD"));
  RegisterFvBootOption (&gMsBootPolicyFileGuid,            L"USB Storage",      (UINTN)-1, LOAD_OPTION_ACTIVE, (UINT8 *)"USB", sizeof ("USB"));
  RegisterFvBootOption (FixedPcdGetPtr (PcdUfpLoaderFile), L"FFU Mode",         (UINTN)-1, LOAD_OPTION_HIDDEN, NULL, 0);
"""

new = """  //
  // [k70u 2026-11-02] MsBootPolicy and UFPLoader are not part of this build, so
  // the generic defaults below fail (EFI_NOT_FOUND) and leave the Boot Manager
  // menu with zero entries - it then paints an empty frame and Volume Up has
  // nothing to move between. Register the application this platform ships.
  //
  STATIC EFI_GUID gK70uUniXNUFileGuid = {
    0x9B665204, 0xA133, 0x47A2, { 0x93, 0x96, 0x9E, 0x2B, 0x37, 0x0A, 0x4E, 0x25 }
  };

  RegisterFvBootOption (&gK70uUniXNUFileGuid, L"UniXNU", (UINTN)-1, LOAD_OPTION_ACTIVE, NULL, 0);
"""

if old not in t:
    print("ERROR: anchor not found")
    sys.exit(2)

P.write_text(t.replace(old, new, 1), encoding="utf-8")
print("registered UniXNU as the platform boot option")
