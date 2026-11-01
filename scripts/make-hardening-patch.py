#!/usr/bin/env python3
"""Generate patches/0003-rothko-pool-hardening.patch: bring-up fixes for the pool
corruption that kills the boot with a data abort inside CoreFreePoolI.

Three upstream files are patched (all inside Mu_Basecore):

  1. MdeModulePkg/Core/Dxe/Mem/Pool.c
     CoreInternalFreePool() dereferences any non-NULL pointer to read the pool
     signature. A bogus pointer therefore takes the whole firmware down with a
     data abort (which only surfaces ~33 s later as a watchdog reset). Reject
     pointers that cannot possibly be pool blocks instead.

  2. MdeModulePkg/Library/UefiBootManagerLib/BmConsole.c
     BmGetGopDevicePath() frees TempDevicePath and leaves it dangling; the same
     variable is freed again a few lines later. Worse, when the recursive lookup
     returns NULL the trailing block frees the *live* GopPool that the function
     is about to return. Both are double frees on the controller-connect path.

  3. MdeModulePkg/Universal/Console/GraphicsConsoleDxe/GraphicsConsole.c
     GraphicsConsoleConOutSetMode() frees Private->LineBuffer without clearing
     it; if the following allocation fails the stale pointer is freed again by
     the error path.

Every file is normalised to LF first (the build script does the same for files
named by the patch series), so the hunks are emitted with LF endings.

Usage (inside WSL):
    python3 make-hardening-patch.py /home/ubuntu/rothko/Mu-Silicium <out.patch>
"""
import difflib
import pathlib
import sys

POOL = "Mu_Basecore/MdeModulePkg/Core/Dxe/Mem/Pool.c"
BMCON = "Mu_Basecore/MdeModulePkg/Library/UefiBootManagerLib/BmConsole.c"
GCONS = "Mu_Basecore/MdeModulePkg/Universal/Console/GraphicsConsoleDxe/GraphicsConsole.c"
BMHEALTH = "Mu_Basecore/MdeModulePkg/Library/UefiBootManagerLib/BmDriverHealth.c"
BMMISC = "Mu_Basecore/MdeModulePkg/Library/UefiBootManagerLib/BmMisc.c"

POOL_OLD = (
    "CoreInternalFreePool (\n"
    "  IN VOID              *Buffer,\n"
    "  OUT EFI_MEMORY_TYPE  *PoolType OPTIONAL\n"
    "  )\n"
    "{\n"
    "  EFI_STATUS  Status;\n"
    "\n"
    "  if (Buffer == NULL) {\n"
    "    return EFI_INVALID_PARAMETER;\n"
    "  }\n"
)

POOL_NEW = POOL_OLD + (
    "\n"
    "  //\n"
    "  // ROTHKO bring-up hardening. CoreFreePoolI dereferences the head that\n"
    "  // precedes the buffer to validate the pool signature, so a stale or\n"
    "  // truncated pointer (a status code, an index, a freed block) brings the\n"
    "  // whole firmware down with a data abort that only shows up ~33 s later as\n"
    "  // a watchdog reset. Anything below the first page, or not 8-byte aligned,\n"
    "  // cannot be a pool block: reject it and let the caller carry on.\n"
    "  //\n"
    "  if (((UINTN)Buffer < 0x1000) || (((UINTN)Buffer & 0x7) != 0)) {\n"
    "    return EFI_INVALID_PARAMETER;\n"
    "  }\n"
)

BMCON_OLD = (
    "            if (TempDevicePath != NULL) {\n"
    "              gBS->FreePool (TempDevicePath);\n"
    "            }\n"
    "\n"
    "            gBS->FreePool (ReturnDevicePath);\n"
    "          }\n"
    "\n"
    "          if (TempDevicePath != NULL) {\n"
    "            gBS->FreePool (TempDevicePath);\n"
    "          }\n"
)

BMCON_NEW = (
    "            if (TempDevicePath != NULL) {\n"
    "              gBS->FreePool (TempDevicePath);\n"
    "              TempDevicePath = NULL;\n"
    "            }\n"
    "\n"
    "            gBS->FreePool (ReturnDevicePath);\n"
    "          }\n"
    "\n"
    "          //\n"
    "          // ROTHKO fix: this used to free TempDevicePath a second time, and when\n"
    "          // the recursive lookup returned NULL it freed the live GopPool that\n"
    "          // this function is about to hand back to its caller.\n"
    "          //\n"
)

