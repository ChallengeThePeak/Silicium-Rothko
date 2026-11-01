/**
  Copyright (c) 2011-2017, ARM Limited. All rights reserved.
  SPDX-License-Identifier: BSD-2-Clause-Patent
**/

#include <Library/PcdLib.h>
#include <Library/DebugLib.h>
#include <Library/PrePiLib.h>
#include <Library/DebugAgentLib.h>
#include <Library/BaseMemoryLib.h>
#include <Library/SerialPortLib.h>
#include <Library/PlatformSecLib.h>
#include <Library/PrePiHobListPointerLib.h>
#include <Library/CacheMaintenanceLib.h>
#include <Library/MemoryMapHelperLib.h>
#include <Library/TimerLib.h>
#include <Library/HobLib.h>

#include "Sec.h"

// First argument (x0) of the previous stage, saved by ModuleEntryPoint.S
extern UINT64  gSecEntryArg0;

// The library constructors ProcessLibraryConstructorList () runs for this module, in its generated order, called one by one so the screen
// shows which one a stall is in (an entry here that the generated list lacks fails to link, which is the check).
// Helper.S: clean and invalidate every data cache level by set/way (see there).
extern VOID SecCleanInvalidateDataCacheAll (VOID);

extern RETURN_STATUS EFIAPI BaseDebugLibSerialPortConstructor (VOID);
extern RETURN_STATUS EFIAPI ExtractGuidedSectionLibConstructor (VOID);
extern RETURN_STATUS EFIAPI ArmMmuBaseLibConstructor (VOID);
extern RETURN_STATUS EFIAPI LzmaDecompressLibConstructor (VOID);
extern VOID EFIAPI PstoreLogBegin (VOID);

// Walks the HOB list with a bound, so a zero-length or runaway entry is reported instead of looping forever in the constructors and in
// the FV decompression that follow (both search the list).
STATIC
VOID
CheckHobList (IN CONST CHAR8 *Stage)
{
  EFI_PEI_HOB_POINTERS  Hob;
  UINTN                 Count = 0;

  Hob.Raw = GetHobList ();
  DEBUG ((EFI_D_WARN, "SEC: HOB dump %a list=%p\n", Stage, Hob.Raw));
  while (!END_OF_HOB_LIST (Hob)) {
    if (Hob.Header->HobLength < sizeof (EFI_HOB_GENERIC_HEADER) || Count >= 16384) {
      DEBUG ((EFI_D_ERROR, "SEC: HOB list broken at entry %u: type 0x%x length %u\n", (UINT32)Count, (UINT32)Hob.Header->HobType, (UINT32)Hob.Header->HobLength));
      return;
    }

    DEBUG ((DEBUG_INFO, "SEC: HOB[%u] ptr=%p type=0x%x length=%u\n", (UINT32)Count, Hob.Raw, (UINT32)Hob.Header->HobType, (UINT32)Hob.Header->HobLength));
    switch (Hob.Header->HobType) {
      case EFI_HOB_TYPE_HANDOFF:
        DEBUG ((EFI_D_WARN, "SEC: PHIT memory=[0x%Lx,0x%Lx) free=[0x%Lx,0x%Lx) end=0x%Lx boot=0x%x\n",
          Hob.HandoffInformationTable->EfiMemoryBottom, Hob.HandoffInformationTable->EfiMemoryTop,
          Hob.HandoffInformationTable->EfiFreeMemoryBottom, Hob.HandoffInformationTable->EfiFreeMemoryTop,
          Hob.HandoffInformationTable->EfiEndOfHobList, (UINT32)Hob.HandoffInformationTable->BootMode));
        break;
      case EFI_HOB_TYPE_RESOURCE_DESCRIPTOR:
      case EFI_HOB_TYPE_RESOURCE_DESCRIPTOR2:
        DEBUG ((DEBUG_INFO, "SEC: resource type=%u base=0x%Lx size=0x%Lx attr=0x%Lx\n",
          Hob.ResourceDescriptor->ResourceType, Hob.ResourceDescriptor->PhysicalStart,
          Hob.ResourceDescriptor->ResourceLength, Hob.ResourceDescriptor->ResourceAttribute));
        break;
      case EFI_HOB_TYPE_MEMORY_ALLOCATION:
        DEBUG ((DEBUG_INFO, "SEC: allocation base=0x%Lx size=0x%Lx type=%u name=%g\n",
          Hob.MemoryAllocation->AllocDescriptor.MemoryBaseAddress, Hob.MemoryAllocation->AllocDescriptor.MemoryLength,
          (UINT32)Hob.MemoryAllocation->AllocDescriptor.MemoryType, &Hob.MemoryAllocation->AllocDescriptor.Name));
        break;
      case EFI_HOB_TYPE_FV:
        DEBUG ((DEBUG_INFO, "SEC: FV base=0x%Lx size=0x%Lx\n", Hob.FirmwareVolume->BaseAddress, Hob.FirmwareVolume->Length));
        break;
      default:
        break;
    }

    Count++;
    Hob.Raw = GET_NEXT_HOB (Hob);
  }

  DEBUG ((EFI_D_WARN, "SEC: HOB list ok, %u entries\n", (UINT32)Count));
}

