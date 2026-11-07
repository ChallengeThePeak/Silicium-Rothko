# Rothko UEFI Platform

Device platform for the Xiaomi Redmi K70 Ultra (`rothko`, MT6989).

`DeviceBuild.py` exposes this package to `stuart` and adds the sibling
`UniXNU/package` directory to the EDK II package search path. The platform
uses reviewed MT6989 paths; inactive inherited constants do not establish
support for their original hardware targets.

## Platform components

- `UniXNUComponents.dsc.inc` and `UniXNUComponents.fdf.inc` register the
  UniXNU application, registrar and initrd block driver.
- `rothko.dsc` and `rothko.fdf` build the 2 MiB firmware volume at
  `0x40400000`.
- `Drivers/RothkoDisplayDxe` publishes the board display and the active CMD
  framebuffer path.
- `Drivers/RothkoHighMemDxe` publishes the MT6989 high-memory ranges.
- `Drivers/RothkoWatchdogDxe` handles the board watchdog.
- `Drivers/MtkUfsDxe` provides the bounded MT6989 UFS transport.
- `Library/MemoryMapLib` maps the live LK mblock free extents while excluding
  UEFI, BootShim, DTB and initrd ranges.
- `Library/KeypadDeviceLib` and `Library/GpioImplLib` provide the three-key
  physical input route.

## UFS policy

The current UFS interfaces have several write restrictions:

- the device refclk property is preserved;
- the device-reset and refclk SMC paths are disabled;
- PHY power-on programming is skipped before any MMIO write;
- the UFS Device Config protocol is not published to applications;
- the retained filter rejects FORMAT UNIT, WRITE(6/10/12/16), WRITE BUFFER,
  UNMAP and SECURITY PROTOCOL OUT; other opcodes are still forwarded;
- the published Block I/O interface is marked read-only.

The filter is not a complete write prohibition: WRITE SAME, for example, is
not rejected at this boundary. PreHce still sends RTFF SMC BIT9 off/on and
changes host HCI/options and link state despite the separate PHY/reset/refclk
switches. No same-run evidence establishes those paths caused BROM.

The unx18 FD build passed offline. That build does not qualify later source
edits. UFS command completion, DMA behavior, complete storage-command policy
and a post-BROM hardware run remain open.

## Device assumptions

The memory map and FD placement come from the OS3.0.303 FDT and live LK mblock
snapshot used during K70U bring-up. Re-capture and compare those inputs before
using this platform with another LK or Android release.

The v4 vendor-ramdisk prefix is measured as `0x02719743`. The initrd size PCD
must match the sector-aligned FAT image used by the matching device build.
Never expose the vendor ramdisk table or its envelope as a filesystem.

## Build entry point

```sh
python3 Platforms/Xiaomi/rothkoPkg/DeviceBuild.py \
  TARGET=DEBUG \
  ENABLE_SECUREBOOT=0 \
  FD_BASE=0x40400000 \
  FD_SIZE=0x200000 \
  FD_BLOCKS=0x200 \
  DEVICE_MODEL=0 \
  DISABLE_DEBUG_MACRO_CHECK=TRUE
```

See the repository root README for submodule setup, the matching
`UniXNU-rothko` package layout and the current verification boundary.
