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
  gEfiMdeModulePkgTokenSpaceGuid.PcdDriverHealthConfigureForm|{0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0}

[LibraryClasses]
  MemoryMapLib|rothkoPkg/Library/MemoryMapLib/MemoryMapLib.inf
  UniXNULib|UniXNUPkg/Library/UniXNULib/UniXNULib.inf

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

!include rothkoPkg/UniXNUComponents.dsc.inc