#ifndef MDEPKG_NDEBUG
STATIC
VOID
ClearFrameBuffer (VOID)
{
  EFI_MEMORY_REGION_DESCRIPTOR FrameBufferRegion;

  // Locate "Display Reserved" Memory Region
  LocateMemoryRegionByName ("Display Reserved", &FrameBufferRegion);
  LocateMemoryRegionByName ("Display_Reserved", &FrameBufferRegion);

  // Clear Memory Region
  if (FrameBufferRegion.Address != 0 && FrameBufferRegion.Length != 0) {
    ZeroMem ((VOID *)FrameBufferRegion.Address, FrameBufferRegion.Length);
  }
}

STATIC
VOID
PrintFirmwareVersion (VOID)
{
  // Clear Frame Buffer
  ClearFrameBuffer ();

  // Print UEFI Version Message
  DEBUG ((EFI_D_WARN, "\n"));
  DEBUG ((EFI_D_WARN, "Project Silicium for %a %a\n",            FixedPcdGetPtr (PcdSmbiosSystemManufacturer), FixedPcdGetPtr (PcdSmbiosSystemModel)));
  DEBUG ((EFI_D_WARN, "Firmware Version %s Build at %a on %a\n", PcdGetPtr (PcdFirmwareVersionString), __TIME__, __DATE__));
  DEBUG ((EFI_D_WARN, "\n"));
}
#endif

