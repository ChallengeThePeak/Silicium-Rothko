# 菜单自动进入 + 音量键（2026-11-02）

## 一、菜单出不来的真根因

之前日志里那句 `K70U-BDS: no boot option registered, parking for the watchdog`
**是无条件打印的假结论**，而且当时插进去的 `CpuDeadLoop()` 位置错了：

```c
// Mu_Basecore/MdeModulePkg/Universal/BdsDxe/BdsEntry.c:972 附近（旧）
PlatformBootManagerAfterConsole ();
  ...
  DEBUG (("K70U-BDS: no boot option registered, parking for the watchdog"));
  CpuDeadLoop ();        // ← 插在这里
  // 下面整段 BootOrder 遍历、PriorityBoot、BootManagerMenu 注册全部没跑
```

`PlatformBootManagerPriorityBoot()`、启动项遍历、`BmRegisterBootManagerMenu()`
全部在它**后面**，所以 BDS 从来没有真正尝试过启动任何东西，菜单自然也不会注册。

### 修复
1. 删除该 `CpuDeadLoop()` 块（`BdsEntry.c`）。
2. `SiliciumPkg/Library/BootManagerLib/BootManager.c` 的
   `PlatformBootManagerPriorityBoot()` 增加回退：

```c
BootManagerFlag = EnterBootManager ();          // 音量上热键
if (BootManagerFlag == FALSE) {
  BootOptions = EfiBootManagerGetLoadOptions (&BootOptionCount, LoadOptionTypeBoot);
  if (BootOptionCount == 0) {                   // BootOrder 里没有任何可启动项
    DEBUG (("K70U-BDS: BootOrder is empty, entering Boot Manager menu"));
    BootManagerFlag = TRUE;                     // 直接进菜单
  }
}
```

Boot Manager Menu 本身是独立的 load option，**不在 BootOrder 里**，所以
`BootOptionCount == 0` 精确表达“没东西可启动”，不会误判。

菜单 FFS 的 GUID 与 `PcdBootManagerMenuFile` 完全一致
（`EEC25BDC-67F2-4D95-B1D5-F81B2039D11D`），`SetupBrowserDxe` 也在 FV 里，
所以 BDS 现在能找到并启动它。

## 二、rothko 按键实锤（纯离线，DTBO）

来源：`work/extracted/dtbo_entry0.txt`（stock DTBO overylay）+ `work/extracted/lk_fdt0.txt`（LK 展开的 FDT）

```
/fragment@19  (target = /gpio_keys)
  /volup-key
      label = "Volume_Up"
      gpios = <&pio 0xC4 0x1>        → MTK GPIO 196，GPIO_ACTIVE_LOW
      linux,code = 0x73              → KEY_VOLUMEUP
      debounce-interval = 32
/fragment@20
  /key-default/pinkey
      pinmux = <0xc400>              → pin 0xC4，function 0（纯 GPIO）
      input-enable, bias-pull-up     → LK 已配好输入+上拉，UEFI 只读即可

/mt6363keys  compatible = "mediatek,mt6363-keys"
  /power   linux,keycodes = 0x74     → KEY_POWER
  /home    linux,keycodes = 0x73     → 与 volup 重复，疑为模板残留；
                                       实际应为音量下（待设备侧 getevent 确认）
```

对比 **yunluo**（`D:\漏洞\YunluoUEFI-MU\repo\Platforms\Xiaomi\yunluoPkg\Library\KeypadDeviceLib`）：

| 键 | yunluo | rothko（DT 实锤） |
| --- | --- | --- |
| 音量上 | PMIC Home | **MTK GPIO 196** |
| 音量下 | GPIO 66 | MT6363 `/home`（待确认） |
| 电源 | PMIC Power | MT6363 `/power` |

两者**不是同一套接法**，不能照抄。

补充确证：rothko 的 DT 里**没有** `mediatek,kpd` 节点，也**没有** i2c GPIO expander
（搜 `aw9523|tca95|pcal|gpio-expander` 均 0 命中），所以按键只有 GPIO + MT6363 两条路。

