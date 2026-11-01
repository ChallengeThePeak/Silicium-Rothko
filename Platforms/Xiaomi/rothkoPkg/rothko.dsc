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

[LibraryClasses]
  MemoryMapLib|rothkoPkg/Library/MemoryMapLib/MemoryMapLib.inf
  UniXNULib|UniXNUPkg/Library/UniXNULib/UniXNULib.inf

[BuildOptions]
  CLANGDWARF:*_*_*_CC_FLAGS = -fno-stack-protector

[BuildOptions.common.EDKII.DXE_RUNTIME_DRIVER]
  CLANGDWARF:*_*_*_DLINK_FLAGS = -z common-page-size=0x10000

!include rothkoPkg/UniXNUConfig.dsc.inc
!include rothkoPkg/UniXNUComponents.dsc.inc