STATIC
EFI_STATUS
InitializeMemory (VOID)
{
  EFI_STATUS                    Status;
  EFI_MEMORY_REGION_DESCRIPTOR  UefiMemoryRegion;
  EFI_HOB_HANDOFF_INFO_TABLE   *HobList;

  // Locate "DXE Heap" Memory Region
  LocateMemoryRegionByName ("DXE Heap", &UefiMemoryRegion);
  LocateMemoryRegionByName ("DXE_Heap", &UefiMemoryRegion);

  // Save UEFI Memory Details
  UINTN UefiMemoryBase = UefiMemoryRegion.Address;
  UINTN UefiMemorySize = UefiMemoryRegion.Length;

  DEBUG ((EFI_D_WARN, "SEC: heap base=0x%Lx size=0x%Lx resource=%u attr=0x%Lx memory=%u arm=%u\n",
    (UINT64)UefiMemoryBase, (UINT64)UefiMemorySize, UefiMemoryRegion.ResourceType,
    UefiMemoryRegion.ResourceAttribute, (UINT32)UefiMemoryRegion.MemoryType, (UINT32)UefiMemoryRegion.ArmAttributes));

  // Verify UEFI Memory Base
  if (UefiMemoryBase == 0 && UefiMemorySize == 0) {
    DEBUG ((EFI_D_ERROR, "Failed to Locate \"DXE Heap\" Memory Region!\n"));
    return EFI_NOT_FOUND;
  }

  // Initialize HOB List
  HobList = HobConstructor ((VOID *)UefiMemoryBase, UefiMemorySize, (VOID *)UefiMemoryBase, (VOID *)(UefiMemoryBase + UefiMemorySize));
  PrePeiSetHobList (HobList);
  DEBUG ((EFI_D_WARN, "SEC: HobConstructor list=%p free=[0x%Lx,0x%Lx)\n", HobList, HobList->EfiFreeMemoryBottom, HobList->EfiFreeMemoryTop));

  // Initialize MMU & Memory HOBs
  Status = MemoryPeim (UefiMemoryBase, UefiMemorySize);
  DEBUG ((EFI_D_WARN, "SEC: MemoryPeim returned %r SCTLR=0x%Lx\n", Status, (UINT64)ArmReadSctlr ()));
  if (EFI_ERROR (Status)) {
    return Status;
  }

  // Build Stack HOB
  BuildStackHob (FixedPcdGet64 (PcdCPUCoresStackBase), FixedPcdGet32 (PcdCPUCorePrimaryStackSize));
  DEBUG ((EFI_D_WARN, "SEC: stack base=0x%Lx size=0x%x\n", FixedPcdGet64 (PcdCPUCoresStackBase), FixedPcdGet32 (PcdCPUCorePrimaryStackSize)));

  return EFI_SUCCESS;
}

STATIC
VOID
SecMain (VOID)
{
  EFI_STATUS Status;

  // Do Platform Specific Initialization
  DEBUG ((EFI_D_WARN, "SEC: PlatformInitialize begin\n"));
  PlatformInitialize ();
  DEBUG ((EFI_D_WARN, "SEC: PlatformInitialize done\n"));

#ifndef MDEPKG_NDEBUG
  // Initialize Serial Port
  Status = SerialPortInitialize ();
  DEBUG ((EFI_D_WARN, "SEC: SerialPortInitialize returned %r\n", Status));
  if (EFI_ERROR (Status)) {
    return;
  }

  // Print Firmware Version
  PrintFirmwareVersion ();

  // Initialize Debug Agent
  DEBUG ((EFI_D_WARN, "SEC: debug agent begin\n"));
  InitializeDebugAgent (DEBUG_AGENT_INIT_POSTMEM_SEC, NULL, NULL);
  SaveAndSetDebugTimerInterrupt (TRUE);
  DEBUG ((EFI_D_WARN, "SEC: debug agent done\n"));
#endif

  // Initialize Memory
  Status = InitializeMemory ();
  DEBUG ((EFI_D_WARN, "SEC: InitializeMemory returned %r\n", Status));
  if (EFI_ERROR (Status)) {
    return;
  }

  DEBUG ((EFI_D_WARN, "SEC: memory HOBs done\n"));

  // Build CPU HOB
  BuildCpuHob (ArmGetPhysicalAddressBits (), PcdGet8 (PcdPrePiCpuIoSize));
  DEBUG ((EFI_D_WARN, "SEC: CPU HOB physical-bits=%u io-bits=%u\n", (UINT32)ArmGetPhysicalAddressBits (), (UINT32)PcdGet8 (PcdPrePiCpuIoSize)));

  // Set the Boot Mode
  SetBootMode (BOOT_WITH_DEFAULT_SETTINGS);

  // Initialize Platform HOBs
  Status = PlatformPeim ();
  DEBUG ((EFI_D_WARN, "SEC: platform HOBs done (%r)\n", Status));
  if (EFI_ERROR (Status)) {
    return;
  }

  // Pass on what the previous stage handed over in x0 (a DT address for a
  // Linux-style boot loader), so a DXE driver can use it.
  {
    UINT64  EntryArg = gSecEntryArg0;

    BuildGuidDataHob (&gSiliciumEntryArgHobGuid, &EntryArg, sizeof (EntryArg));
    DEBUG ((EFI_D_WARN, "SEC: entry argument HOB x0=0x%Lx\n", EntryArg));
  }

  CheckHobList ("before-constructors");

  // Run Library Cconstructors
  DEBUG ((EFI_D_WARN, "SEC: constructor debug\n"));
  BaseDebugLibSerialPortConstructor ();
  DEBUG ((EFI_D_WARN, "SEC: constructor guided-section\n"));
  ExtractGuidedSectionLibConstructor ();
  DEBUG ((EFI_D_WARN, "SEC: constructor mmu\n"));
  ArmMmuBaseLibConstructor ();
  DEBUG ((EFI_D_WARN, "SEC: constructor lzma\n"));
  LzmaDecompressLibConstructor ();
  DEBUG ((EFI_D_WARN, "SEC: constructors done\n"));
  CheckHobList ("before-FV");

  // Decompress all FVs
  Status = DecompressFirstFv ();
  DEBUG ((EFI_D_WARN, "SEC: FV decompressed (%r)\n", Status));
  if (EFI_ERROR (Status)) {
    DEBUG ((EFI_D_ERROR, "Failed to Decompress FV! Status = %r\n", Status));
    return;
  }

  CheckHobList ("before-DXE");

  // Load DXE Core
  DEBUG ((EFI_D_WARN, "SEC: loading DXE core\n"));
  Status = LoadDxeCoreFromFv (NULL, 0);
  DEBUG ((EFI_D_ERROR, "SEC: LoadDxeCoreFromFv unexpectedly returned %r\n", Status));
  if (EFI_ERROR (Status)) {
    DEBUG ((EFI_D_ERROR, "Failed to Load DXE Core! Status = %r\n", Status));
  }
}

