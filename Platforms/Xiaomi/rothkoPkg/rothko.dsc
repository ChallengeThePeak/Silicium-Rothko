[Defines]
  PLATFORM_NAME                  = rothko
  PLATFORM_GUID                  = 8F1197D8-03FB-44A6-B1F6-6494A79B2A71
  PLATFORM_VERSION               = 0.1
  DSC_SPECIFICATION              = 0x00010005
  OUTPUT_DIRECTORY               = Build/rothkoPkg
  SUPPORTED_ARCHITECTURES        = AARCH64
  BUILD_TARGETS                  = DEBUG|RELEASE
  SKUID_IDENTIFIER               = DEFAULT
  FLASH_DEFINITION               = rothkoPkg/rothko.fdf
  USE_CUSTOM_DISPLAY_DRIVER      = 1
  USE_PHYSICAL_TIMER             = 1

!include SiliciumPkg/SiliciumPkg.dsc.inc

[PcdsFixedAtBuild]
  gArmTokenSpaceGuid.PcdSystemMemoryBase|0x40000000
  gArmPlatformTokenSpaceGuid.PcdCPUCoresStackBase|0x40600000
  gArmPlatformTokenSpaceGuid.PcdCPUCorePrimaryStackSize|0x40000
  gArmPlatformTokenSpaceGuid.PcdCoreCount|8
  gArmPlatformTokenSpaceGuid.PcdClusterCount|3
  gArmTokenSpaceGuid.PcdGicDistributorBase|0x0C400000
  gArmTokenSpaceGuid.PcdGicRedistributorsBase|0x0C440000
  gSiliciumPkgTokenSpaceGuid.PcdSmbiosSystemManufacturer|"Xiaomi"
  gSiliciumPkgTokenSpaceGuid.PcdSmbiosSystemModel|"Redmi K70 Ultra"
  gSiliciumPkgTokenSpaceGuid.PcdSmbiosSystemRetailModel|"rothko"
  gSiliciumPkgTokenSpaceGuid.PcdSmbiosSystemRetailSku|"ROTHKO"
  gSiliciumPkgTokenSpaceGuid.PcdSmbiosSystemBoardModel|"rothko"
  #
  # [k70u-fix 2026-11-02] BDS asserts at BmDriverHealth.c(553) because the FV has no
  # SetupBrowserDxe, so gEfiFormBrowser2ProtocolGuid is absent. UEFI provides this
  # documented switch: a zero PcdDriverHealthConfigureForm disables the check.
  #
  # [k70u-fix 2026-11-02] Panel geometry validated on dali (MT6991) and on
  # the stock LK handoff for rothko: DSC + DSI command mode, 1220x2712, 32bpp.
  # Stride is the pitch the OVL layer actually uses (1248).
  # Delay 0: the framebuffer console must not slow the log down.
  #
  gSiliciumPkgTokenSpaceGuid.PcdFrameBufferWidth|1220
  gSiliciumPkgTokenSpaceGuid.PcdFrameBufferHeight|2712
  gSiliciumPkgTokenSpaceGuid.PcdFrameBufferColorDepth|32
  gSiliciumPkgTokenSpaceGuid.PcdFrameBufferStride|1248
  gSiliciumPkgTokenSpaceGuid.PcdFrameBufferDelay|0
  #
  # [k70u 2026-11-02] BootManagerMenuApp calls BdsSetConsoleMode(TRUE) before
  # drawing its menu. With these four PCDs left at 0 it looks for a 0x0 GOP
  # mode, fails, and restarts the whole console stack - the menu then draws into
  # a dead device and the screen never shows it. 1220x2712 at 8x19 glyphs is
  # 152x142 text cells.
  #
  #
  gEfiMdeModulePkgTokenSpaceGuid.PcdDriverHealthConfigureForm|{0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0}

[Packages]
  MediaTekPkg/MediaTekPkg.dec

