#include <Library/MemoryMapLib.h>

//
// OS3.0.303 live mblock snapshot. LK releases mb_kernel, mb_dtb and
// mb_ramdisk before exporting the FDT, so those handoff ranges are carved
// back out below. Unlisted address gaps and mblock reservations stay unmapped.
//
STATIC EFI_MEMORY_REGION_DESCRIPTOR gMemoryDescriptor[] = {
  // Low free extent [0x40000000, 0x48080000), split for firmware and handoff.
  {"BootShim Source", 0x40000000, 0x00201000, AddMem, SYS_MEM, SYS_MEM_CAP_XN, BsData, WRITE_BACK},
  {"Free Low A",      0x40201000, 0x001FF000, AddMem, SYS_MEM, SYS_MEM_CAP_XN, Conv,   WRITE_BACK_XN},
  {"UEFI FD",         0x40400000, 0x00200000, AddMem, SYS_MEM, SYS_MEM_CAP_XN, BsData, WRITE_BACK},
  {"UEFI Stack",      0x40600000, 0x00040000, AddMem, SYS_MEM, SYS_MEM_CAP_XN, BsData, WRITE_BACK_XN},
  {"Free Low B",      0x40640000, 0x00040000, AddMem, SYS_MEM, SYS_MEM_CAP_XN, Conv,   WRITE_BACK_XN},
  {"DXE Heap",        0x40680000, 0x01000000, AddMem, SYS_MEM, SYS_MEM_CAP_XN, Conv,   WRITE_BACK_XN},
  {"Free Low C",      0x41680000, 0x06600000, AddMem, SYS_MEM, SYS_MEM_CAP_XN, Conv,   WRITE_BACK_XN},
  {"Incoming DTB",    0x47C80000, 0x00400000, AddMem, SYS_MEM, SYS_MEM_CAP_XN, BsData, WRITE_BACK_XN},
  {"Pstore",          0x48090000, 0x000E0000, AddMem, MEM_RES, UNCACHEABLE, Reserv, UNCACHED_UNBUFFERED_XN},

  // Remaining mblock free extents, excluding the live initrd envelope.
  {"Free 01", 0x48180000, 0x00281000, AddMem, SYS_MEM, SYS_MEM_CAP_XN, Conv, WRITE_BACK_XN},
  {"Free 02", 0x48402000, 0x003FE000, AddMem, SYS_MEM, SYS_MEM_CAP_XN, Conv, WRITE_BACK_XN},
  {"Free 03a",0x48A00000, 0x1E500000, AddMem, SYS_MEM, SYS_MEM_CAP_XN, Conv, WRITE_BACK_XN},
  {"Incoming Initrd",0x66F00000, 0x037D4000, AddMem, SYS_MEM, SYS_MEM_CAP_XN, BsData, WRITE_BACK_XN},
  {"Free 03b",0x6A6D4000, 0x0392A000, AddMem, SYS_MEM, SYS_MEM_CAP_XN, Conv, WRITE_BACK_XN},
  {"Free 04", 0x6FFFF000, 0x0A001000, AddMem, SYS_MEM, SYS_MEM_CAP_XN, Conv, WRITE_BACK_XN},
  {"Free 05", 0x7B930000, 0x016D0000, AddMem, SYS_MEM, SYS_MEM_CAP_XN, Conv, WRITE_BACK_XN},
  {"Free 06", 0x7E800000, 0x00800000, AddMem, SYS_MEM, SYS_MEM_CAP_XN, Conv, WRITE_BACK_XN},
  {"Free 07", 0x7FE00000, 0x00070000, AddMem, SYS_MEM, SYS_MEM_CAP_XN, Conv, WRITE_BACK_XN},
  {"Free 08", 0x7FFF0000, 0x00008000, AddMem, SYS_MEM, SYS_MEM_CAP_XN, Conv, WRITE_BACK_XN},
  {"Free 09", 0x80200000, 0x0BE00000, AddMem, SYS_MEM, SYS_MEM_CAP_XN, Conv, WRITE_BACK_XN},
  {"Free 10", 0x8C130000, 0x002D0000, AddMem, SYS_MEM, SYS_MEM_CAP_XN, Conv, WRITE_BACK_XN},
  {"Free 11", 0x8C600000, 0x00140000, AddMem, SYS_MEM, SYS_MEM_CAP_XN, Conv, WRITE_BACK_XN},
  {"Free 12", 0x8EB58000, 0x000A8000, AddMem, SYS_MEM, SYS_MEM_CAP_XN, Conv, WRITE_BACK_XN},
  {"Free 13", 0x90000000, 0x06000000, AddMem, SYS_MEM, SYS_MEM_CAP_XN, Conv, WRITE_BACK_XN},
  {"Free 14", 0x9B400000, 0x00C00000, AddMem, SYS_MEM, SYS_MEM_CAP_XN, Conv, WRITE_BACK_XN},
  {"Free 15", 0x9F0A0000, 0x00BCF000, AddMem, SYS_MEM, SYS_MEM_CAP_XN, Conv, WRITE_BACK_XN},
  {"Free 16", 0x9FFFF000, 0x12001000, AddMem, SYS_MEM, SYS_MEM_CAP_XN, Conv, WRITE_BACK_XN},
  {"Free 17", 0xB6F60000, 0x010A0000, AddMem, SYS_MEM, SYS_MEM_CAP_XN, Conv, WRITE_BACK_XN},
  {"Free 18", 0xBAB00000, 0x04900000, AddMem, SYS_MEM, SYS_MEM_CAP_XN, Conv, WRITE_BACK_XN},
  {"Free 19", 0xBFC00000, 0x001F0000, AddMem, SYS_MEM, SYS_MEM_CAP_XN, Conv, WRITE_BACK_XN},
  {"Free 20", 0xCC000000, 0x04000000, AddMem, SYS_MEM, SYS_MEM_CAP_XN, Conv, WRITE_BACK_XN},
  {"Free 21", 0xD2B70000, 0x00490000, AddMem, SYS_MEM, SYS_MEM_CAP_XN, Conv, WRITE_BACK_XN},
  {"Free 22", 0xD3250000, 0x00DB0000, AddMem, SYS_MEM, SYS_MEM_CAP_XN, Conv, WRITE_BACK_XN},
  {"Free 23", 0xDD340000, 0x102C0000, AddMem, SYS_MEM, SYS_MEM_CAP_XN, Conv, WRITE_BACK_XN},
  {"Free 24", 0xEE000000, 0x0A000000, AddMem, SYS_MEM, SYS_MEM_CAP_XN, Conv, WRITE_BACK_XN},
  {"Free 25", 0xF8BD0000, 0x00430000, AddMem, SYS_MEM, SYS_MEM_CAP_XN, Conv, WRITE_BACK_XN},
  {"Free 26", 0xF9280000, 0x00D80000, AddMem, SYS_MEM, SYS_MEM_CAP_XN, Conv, WRITE_BACK_XN},
  {"Free 27", 0xFD800000, 0x000DF000, AddMem, SYS_MEM, SYS_MEM_CAP_XN, Conv, WRITE_BACK_XN},
  {"Free 28", 0xFFFFF000, 0xBFFFF000, AddMem, SYS_MEM, SYS_MEM_CAP_XN, Conv, WRITE_BACK_XN},
  {"Free 29", 0x1C0000000, 0x17D600000, AddMem, SYS_MEM, SYS_MEM_CAP_XN, Conv, WRITE_BACK_XN},
  {"Free 30", 0x33FE41000, 0x0017D000, AddMem, SYS_MEM, SYS_MEM_CAP_XN, Conv, WRITE_BACK_XN},

  // FDT-described GICv3 register windows.
  {"GIC Distributor",   0x0C400000, 0x00040000, AddDev, MMAP_IO, UNCACHEABLE, MmIO, NS_DEVICE},
  {"GIC Redistributors",0x0C440000, 0x00200000, AddDev, MMAP_IO, UNCACHEABLE, MmIO, NS_DEVICE}
};

VOID
GetMemoryMap (
  OUT EFI_MEMORY_REGION_DESCRIPTOR **MemoryDescriptor,
  OUT UINT8                         *MemoryDescriptorCount
  )
{
  *MemoryDescriptor = gMemoryDescriptor;
  *MemoryDescriptorCount = (UINT8)ARRAY_SIZE (gMemoryDescriptor);
}
