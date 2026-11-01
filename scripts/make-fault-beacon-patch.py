#!/usr/bin/env python3
"""Generate patches/0002-rothko-fault-beacon.patch from the pristine EDK II source.

The patched function is DumpCpuContext() in the AArch64 CpuExceptionHandlerLib.
On rothko the only channel that survives a watchdog reset is the ATF dump in
expdb, and it reports exactly pc/lr/sp/pstate. So instead of printing (the
framebuffer console cannot be scanned out yet) the handler parks the CPU with
the payload encoded in LR.

Chain of evidence so far:

  v1  lr = EC<<56 | FAR        -> EC 0x25 (data abort, same EL), FAR = -15
  v2  lr = EC | ELR | FAR[23:0] -> faulting PC 0x43b86bd4
  v3  lr = name | EC | RVA      -> DxeCore + 0x7bd4 = CoreFreePoolI
  v4  lr = name | 0xC1 | RVA    -> first caller frame outside DxeCore

v4 walks the frame chain: CoreFreePoolI stores {x29,x30} at [sp+0x50] and then
subtracts 0x10, so at its signature check the caller's frame pointer is at
SP+0x60 and each frame's return address at FP+8. Frames inside DxeCore are
skipped, which lands on the driver that called gBS->FreePool ().

    lr[63:32] = 4 ASCII characters of that image's base name
    lr[31:24] = 0xC1 marker
    lr[23:0]  = RVA of the return address inside its image (0xFFFFFF if none)

Read the expdb line as:  lr:<4e616d65 C1 RRRRRR>

Usage (inside WSL, build tree = /home/ubuntu/rothko/Mu-Silicium):

    python3 make-fault-beacon-patch.py \
        /home/ubuntu/rothko/Mu-Silicium \
        "/mnt/d/漏洞/UNIXNU/适配K70U/src/uefi-rothko/patches/0002-rothko-fault-beacon.patch"
"""
import difflib
import pathlib
import sys

REL = "Mu_Basecore/UefiCpuPkg/Library/CpuExceptionHandlerLib/AArch64/CpuExceptionHandlerLib.c"
ANCHOR = "  if (mRecursiveException) {"

BLOCK = r'''  //
  // ROTHKO FAULT BEACON v4 -- diagnostic, applied by
  // patches/0002-rothko-fault-beacon.patch
  //
  // The ATF watchdog dump in expdb records pc/lr/sp/pstate for the dying CPU
  // and nothing else. Everything below this point prints to a framebuffer
  // console that cannot be scanned out on this port yet, so the raw register
  // state is the only thing that survives the reset.
  //
  // lr[63:32] = four characters of the first caller image outside DxeCore
  // lr[31:24] = 0xC1 marker
  // lr[23:0]  = RVA of that return address in its own image
  //
  {
    UINT64  Beacon;
    UINT64  Fp;
    UINT64  Ra;
    UINT64  Rva;
    UINTN   ImageBase;
    UINTN   HeaderSize;
    CHAR8   *Pdb;
    UINT32  Tag;
    UINT32  Index;
    UINT32  Walk;

    Fp  = *(UINT64 *)(UINTN)(SystemContext.SystemContextAArch64->SP + 0x60);
    Ra  = 0;
    Rva = 0xFFFFFF;
    Tag = 0;

    for (Walk = 0; Walk < 12; Walk++) {
      if ((Fp < 0x42200000ULL) || (Fp >= 0x42240000ULL)) {
        break;
      }

      Ra = *(UINT64 *)(UINTN)(Fp + 8);
      Fp = *(UINT64 *)(UINTN)Fp;
      if ((Ra < 0x42000000ULL) || (Ra >= 0x44000000ULL)) {
        continue;
      }

      ImageBase = 0;
      Pdb       = GetImageName (Ra, &ImageBase, &HeaderSize);
      if ((Pdb == NULL) || (ImageBase == 0)) {
        continue;
      }

      Pdb = (CHAR8 *)BaseName (Pdb);
      if ((Pdb[0] == 'D') && (Pdb[1] == 'x') && (Pdb[2] == 'e') && (Pdb[3] == 'C')) {
        continue;
      }

      for (Index = 0; Index < 4; Index++) {
        Tag = (Tag << 8) | (UINT8)((Pdb[Index] != 0) ? Pdb[Index] : ' ');
      }

      Rva = (Ra - ImageBase) & 0xFFFFFFULL;
      break;
    }

    Beacon  = ((UINT64)Tag) << 32;
    Beacon |= ((UINT64)0xC1) << 24;
    Beacon |= Rva;

    __asm__ volatile (
      "mov x30, %0\n\t"
      "1:\n\t"
      "b 1b\n\t"
      :: "r" (Beacon) : "x30", "memory"
      );
  }

'''


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__)
        return 2

    tree = pathlib.Path(sys.argv[1])
    out = pathlib.Path(sys.argv[2])

    src = tree / REL
    with open(src, "r", encoding="utf-8", newline="") as fh:
        text = fh.read()

    if "ROTHKO FAULT BEACON" in text:
        print("ERROR: build tree already carries the beacon; revert it first")
        return 1

    # The EDK II checkout on this host keeps CRLF; the build script normalises
    # the files named by the patch series to LF before applying anything, so
    # the hunk has to match whatever the file holds right now.
    eol = "\r\n" if "\r\n" in text else "\n"
    anchor = ANCHOR + eol
    block = BLOCK.replace("\n", eol)

    if text.count(anchor) != 1:
        print(f"ERROR: anchor found {text.count(anchor)} times, expected 1")
        return 1

    patched = text.replace(anchor, block + anchor, 1)

    diff = difflib.unified_diff(
        text.splitlines(keepends=True),
        patched.splitlines(keepends=True),
        fromfile="a/" + REL,
        tofile="b/" + REL,
        n=3,
    )

    body = "".join(diff)
    if not body:
        print("ERROR: empty diff")
        return 1

    with open(out, "w", encoding="utf-8", newline="") as fh:
        fh.write("diff --git a/%s b/%s\n" % (REL, REL) + body)

    print(f"wrote {out} ({len(body.splitlines())} diff lines)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
