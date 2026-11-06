INF MdeModulePkg/Core/Dxe/DxeMain.inf
INF MdeModulePkg/Universal/PCD/Dxe/Pcd.inf
INF ArmPkg/Drivers/CpuDxe/CpuDxe.inf
INF ArmPkg/Drivers/ArmGicDxe/ArmGicDxe.inf
INF ArmPkg/Drivers/TimerDxe/TimerDxe.inf
INF MdeModulePkg/Core/RuntimeDxe/RuntimeDxe.inf
INF MdeModulePkg/Universal/ReportStatusCodeRouter/RuntimeDxe/ReportStatusCodeRouterRuntimeDxe.inf
INF MdeModulePkg/Universal/StatusCodeHandler/RuntimeDxe/StatusCodeHandlerRuntimeDxe.inf
INF MdeModulePkg/Universal/Variable/RuntimeDxe/VariableRuntimeDxe.inf
INF EmbeddedPkg/SimpleTextInOutSerial/SimpleTextInOutSerial.inf
INF EmbeddedPkg/EmbeddedMonotonicCounter/EmbeddedMonotonicCounter.inf
INF EmbeddedPkg/MetronomeDxe/MetronomeDxe.inf
INF EmbeddedPkg/RealTimeClockRuntimeDxe/RealTimeClockRuntimeDxe.inf
INF MdeModulePkg/Universal/DevicePathDxe/DevicePathDxe.inf
INF MdeModulePkg/Universal/SecurityStubDxe/SecurityStubDxe.inf
INF MdeModulePkg/Universal/WatchdogTimerDxe/WatchdogTimer.inf
INF MdeModulePkg/Universal/CapsuleRuntimeDxe/CapsuleRuntimeDxe.inf
INF MdeModulePkg/Universal/Disk/DiskIoDxe/DiskIoDxe.inf
  INF rothkoPkg/Drivers/MtkUfsDxe/MtkUfsDxe.inf
INF MdeModulePkg/Bus/Ufs/UfsPassThruDxe/UfsPassThruDxe.inf
INF MdeModulePkg/Bus/Scsi/ScsiBusDxe/ScsiBusDxe.inf
INF MdeModulePkg/Bus/Scsi/ScsiDiskDxe/ScsiDiskDxe.inf
INF MdeModulePkg/Universal/Disk/PartitionDxe/PartitionDxe.inf
INF MdeModulePkg/Universal/Disk/UnicodeCollation/EnglishDxe/EnglishDxe.inf
INF FatPkg/EnhancedFatDxe/Fat.inf
INF MdeModulePkg/Universal/Console/ConPlatformDxe/ConPlatformDxe.inf
INF MdeModulePkg/Universal/Console/ConSplitterDxe/ConSplitterDxe.inf
INF MdeModulePkg/Universal/Console/GraphicsConsoleDxe/GraphicsConsoleDxe.inf
INF MdeModulePkg/Universal/HiiDatabaseDxe/HiiDatabaseDxe.inf
INF MdeModulePkg/Universal/PrintDxe/PrintDxe.inf
  INF rothkoPkg/Drivers/RothkoDisplayDxe/RothkoDisplayDxe.inf
INF MdeModulePkg/Universal/ResetSystemRuntimeDxe/ResetSystemRuntimeDxe.inf
INF UniXNUPkg/Driver/UniXNUDxe/UniXNUDxe.inf
INF UniXNUPkg/Driver/UniXNURamDiskDxe/UniXNURamDiskDxe.inf
INF UniXNUPkg/Driver/DarwinBoot/DarwinBoot.inf
INF MdeModulePkg/Universal/BdsDxe/BdsDxe.inf
#
# [k70u-fix 2026-11-02] The graphical boot manager. BDS looks the menu up by
# GUID through PcdBootManagerMenuFile, and that GUID is this module's
# FILE_GUID (EEC25BDC-67F2-4D95-B1D5-F81B2039D11D), so putting the INF in
# the FV is what makes the menu appear. SetupBrowserDxe provides the
# FormBrowser2 protocol the menu needs.
#
INF MdeModulePkg/Application/BootManagerMenuApp/BootManagerMenuApp.inf
INF MdeModulePkg/Universal/SetupBrowserDxe/SetupBrowserDxe.inf
#
# [k70u 2026-11-02] Keys: GPIO -> keypad protocol -> SimpleTextInputEx.
# Volume Up (GPIO 196) is what opens the Boot Manager menu.
#
INF MediaTekPkg/Drivers/GpioDxe/GpioDxe.inf
INF rothkoPkg/Drivers/RothkoWatchdogDxe/RothkoWatchdogDxe.inf
INF rothkoPkg/Drivers/RothkoHighMemDxe/RothkoHighMemDxe.inf
INF SiliciumPkg/Drivers/KeypadDeviceDxe/KeypadDeviceDxe.inf
INF SiliciumPkg/Drivers/KeypadDxe/KeypadDxe.inf
INF UniXNUPkg/Application/UniXNU/UniXNU.inf
