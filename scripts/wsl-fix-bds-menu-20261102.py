#!/usr/bin/env python3
"""
Fix BDS so the Boot Manager menu can actually appear.

Root cause: during yesterday's pstore debugging a CpuDeadLoop() was inserted
right after PlatformBootManagerAfterConsole(), i.e. BEFORE the boot option
dispatch loop. BDS therefore never walked the BootOrder, never called
PlatformBootManagerPriorityBoot() (the hotkey hook) and never registered the
Boot Manager Menu. The "no boot option registered" message was an unconditional
debug print and did not describe reality.

Changes:
  1. Remove that premature CpuDeadLoop block from BdsEntry.c.
  2. In the platform hook PlatformBootManagerPriorityBoot(), when no hotkey was
     pressed AND the BootOrder holds no boot option, enter the Boot Manager menu
     anyway. This is what makes the menu show up without a keyboard.
"""
from pathlib import Path
import sys

ROOT = Path("/home/ubuntu/rothko-upstream-20261102/uefi-full")
BDS = ROOT / "Mu_Basecore/MdeModulePkg/Universal/BdsDxe/BdsEntry.c"
BM = ROOT / "Silicon/Silicium/SiliciumPkg/Library/BootManagerLib/BootManager.c"

MARK = "K70U-BDS: no boot option registered"


def read(p):
    raw = p.read_bytes()
    crlf = b"\r\n" in raw
    txt = raw.decode("utf-8", "surrogateescape").replace("\r\n", "\n")
    return txt, crlf


def write(p, txt, crlf):
    data = txt.replace("\n", "\r\n") if crlf else txt
    p.write_bytes(data.encode("utf-8", "surrogateescape"))


# ---------------------------------------------------------------- BdsEntry.c
txt, crlf = read(BDS)

if MARK not in txt:
    print("BdsEntry.c: premature CpuDeadLoop already removed")
else:
    lines = txt.split("\n")
    idx = next(i for i, l in enumerate(lines) if MARK in l)
    # walk up over the comment block that precedes the DEBUG line
    start = idx
    while start > 0 and lines[start - 1].strip() in ("//", "") or (
        start > 0 and lines[start - 1].lstrip().startswith("//")
    ):
        start -= 1
    # walk down to the CpuDeadLoop() that belongs to this block
    end = idx
    while end < len(lines) and "CpuDeadLoop ()" not in lines[end]:
        end += 1
    # also swallow the blank lines right after
    end += 1
    while end < len(lines) and lines[end].strip() == "":
        end += 1
    removed = lines[start:end]
    del lines[start:end]
    txt = "\n".join(lines)
    write(BDS, txt, crlf)
    print(f"BdsEntry.c: removed {len(removed)} lines (premature CpuDeadLoop block)")
    for l in removed:
        print("   -", l[:120])

# ------------------------------------------------------------- BootManager.c
txt, crlf = read(BM)

if "K70U-BDS: BootOrder is empty" in txt:
    print("BootManager.c: menu fallback already present")
else:
    old = """VOID
EFIAPI
PlatformBootManagerPriorityBoot (IN OUT UINT16 **BootNext)
{
  EFI_STATUS                   Status;
  EFI_BOOT_MANAGER_LOAD_OPTION LoadOption;
  BOOLEAN                      BootManagerFlag;

  // Unregister Key Callback
  UnregisterKeyCallback ();

  // Get Boot Manager Flag
  BootManagerFlag = EnterBootManager ();
  if (BootManagerFlag == FALSE) {
    return;
  }
"""
    new = """VOID
EFIAPI
PlatformBootManagerPriorityBoot (IN OUT UINT16 **BootNext)
{
  EFI_STATUS                    Status;
  EFI_BOOT_MANAGER_LOAD_OPTION  LoadOption;
  BOOLEAN                       BootManagerFlag;
  EFI_BOOT_MANAGER_LOAD_OPTION *BootOptions;
  UINTN                         BootOptionCount;

  // Unregister Key Callback
  UnregisterKeyCallback ();

  // Get Boot Manager Flag
  BootManagerFlag = EnterBootManager ();
  if (BootManagerFlag == FALSE) {
    //
    // [k70u 2026-11-02] No hotkey was pressed. If the BootOrder is empty there
    // is nothing to boot either, so enter the Boot Manager menu anyway: the
    // menu is the only thing that can be shown to the user on this platform
    // (no OS installed yet) and it keeps the display and the keyboard alive
    // instead of parking BDS in a dead loop.
    //
    // Note that the Boot Manager menu load option itself is NOT part of the
    // BootOrder, it is a separate load option, so an empty BootOrder here
    // really means "nothing to boot".
    //
    BootOptionCount = 0;
    BootOptions     = EfiBootManagerGetLoadOptions (&BootOptionCount, LoadOptionTypeBoot);
    if (BootOptions != NULL) {
      EfiBootManagerFreeLoadOptions (BootOptions, BootOptionCount);
    }

    if (BootOptionCount == 0) {
      DEBUG ((DEBUG_ERROR, "K70U-BDS: BootOrder is empty, entering Boot Manager menu\\n"));
      BootManagerFlag = TRUE;
    }
  }

  if (BootManagerFlag == FALSE) {
    return;
  }
"""
    if old not in txt:
        print("ERROR: PlatformBootManagerPriorityBoot anchor not found")
        sys.exit(2)

    txt = txt.replace(old, new, 1)

    # make sure the boot manager lib API is declared
    if "Library/UefiBootManagerLib.h" not in txt:
        txt = txt.replace(
            "#include <Library/PlatformBootManagerLib.h>",
            "#include <Library/PlatformBootManagerLib.h>\n#include <Library/UefiBootManagerLib.h>",
            1,
        )

    write(BM, txt, crlf)
    print("BootManager.c: added empty-BootOrder -> menu fallback")

print("done")