VOID
SecEntry (VOID)
{
  // The previous stage ran with its caches on. Clean and invalidate them before anything else: the UEFI writes its HOB tables and heap with
  // the MMU and caches off, and lines the previous stage left would hide those writes (or be written back over them) once the caches are on.
  SecCleanInvalidateDataCacheAll ();

  // Disable Data Cache
  ArmDisableDataCache ();

  // Invalidate Instruction Cache
  ArmInvalidateInstructionCache ();

  // Enable Instruction Cache
  ArmEnableInstructionCache ();

  // Write back and invalidate Stack & UEFI FD D-Cache. A plain invalidate would discard what the entry code just stored there
  // (live stack frames, gSecEntryArg0) if the previous stage left the data cache on.
  WriteBackInvalidateDataCacheRange ((VOID *)FixedPcdGet64 (PcdCPUCoresStackBase), FixedPcdGet32 (PcdCPUCorePrimaryStackSize));
  WriteBackInvalidateDataCacheRange ((VOID *)FixedPcdGet64 (PcdFdBaseAddress),     FixedPcdGet32 (PcdFdSize));

  // Verify Exception Vector Table
  ASSERT (((UINTN)SecVectorTable & ARM_VECTOR_TABLE_ALIGNMENT) == 0);

  // Enable new Exception Vector Table
  ArmWriteVBar ((UINTN)SecVectorTable);

  // Record entry before platform, framebuffer and MMU initialization can stall.
  PstoreLogBegin ();
  DEBUG ((EFI_D_WARN, "K70U_UEFI_TRACE_V2 x0=0x%Lx SCTLR=0x%Lx VBAR=%p ticks=0x%Lx\n",
    gSecEntryArg0, (UINT64)ArmReadSctlr (), SecVectorTable, GetPerformanceCounter ()));
  DEBUG ((EFI_D_WARN, "SEC: FD base=0x%Lx size=0x%x stack=0x%Lx size=0x%x\n",
    FixedPcdGet64 (PcdFdBaseAddress), FixedPcdGet32 (PcdFdSize),
    FixedPcdGet64 (PcdCPUCoresStackBase), FixedPcdGet32 (PcdCPUCorePrimaryStackSize)));

  // Enter Main SEC Function
  SecMain ();
  DEBUG ((EFI_D_ERROR, "SEC: SecMain unexpectedly returned\n"));
}
