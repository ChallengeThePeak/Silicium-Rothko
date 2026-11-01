# Rothko UEFI Platform

This package is the device-specific integration point for UniXNU on the
Redmi K70 Ultra (MT6989). `DeviceBuild.py` exposes it to the repository build
driver and adds the sibling `UniXNU/package` directory to EDK II package
search paths. It intentionally does not inherit MT6789 platform register
settings or Qualcomm platform code.

## Current integration

- `UniXNUComponents.dsc.inc` lists the UniXNU application, registrar, and
  initrd block driver.
- `UniXNUComponents.fdf.inc` places those modules in the firmware volume.
- `rothko.dsc` and `rothko.fdf` provide the platform DSC/FDF integration.
- `MemoryMapLib` maps only the live LK mblock free extents, with UEFI,
  BootShim, DTB, and initrd ranges carved out; gaps and reserved extents stay
  unmapped.
- `UniXNUConfig.dsc.inc` sets the measured v4 vendor-ramdisk prefix as the
  initrd disk offset. Set its size PCD to the exact sector-aligned FAT image
  size when that image is produced; zero intentionally disables publication.

The layout is a host-build starting point, not yet a qualified boot image.

## Build gates before a bootable FD

1. The current memory map and FD placement are a static snapshot of the
   connected device's OS3.0.303 FDT and LK mblock state. Re-capture and compare
   them before using this config with another LK/OS build.
2. Set the initrd size to the exact FAT image inside the v4 initrd envelope.
   The offset is currently measured as `0x02719743`. Do not expose the
   envelope or vendor ramdisk table as a disk.
3. Qualify MT6989 SEC, GICv3, and timer setup. The stock FDT is evidence for
   resource locations, not proof that inherited firmware state is safe to
   reuse or reinitialize.
4. Build the host FD, then validate the packed v4 image and its ranges before
   any device test. This package does not authorize flashing.