GCONS_OLD = (
    "    FlushCursor (This);\n"
    "\n"
    "    FreePool (Private->LineBuffer);\n"
    "  }\n"
)

GCONS_NEW = (
    "    FlushCursor (This);\n"
    "\n"
    "    FreePool (Private->LineBuffer);\n"
    "    //\n"
    "    // ROTHKO fix: leaving the pointer behind means the error path below\n"
    "    // frees the same block a second time once AllocatePool has failed.\n"
    "    //\n"
    "    Private->LineBuffer = NULL;\n"
    "  }\n"
)

BMHEALTH_OLD = (
    "  if (RebootRequired) {\n"
    '    DEBUG ((DEBUG_INFO, "[BDS] One of the Driver Health instances requires rebooting.\\n"));\n'
    "    gRT->ResetSystem (EfiResetWarm, EFI_SUCCESS, 0, NULL);\n"
    "  }\n"
)

BMHEALTH_NEW = (
    "  if (RebootRequired) {\n"
    '    DEBUG ((DEBUG_INFO, "[BDS] One of the Driver Health instances requires rebooting.\\n"));\n'
    "    //\n"
    "    // ROTHKO bring-up: a warm reset here costs the whole attempt (the panel\n"
    "    // goes back to the LK logo and no dump is produced). Stay put instead;\n"
    "    // the firmware has nothing to hand control to on this port anyway.\n"
    "    //\n"
    "  }\n"
)

BMMISC_OLD = (
    "      if (MemoryTypeInformationModified) {\n"
    '        DEBUG ((DEBUG_INFO, "Memory Type Information settings change.\\n"));\n'
    "        if (Boot && PcdGetBool (PcdResetOnMemoryTypeInformationChange)) {\n"
    '          DEBUG ((DEBUG_INFO, "...Warm Reset!!!\\n"));\n'
    "          gRT->ResetSystem (EfiResetWarm, EFI_SUCCESS, 0, NULL);\n"
    "        }\n"
    "      }\n"
)

BMMISC_NEW = (
    "      if (MemoryTypeInformationModified) {\n"
    '        DEBUG ((DEBUG_INFO, "Memory Type Information settings change.\\n"));\n'
    "        //\n"
    "        // ROTHKO bring-up: never warm-reset just because the memory type\n"
    "        // information changed. See BmDriverHealth.c for the same reasoning.\n"
    "        //\n"
    "      }\n"
)

EDITS = [
    (POOL, POOL_OLD, POOL_NEW),
    (BMCON, BMCON_OLD, BMCON_NEW),
    (GCONS, GCONS_OLD, GCONS_NEW),
    (BMHEALTH, BMHEALTH_OLD, BMHEALTH_NEW),
    (BMMISC, BMMISC_OLD, BMMISC_NEW),
]


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__)
        return 2

    tree = pathlib.Path(sys.argv[1])
    out = pathlib.Path(sys.argv[2])
    chunks = []

    for rel, old, new in EDITS:
        path = tree / rel
        with open(path, "r", encoding="utf-8", newline="") as fh:
            raw = fh.read()
        text = raw.replace("\r\n", "\n")

        if text.count(old) != 1:
            print(f"ERROR: {rel}: anchor found {text.count(old)} times, expected 1")
            return 1

        patched = text.replace(old, new, 1)
        diff = list(
            difflib.unified_diff(
                text.splitlines(keepends=True),
                patched.splitlines(keepends=True),
                fromfile="a/" + rel,
                tofile="b/" + rel,
                n=3,
            )
        )
        if not diff:
            print(f"ERROR: {rel}: empty diff")
            return 1
        chunks.append("diff --git a/%s b/%s\n" % (rel, rel) + "".join(diff))

    with open(out, "w", encoding="utf-8", newline="") as fh:
        fh.write("\n".join(chunks))

    print(f"wrote {out} ({sum(len(c.splitlines()) for c in chunks)} lines, {len(EDITS)} files)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
