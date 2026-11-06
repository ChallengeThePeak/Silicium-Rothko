#include <Library/MemoryMapLib.h>

//
// [k70u-fix 2026-11-02] CoreInitializeMemoryServices (Gcd.c) requires the resource
// descriptor HOB that covers the PHIT free range to carry EXACTLY
// PRESENT|INITIALIZED|TESTED after masking. SYS_MEM_TESTED additionally sets
// UNCACHEABLE/WC/WT/WB/EXECUTION_PROTECTED, so the strict equality failed and DXE
// asserted at Gcd.c(2448) with Found=0. Cacheability and XN keep coming from the
// last two table columns, which drive the MMU setup and are unaffected.
//
#define SYS_MEM_TESTED (PRESENT | INITIALIZED | TESTED)

//
// OS3.0.303 live mblock snapshot. LK releases mb_kernel, mb_dtb and
// mb_ramdisk before exporting the FDT, so those handoff ranges are carved
// back out below. Unlisted address gaps and mblock reservations stay unmapped.
//
STATIC EFI_MEMORY_REGION_DESCRIPTOR gMemoryDescriptor[] = {
  // Low free extent [0x40000000, 0x48080000), split for firmware and handoff.
  {"BootShim Source", 0x40000000, 0x00201000, AddMem, SYS_MEM, SYS_MEM_TESTED, BsData, WRITE_BACK},
  {"Free Low A",      0x40201000, 0x001FF000, AddMem, SYS_MEM, SYS_MEM_TESTED, Conv,   WRITE_BACK_XN},
  {"UEFI FD",         0x40400000, 0x00200000, AddMem, SYS_MEM, SYS_MEM_TESTED, BsData, WRITE_BACK},
  {"UEFI Stack",      0x40600000, 0x00040000, AddMem, SYS_MEM, SYS_MEM_TESTED, BsData, WRITE_BACK_XN},
  {"Free Low B",      0x40640000, 0x00040000, AddMem, SYS_MEM, SYS_MEM_TESTED, Conv,   WRITE_BACK_XN},
  {"DXE Heap",        0x40680000, 0x01000000, AddMem, SYS_MEM, SYS_MEM_TESTED, Conv,   WRITE_BACK_XN},
  {"Free Low C",      0x41680000, 0x06600000, AddMem, SYS_MEM, SYS_MEM_TESTED, Conv,   WRITE_BACK_XN},
  // [k70u-fix 2026-11-02] Renamed to the name RothkoDisplayDxe looks up
  // ("LK DTB"), and made reserved: LK hands the live device tree over in x0
  // and the driver reads it, so GCD must not hand this range out. The old
  // tree had it as MEM_RES/Reserv at the same base and size.
  {"LK DTB", 0x47C80000, 0x00400000, AddMem, MEM_RES, SYS_MEM_TESTED, Reserv, WRITE_BACK_XN},
  {"Pstore",          0x48090000, 0x000E0000, AddMem, MEM_RES, UNCACHEABLE, Reserv, UNCACHED_UNBUFFERED_XN},

  // Remaining mblock free extents, excluding the live initrd envelope.
  {"Free 01", 0x48180000, 0x00281000, AddMem, SYS_MEM, SYS_MEM_TESTED, Conv, WRITE_BACK_XN},
  {"Free 02", 0x48402000, 0x003FE000, AddMem, SYS_MEM, SYS_MEM_TESTED, Conv, WRITE_BACK_XN},
  {"Free 03a",0x48A00000, 0x1E500000, AddMem, SYS_MEM, SYS_MEM_TESTED, Conv, WRITE_BACK_XN},
  //
  // [k70u 2026-11-03] Kernel hand-off carrier.  LK concatenates the vendor
  // ramdisk in front of the init_boot ramdisk here, and this build puts the
  // 56 MiB UniXNU payload volume in the vendor ramdisk slot, so the range
  // is widened from 0x037D4000 to a full 64 MiB.  UniXNURamDiskDxe
  // publishes the payload slice of it as a block device.
  //
  //
  // [k70u 2026-11-04] The envelope is now vendor ramdisk (~52 MiB) plus the
  // boot ramdisk that carries the 56 MiB UniXNU payload volume plus the
  // init_boot ramdisk, so 113 MiB are reserved up to the next LK mblock gap.
  //
  //
  // [k70u 2026-11-04] Reserved, not BsData.  The payload volume lives in this
  // range and the firmware was free to allocate these pages and zero them:
  // UniXNURamDiskDxe read the FAT directory entry correctly (size 241) while
  // the file cluster came back as all zeros.
  //
  {"Incoming Initrd",0x66F00000, 0x07100000, AddMem, MEM_RES, SYS_MEM_TESTED, Reserv, WRITE_BACK_XN},
  // [k70u 2026-11-04] Free 03b now lives inside the widened initrd reservation.
  {"Free 04", 0x6FFFF000, 0x0A001000, AddMem, SYS_MEM, SYS_MEM_TESTED, Conv, WRITE_BACK_XN},
  {"Free 05", 0x7B930000, 0x016D0000, AddMem, SYS_MEM, SYS_MEM_TESTED, Conv, WRITE_BACK_XN},
  {"Free 06", 0x7E800000, 0x00800000, AddMem, SYS_MEM, SYS_MEM_TESTED, Conv, WRITE_BACK_XN},
  {"Free 07", 0x7FE00000, 0x00070000, AddMem, SYS_MEM, SYS_MEM_TESTED, Conv, WRITE_BACK_XN},
  {"Free 08", 0x7FFF0000, 0x00008000, AddMem, SYS_MEM, SYS_MEM_TESTED, Conv, WRITE_BACK_XN},
  {"Free 09", 0x80200000, 0x0BE00000, AddMem, SYS_MEM, SYS_MEM_TESTED, Conv, WRITE_BACK_XN},
  {"Free 10", 0x8C130000, 0x002D0000, AddMem, SYS_MEM, SYS_MEM_TESTED, Conv, WRITE_BACK_XN},
  {"Free 11", 0x8C600000, 0x00140000, AddMem, SYS_MEM, SYS_MEM_TESTED, Conv, WRITE_BACK_XN},
  {"Free 12", 0x8EB58000, 0x000A8000, AddMem, SYS_MEM, SYS_MEM_TESTED, Conv, WRITE_BACK_XN},
  {"Free 13", 0x90000000, 0x06000000, AddMem, SYS_MEM, SYS_MEM_TESTED, Conv, WRITE_BACK_XN},
  {"Free 14", 0x9B400000, 0x00C00000, AddMem, SYS_MEM, SYS_MEM_TESTED, Conv, WRITE_BACK_XN},
  {"Free 15", 0x9F0A0000, 0x00BCF000, AddMem, SYS_MEM, SYS_MEM_TESTED, Conv, WRITE_BACK_XN},
  {"Free 16", 0x9FFFF000, 0x12001000, AddMem, SYS_MEM, SYS_MEM_TESTED, Conv, WRITE_BACK_XN},
  {"Free 17", 0xB6F60000, 0x010A0000, AddMem, SYS_MEM, SYS_MEM_TESTED, Conv, WRITE_BACK_XN},
  {"Free 18", 0xBAB00000, 0x04900000, AddMem, SYS_MEM, SYS_MEM_TESTED, Conv, WRITE_BACK_XN},
  {"Free 19", 0xBFC00000, 0x001F0000, AddMem, SYS_MEM, SYS_MEM_TESTED, Conv, WRITE_BACK_XN},
  // [k70u-3g 2026-11-02] held back for the top-region experiment
//  {"Free 20", 0xCC000000, 0x04000000, AddMem, SYS_MEM, SYS_MEM_TESTED, Conv, WRITE_BACK_XN},
  // [k70u-3g 2026-11-02] held back for the top-region experiment
//  {"Free 21", 0xD2B70000, 0x00490000, AddMem, SYS_MEM, SYS_MEM_TESTED, Conv, WRITE_BACK_XN},
  // [k70u-3g 2026-11-02] held back for the top-region experiment
//  {"Free 22", 0xD3250000, 0x00DB0000, AddMem, SYS_MEM, SYS_MEM_TESTED, Conv, WRITE_BACK_XN},
  // [k70u-3g 2026-11-02] held back for the top-region experiment
//  {"Free 23", 0xDD340000, 0x102C0000, AddMem, SYS_MEM, SYS_MEM_TESTED, Conv, WRITE_BACK_XN},
  // [k70u-3g 2026-11-02] held back for the top-region experiment
//  {"Free 24", 0xEE000000, 0x0A000000, AddMem, SYS_MEM, SYS_MEM_TESTED, Conv, WRITE_BACK_XN},
  // [k70u-3g 2026-11-02] held back for the top-region experiment
//  {"Free 25", 0xF8BD0000, 0x00430000, AddMem, SYS_MEM, SYS_MEM_TESTED, Conv, WRITE_BACK_XN},
  // [k70u-3g 2026-11-02] held back for the top-region experiment
//  {"Free 26", 0xF9280000, 0x00D80000, AddMem, SYS_MEM, SYS_MEM_TESTED, Conv, WRITE_BACK_XN},
  // [k70u-3g 2026-11-02] held back for the top-region experiment
//  {"Free 27", 0xFD800000, 0x000DF000, AddMem, SYS_MEM, SYS_MEM_TESTED, Conv, WRITE_BACK_XN},
    // [k70u-lo4g 2026-11-02] Clipped at 4 GiB: the DXE pool took a block from the
  // 13 GiB range and the store raised an address size fault, so keep every
  // region inside the range the firmware demonstrably reaches.
  // [k70u-3g 2026-11-02] held back for the top-region experiment
//  {"Free 28", 0xFFFFF000, 0x00001000, AddMem, SYS_MEM, SYS_MEM_TESTED, Conv, WRITE_BACK_XN},
  //
  // [k70u 2026-11-04] Above 4 GiB, DISABLED again.  Mapping the four regions
  // /proc/iomem reports (4.25 + 4 + 11.2 + 0.8 GiB) made the firmware fault, so
  // the old "[k70u-lo4g]" warning was right: this build cannot reach them, most
  // likely because the DXE translation tables only cover the low range.
  // DarwinBoot copes by halving its window instead (see AllocateWindow).
  //
  // [k70u-lo4g 2026-11-02] Above 4 GiB, temporarily excluded:
  //{"Free 29", 0x1C0000000, 0x17D600000, AddMem, SYS_MEM, SYS_MEM_TESTED, Conv, WRITE_BACK_XN},
  // [k70u-lo4g 2026-11-02] Above 4 GiB, temporarily excluded:
  //{"Free 30", 0x33FE41000, 0x0017D000, AddMem, SYS_MEM, SYS_MEM_TESTED, Conv, WRITE_BACK_XN},

  // FDT-described GICv3 register windows.
  {"GIC Distributor",   0x0C400000, 0x00040000, AddDev, MMAP_IO, UNCACHEABLE, MmIO, NS_DEVICE},
  //
  // [k70u-fix 2026-11-02] MTK watchdog registers, used to force a watchdog
  // reset (a PSCI SYSTEM_RESET behaves like a cold boot here and wipes DRAM,
  // which loses the pstore buffer). WDT_LENGTH is at +4, WDT_RESTART at +8.
  //
  {"Watchdog",        0x1C00B000, 0x00001000, AddDev, MMAP_IO, UNCACHEABLE, MmIO, NS_DEVICE},
  {"GIC Redistributors",0x0C440000, 0x00200000, AddDev, MMAP_IO, UNCACHEABLE, MmIO, NS_DEVICE},
  //
  // [k70u 2026-11-02] MT6989 pinctrl / GPIO block. Volume Up on rothko is
  // GPIO 196 (0xC4, active low) per the stock DTBO fragment@19 /volup-key,
  // and GpioDxe finds this window by the name "Pinctrl". DT node
  // /pinctrl@10005000, reg[0] "gpio" = 0x10005000 + 0x1000.
  //
  {"Pinctrl", 0x10005000, 0x1000, AddDev, MMAP_IO, UNCACHEABLE, MmIO, NS_DEVICE},
  //
  // [k70u 2026-11-02] SPMI PMIF controller (DT spmi@1cc04000, reg-names "pmif").
  // Register 0x070 bit0 is the power-key event flag: it goes 0 -> 1 when the key
  // is pressed and clears itself shortly after. Reading it is enough to detect
  // the power key, so no SPMI transaction is needed (MT6989's PMIF command
  // offsets are computed at runtime, unlike the old pwrap window this tree ships).
  //
  {"PMIF", 0x1CC04000, 0x1000, AddDev, MMAP_IO, UNCACHEABLE, MmIO, NS_DEVICE},
  //
  // [k70u-fix 2026-11-02] Display plumbing for RothkoDisplayDxe.
  // The MMIO windows below are the ones the driver probes (MMSYS, the two
  // MUTEX banks, OVLSYS0/1, DISPSYS1, DSC0, DSI0) and were validated on
  // dali (MT6991) and against the stock LK handoff for rothko.
  // Display Reserved is the framebuffer carveout LK hands over in
  // atag,videolfb: base 0xFD91F000, size 0x26E0000 (1220x2712, 32bpp).
  //
  {"Display MMSYS", 0x14000000, 0x1000, AddDev, MMAP_IO, UNCACHEABLE, MmIO, NS_DEVICE},
  {"MUTEX DISPSYS0", 0x14001000, 0x1000, AddDev, MMAP_IO, UNCACHEABLE, MmIO, NS_DEVICE},
  {"Display DISPSYS1", 0x14200000, 0x1000, AddDev, MMAP_IO, UNCACHEABLE, MmIO, NS_DEVICE},
  {"MUTEX DISPSYS1", 0x14201000, 0x1000, AddDev, MMAP_IO, UNCACHEABLE, MmIO, NS_DEVICE},
  {"DSC0", 0x14206000, 0x1000, AddDev, MMAP_IO, UNCACHEABLE, MmIO, NS_DEVICE},
  {"DSI0", 0x1420A000, 0x1000, AddDev, MMAP_IO, UNCACHEABLE, MmIO, NS_DEVICE},
  {"Display OVLSYS0", 0x14400000, 0x10000, AddDev, MMAP_IO, UNCACHEABLE, MmIO, NS_DEVICE},
  {"Display OVLSYS1", 0x14600000, 0x10000, AddDev, MMAP_IO, UNCACHEABLE, MmIO, NS_DEVICE},
  {"MIPI TX0", 0x11E90000, 0x1000, AddDev, MMAP_IO, UNCACHEABLE, MmIO, NS_DEVICE},
  //
  // [k70u 2026-11-02] UFS host controller windows, taken from the stock device
  // tree. MtkUfsDxe needs all four: the PHY and the HCI for the transport, plus
  // TOPCKGEN and INFRACFG_AO because the driver gates the UFS clocks itself.
  //
  // Without these the very first register write (INFRA_AO2_CG_CLR at
  // 0x100010a8) takes a translation fault and the driver dies with
  // "Data abort: Translation fault, third level".
  //
  {"TOPCKGEN", 0x10000000, 0x1000, AddDev, MMAP_IO, UNCACHEABLE, MmIO, NS_DEVICE},
  {"INFRACFG AO", 0x10001000, 0x1000, AddDev, MMAP_IO, UNCACHEABLE, MmIO, NS_DEVICE},
  {"UFS PHY", 0x112A0000, 0x10000, AddDev, MMAP_IO, UNCACHEABLE, MmIO, NS_DEVICE},
  // 0x2a00 is the DT window size but is not page aligned, so the MMU
  // refuses it ("RegionStart ... are not page aligned"). Map 0x3000 and keep
  // the driver-side bound at 0x2a00.
  {"UFS HCI", 0x112B0000, 0x3000, AddDev, MMAP_IO, UNCACHEABLE, MmIO, NS_DEVICE},
  {"UFS AO", 0x112B8000, 0x1000, AddDev, MMAP_IO, UNCACHEABLE, MmIO, NS_DEVICE},
  {"UFS PDN", 0x112BB000, 0x1000, AddDev, MMAP_IO, UNCACHEABLE, MmIO, NS_DEVICE},
  {"Display Reserved", 0xFD91F000, 0x26E0000, AddMem, MEM_RES, SYS_MEM_TESTED, Reserv, WRITE_THROUGH},

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
