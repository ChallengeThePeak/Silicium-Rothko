/** @file
  [k70u 2026-11-04] Publish the DRAM above 4 GiB to DXE.

  The phone has 24 GB; the PEI memory map stopped at 3 GiB and the remaining
  ~19 GiB was unreachable, so DarwinBoot could never satisfy the 2 GiB window its
  ADT asks for (largest low run is Free 03a, 484 MiB at 0x48A00000).

  Adding the ranges to MemoryMapLib made the firmware fault instead: MemoryPeim()
  builds the translation tables once, in PEI, from a fixed stack array.  Here the
  ranges are added after DXE is running, through gDS->AddMemorySpace() (GCD plus
  UEFI memory map) and the CPU architectural protocol's SetMemoryAttributes(),
  which grows the translation tables on demand.  ARM_MMU maps UC first,
  then the range is switched to write-back.

  Ranges come from /proc/iomem (System RAM) on the running device.

  SPDX-License-Identifier: BSD-2-Clause-Patent
**/

#include <PiDxe.h>

#include <Library/DebugLib.h>
#include <Library/DxeServicesTableLib.h>
#include <Library/UefiBootServicesTableLib.h>

#include <Protocol/Cpu.h>

typedef struct {
  UINT64  Base;
  UINT64  Size;
} ROTHKO_HIGH_RANGE;

STATIC CONST ROTHKO_HIGH_RANGE  mRanges[] = {
  { 0x0000000130000000ULL, 0x000000010FFFD000ULL },   //  4.25 GiB  130000000-23fffd000
  { 0x0000000240000000ULL, 0x00000000FFE00000ULL },   // ~4.00 GiB  240000000-33fdfffff
  { 0x0000000340000000ULL, 0x00000002CC000000ULL },   // 11.20 GiB  340000000-60bffffff
  { 0x000000060FE00000ULL, 0x000000000301FE000ULL }    // ~0.77 GiB  60fe00000-63fffdfff
};

//
// [k70u 2026-11-04] Everything must stay inside the 40-bit physical address
// space the firmware actually reports (ArmGetPhysicalAddressBits() = 40).  The
// first version of this table had the last entry 16x too large, which put the
// range end at 0x90FFD0000; the moment that address was touched the firmware
// died with an address size fault at FAR 0x90FFAF000.
//
#define ROTHKO_PA_LIMIT  0x10000000000ULL
#define ROTHKO_BLOCK     0x1000ULL

#define ROTHKO_HIGH_COUNT  (sizeof (mRanges) / sizeof (mRanges[0]))

EFI_STATUS
EFIAPI
RothkoHighMemEntry (
  IN EFI_HANDLE        ImageHandle,
  IN EFI_SYSTEM_TABLE  *SystemTable
  )
{
  EFI_STATUS             Status;
  EFI_CPU_ARCH_PROTOCOL  *Cpu;
  UINTN                  Index;
  UINT64                 TotalAdded;

  (VOID)ImageHandle;
  (VOID)SystemTable;

  Status = gBS->LocateProtocol (&gEfiCpuArchProtocolGuid, NULL, (VOID **)&Cpu);
  if (EFI_ERROR (Status)) {
    DEBUG ((DEBUG_ERROR, "ROTHKO-HIMEM: no CPU arch protocol (%r), skipped\n", Status));
    return EFI_SUCCESS;
  }

  TotalAdded = 0;
  for (Index = 0; Index < ROTHKO_HIGH_COUNT; Index++) {
    UINT64  Base = mRanges[Index].Base;
    UINT64  Size = mRanges[Index].Size;

    if (((Base | Size) & (ROTHKO_BLOCK - 1)) != 0) {
      DEBUG ((DEBUG_ERROR, "ROTHKO-HIMEM: skip 0x%lx+0x%lx (not page aligned)\n", Base, Size));
      continue;
    }

    if (((Base + Size) < Base) || ((Base + Size) > ROTHKO_PA_LIMIT)) {
      DEBUG ((DEBUG_ERROR, "ROTHKO-HIMEM: skip 0x%lx+0x%lx (outside 40-bit PA, end 0x%lx)\n",
              Base, Size, Base + Size));
      continue;
    }

    //
    // Publish to the GCD and the UEFI memory map.  Accept every capability;
    // the mapping itself is set below.
    //
    Status = gDS->AddMemorySpace (
                    EfiGcdMemoryTypeSystemMemory,
                    Base,
                    Size,
                    EFI_MEMORY_UC | EFI_MEMORY_WC | EFI_MEMORY_WT |
                    EFI_MEMORY_WB | EFI_MEMORY_WP | EFI_MEMORY_XP
                    );
    if (EFI_ERROR (Status)) {
      DEBUG ((DEBUG_ERROR, "ROTHKO-HIMEM: AddMemorySpace 0x%lx+0x%lx failed %r\n", Base, Size, Status));
      continue;
    }

    //
    // Map it.  SetMemoryAttributes builds the translation table entries on
    // demand, which is what the PEI path could not do for a second batch.
    //
    Status = Cpu->SetMemoryAttributes (Cpu, Base, Size, EFI_MEMORY_WB);
    if (EFI_ERROR (Status)) {
      DEBUG ((DEBUG_ERROR, "ROTHKO-HIMEM: SetMemoryAttributes 0x%lx+0x%lx failed %r\n", Base, Size, Status));
      gDS->RemoveMemorySpace (Base, Size);
      continue;
    }

    gDS->SetMemorySpaceAttributes (Base, Size, EFI_MEMORY_WB);

    TotalAdded += Size;
    DEBUG ((DEBUG_ERROR, "ROTHKO-HIMEM: added 0x%lx + 0x%lx (%lu MiB)\n",
            Base, Size, Size >> 20));
  }

  DEBUG ((DEBUG_ERROR, "ROTHKO-HIMEM: total added %lu MiB\n", TotalAdded >> 20));
  return EFI_SUCCESS;
}