[PcdsPatchableInModule]
  #
  # BootManagerMenuApp 在画菜单前调用 BdsSetConsoleMode(TRUE)，会按这四个 PCD
  # 去找 GOP 模式；留 0 会走到“重启整个控制台驱动”的分支，菜单画到死设备上。
  # 面板 1220x2712，字形 8x19，文本模式即 152x142。
  #
  gEfiMdeModulePkgTokenSpaceGuid.PcdSetupVideoHorizontalResolution|1220
  gEfiMdeModulePkgTokenSpaceGuid.PcdSetupVideoVerticalResolution|2712
  gEfiMdeModulePkgTokenSpaceGuid.PcdSetupConOutColumn|152
  gEfiMdeModulePkgTokenSpaceGuid.PcdSetupConOutRow|142

[LibraryClasses]
  MemoryMapLib|rothkoPkg/Library/MemoryMapLib/MemoryMapLib.inf
  GpioImplLib|rothkoPkg/Library/GpioImplLib/GpioImplLib.inf
  KeypadDeviceLib|rothkoPkg/Library/KeypadDeviceLib/KeypadDeviceLib.inf
  UniXNULib|UniXNUPkg/Library/UniXNULib/UniXNULib.inf
  UefiScsiLib|MdePkg/Library/UefiScsiLib/UefiScsiLib.inf

[BuildOptions]
  CLANGDWARF:*_*_*_CC_FLAGS = -fno-stack-protector

[BuildOptions.common.EDKII.DXE_RUNTIME_DRIVER]
  CLANGDWARF:*_*_*_DLINK_FLAGS = -z common-page-size=0x10000

!include rothkoPkg/UniXNUConfig.dsc.inc
[Components]
  #
  # MT6989 display: inherits LK's OVL/DSI chain and drives command-mode frame
  # submission (the dali approach). It is the only GOP producer, so the
  # generic SimpleFbDxe stays excluded via USE_CUSTOM_DISPLAY_DRIVER = 1.
  #
  rothkoPkg/Drivers/RothkoDisplayDxe/RothkoDisplayDxe.inf
  #
  # [k70u 2026-11-02] UFS host controller. Ported from the yunluo (MT6789)
  # board package; the HCI/PHY addresses were re-derived from this board's
  # device tree (UFSHCI 0x112b0000/0x2a00, UFS PHY 0x112a0000). It is what
  # lets the firmware enumerate UFS LU2 and find the cust volume.
  #
  rothkoPkg/Drivers/MtkUfsDxe/MtkUfsDxe.inf
  #
  # [k70u 2026-11-02] UFS storage stack, ported from the yunluo board package.
  # MtkUfsDxe provides the UFS host controller; these three turn it into a
  # BlockIo so PartitionDxe and Fat.efi can expose the cust volume.
  #
  MdeModulePkg/Bus/Ufs/UfsPassThruDxe/UfsPassThruDxe.inf
  MdeModulePkg/Bus/Scsi/ScsiBusDxe/ScsiBusDxe.inf
  MdeModulePkg/Bus/Scsi/ScsiDiskDxe/ScsiDiskDxe.inf
  #
  # [k70u 2026-11-02] Volume Up. GpioDxe publishes the MediaTek GPIO protocol
  # (Volume Up = GPIO 196 per the stock DTBO), KeypadDeviceDxe wraps it into the
  # keypad protocol and KeypadDxe turns that into SimpleTextIn/SimpleTextInputEx,
  # which is what BootManagerLib registers the menu hotkey (SCAN_UP) against.
  #
  MediaTekPkg/Drivers/GpioDxe/GpioDxe.inf
  rothkoPkg/Drivers/RothkoWatchdogDxe/RothkoWatchdogDxe.inf
  rothkoPkg/Drivers/RothkoHighMemDxe/RothkoHighMemDxe.inf
  SiliciumPkg/Drivers/KeypadDeviceDxe/KeypadDeviceDxe.inf
  SiliciumPkg/Drivers/KeypadDxe/KeypadDxe.inf

!include rothkoPkg/UniXNUComponents.dsc.inc