## 三、本轮实现

| 位置 | 内容 |
| --- | --- |
| `MemoryMapLib.c` | 新增 `{"Pinctrl", 0x10005000, 0x1000, AddDev, MMAP_IO, ...}`（与 stonePkg 同值，DT `/pinctrl@10005000` reg[0] 一致） |
| `rothkoPkg/Library/GpioImplLib` | MT6989 GPIO 布局：dir +0x000 / dout +0x100 / din +0x200 / mode +0x300，`MaxPin = 251`（DT `gpio-ranges` = 0xFB） |
| `rothkoPkg/Library/KeypadDeviceLib` | 音量上 = GPIO 196（低有效）；PMIC 按键**可选**，缺失只告警不影响 GPIO |
| `rothko.dsc` | `[Packages]` 加 `MediaTekPkg`；LibraryClasses 映射 GpioImplLib / KeypadDeviceLib；Components 加 GpioDxe / KeypadDeviceDxe / KeypadDxe |
| `DXE.inc` | 三个 INF 进 FV |

链路：`GpioDxe`（gMediaTekGpioProtocol）→ `KeypadDeviceDxe`（gKeypadDeviceProtocol + 设备路径）
→ `KeypadDxe`（SimpleTextIn + SimpleTextInputEx）→ `BootManagerLib/KeyCallback.c`
注册 `SCAN_UP` notify → 进菜单。

## 四、封装核对

`0052 Images Verified`（上版 0049，+3 = 三个驱动）。FVMAIN.inf 中：

```
1795051D-...GpioDxe
f5d8b2e6-...KeypadDeviceDxe
b112ad46-...KeypadDxe
EEC25BDC-...BootManagerMenuApp
EBf342FE-...SetupBrowser
```

## 五、未完成：PMIC 按键（音量下 / 电源）

MT6989 用的是 **SPMI/PMIF**（DT `spmi@1cc04000`，reg-names "pmif"），
而树里的 `PmicWrapperDxe` + `PmicWrapperImplLib` 是**老 pwrap 布局**
（参考值：stonePkg 0x10026000 / lancelotPkg 0x1000D000，寄存器 0x880 WACS2_CMD）。

`MT6358PmicDxe` 的寄存器也不匹配 MT6363：
- MT6358：`TOPSTATUS = 0x28`，PWRKEY = BIT1，HOMEKEY = BIT3
- MT6363：从 `mtk-pmic-keys.ko` 的 `mt6363_regs` 数据解出 `TOPSTATUS = 0x1E`，
  `keys_regs` 步长 0x10（press_reg / press_mask / release_reg / release_mask），
  两个键的 press_mask 分别是 0x1 和 0x3

要打通需要新写一个 PMIF/SPMI 访问层（或确认 MT6989 是否仍保留老 pwrap 窗口），
风险较高（`InitPmicWrapper` 在 init_done != 1 时会 `ASSERT_EFI_ERROR` 直接停机）。
本轮先不引入。

**设备在线时的验证命令**（确认音量下到底走哪）：
```
adb shell getevent -i          # 看 mt6363-keys / gpio-keys 的 KEY 能力
adb shell getevent -l          # 分别按音量下、音量上、电源，看上报的节点与 code
```

## 六、产物

| 文件 | SHA-256 |
| --- | --- |
| `bringup/boot-k70u-uefi-menu-key-20261102.img` | `7e6cb010b74faeb0b17c4ba169952e7158e6e9d2d9dd678e7729f6396d4993e1` |
| `bringup/init_boot-k70u-uefi-menu-key-20261102.img` | `933acc535d2fe935069346b041c31500acf2884a535694d9ae2b9dc3f0cbc853` |
| `bringup/SILICIUM_UEFI-menu-key-20261102.fd` | `275b24bfaaed280eecaef931acb70c5c3d4af54b334f33caef243f70df2af298` |

未实机验证；刷写由用户执行。
