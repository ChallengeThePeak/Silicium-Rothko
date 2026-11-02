# 菜单空框的两个原因（2026-11-02 17:22）

## 现象
屏幕能显示 `[Volume Up] Boot Manager`（说明 GOP 控制台正常），按音量上后
`EnterBootManager = 1`、`[Bds]Booting BootManagerMenuApp` 都正常，但**看不到菜单**，
只有一片绿色/灰色区域。

## 原因一：启动项全是空的，菜单没有条目可画

`MsBootOptionsLibRegisterDefaultBootOptions()`（`SiliciumPkg/Library/MsBootOptionsLib`）：

```c
RegisterFvBootOption (&gMsBootPolicyFileGuid,            L"Internal Storage", ...);  // MsBootPolicy
RegisterFvBootOption (&gMsBootPolicyFileGuid,            L"USB Storage",      ...);  // MsBootPolicy
RegisterFvBootOption (FixedPcdGetPtr (PcdUfpLoaderFile), L"FFU Mode",         ...);  // UFPLoader
```

`PcBdsPkg/MsBootPolicy` 和 UFP loader **都不在这棵树里**，三次注册全部失败：

```
CreateFvBootOption: Failed to Read EFI Application Section from q! Status = Not Found
RegisterFvBootOption: Failed to Create a New FV Boot Option! Status = Not Found   (x3)
```

于是 `EfiBootManagerGetLoadOptions(LoadOptionTypeBoot)` 返回 0 项，
`BootManagerMenuApp` 的 `BootMenuData.ItemCount == 0`——菜单框架照画，条目一个没有，
音量上也就没有可移动的对象。

**修法**：注册这棵树里真实存在的启动应用 `UniXNU`
（`SiliciumPkg/Applications/UniXNU/UniXNU.inf`，FILE_GUID
`9B665204-A133-47A2-9396-9E2B370A4E25`，已在 FV 中）。

## 原因二：`BdsSetConsoleMode(TRUE)` 把控制台拆了

`BootManagerMenuApp` 在画菜单前调用 `BdsSetConsoleMode(TRUE)`：

```c
NewHorizontalResolution = mSetupHorizontalResolution;   // PcdSetupVideoHorizontalResolution
NewVerticalResolution   = mSetupVerticalResolution;     // PcdSetupVideoVerticalResolution
...
for (ModeNumber = 0; ModeNumber < MaxGopMode; ModeNumber++) {
  ... if (匹配到 NewHorizontalResolution/NewVerticalResolution) { ... }
}
// 匹配不到 -> 走「分辨率变化，重启整个控制台驱动」分支
```

`rothko.dsc` 从来没配过这四个 PCD，值都是 **0**，所以永远匹配不到任何 GOP 模式，
必然进入重启控制台的分支：控制台被拆掉重建，菜单随后画到失效的设备上。

**修法**（`rothko.dsc`，新增 `[PcdsPatchableInModule]` 段——DEC 里这几个 PCD 的类型是
PatchableInModule，放 FixedAtBuild 会报 #3000）：

```
PcdSetupVideoHorizontalResolution = 1220
PcdSetupVideoVerticalResolution   = 2712
PcdSetupConOutColumn              = 152     (1220 / 8)
PcdSetupConOutRow                 = 142     (2712 / 19)
```

这样 `NewHorizontalResolution/VerticalResolution` 与当前 GOP 模式一致，
并且与 `SimpleTextOut->QueryMode` 报的 152x142 一致，直接走 “Do nothing” 分支。

## 顺带两处

1. **诊断填充改黑**：`RothkoDisplayDxe` 装 GOP 后把整屏涂成 `0xFF102030`（深蓝探针，
   用来证明 OVL→DSC→DSI 推帧通）。显示早已验证，改成 `0xFF000000`，屏幕从纯黑开始。
2. **超时 3 s → 10 s**：`PcdPlatformBootTimeOut`。3 秒内要看清
   `[Volume Up] Boot Manager` 并按下音量上太赶。

## 产物

| 文件 | SHA-256 |
| --- | --- |
| `bringup/boot-k70u-uefi-menu3-20261102.img` | `799daf6b98dc0018edaddcdec691f597dac10eac805bfe79ba2f41c8acc41f85` |
| `bringup/init_boot-k70u-uefi-menu3-20261102.img` | `933acc535d2fe935069346b041c31500acf2884a535694d9ae2b9dc3f0cbc853` |
| `bringup/SILICIUM_UEFI-menu3-20261102.fd` | `7188f1a52634bae18a85e12d412cedbbf6fed16cccde26a41c2284025af63b7b` |

`0052 Images Verified`。
