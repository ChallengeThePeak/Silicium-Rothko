# 00 — 源码与镜像审计（rothko / MT6989）

日期：2026-10-22
工作区：`D:\漏洞\UNIXNU\适配K70U`（不修改 `../` 下的 yunluo 基线）

## 1. 上游版本（已实测）

| 仓库 | 位置 | 版本 / HEAD | 说明 |
|---|---|---|---|
| Mu-Silicium | `src/Mu-Silicium` | `42fe563791e51bf5500c2e470ed294ca0c94b97c`（2026-10-21） | 与 yunluo 基线同一 commit |
| Xiaomi kernel | `src/Xiaomi_Kernel_OpenSource-rothko` | `197c453d27da88f3b7b8fed7323ee6d15fc02066`，分支 `bsp-rothko-u-oss` | 浅克隆 + sparse checkout |
| uefi-sheng（仅复用 BootShim.S） | `../src/uefi-sheng` | 只读引用 | BootShim 会清 cache，比 Mu-Silicium main 的副本新 |
| uefi-yunluo（结构参考） | `../src/uefi-yunluo` | 只读引用 | 只抄板级包结构，不抄 SoC 数值 |

## 2. Mu-Silicium 的 MediaTek 支持范围（源码确认）

```
Silicon/MediaTek/
├── MediaTekPkg/         公共：Clock/Gpio/PmicWrapper/Msdc 驱动 + RamManagerLib
├── MT6768Pkg/           MT6768 专用实现
└── MT6789Pkg/           MT6789 专用实现（v3.8 新增）
```

- **没有 MT6989 / rothko**；`Status.md` 中也无对应设备条目。
- MT6789Pkg 的 `ClockImplLib / GpioImplLib / MsdcImplLib / PmicWrapperImplLib / PlatformSecLib`
  全部是 MT6789 专用值，**不能**用于 MT6989。
- 可复用的只有：`MediaTekPkg/Library/RamManagerLib`、`SiliciumPkg` 的 SEC/GIC/timer/显示框架、
  yunluo 工作区里验证过的通用补丁（SEC 入口保存 x0、cache 维护、GOP/console alpha 等）。

## 3. 小米内核分支的重要发现（与 handoff 假设不符）

`bsp-rothko-u-oss` 的树里 **没有** MTK BSP：

- 无 `drivers/misc/mediatek`
- 无 `arch/arm64/boot/dts/mediatek/mt6989*`
- `arch/arm64/boot/dts/mediatek` 只有 92 个上游通用 DTS 文件
- 全树 `git ls-tree -r` 搜索 `mt6989` / `rothko` 命中 0

结论：这个分支是 Android GKI 公共内核树，Redmi K70 Ultra 的 MTK BSP 源码不在其中。
因此本轮 UEFI 的硬件数据全部来自**原厂镜像里的运行时 DTB**（见下）。
后续如果需要 UFS/显示驱动行为细节，要另外找 Xiaomi 的 MTK BSP 仓库（待办，不阻塞 UEFI）。

## 4. 原厂镜像审计（已实测）

来源：

- `C:\Users\Administrator\Downloads\rothko_images_OS1.0.22.0.UNNCNXM_20240808.0000.00_14.0_cn_197c33cf17\...\images`
- `I:\rothko_factory_images_FACTORY_ROTHKO_0820_debug_20240820_0000_00\...\images`
  （factory 包额外带 `preloader_rothko.bin.i64` 等 IDA 数据库）

解析结果：

| 项 | 值 | 证据 |
|---|---|---|
| boot.img | header v4，page 4096，kernel 0xF89357 字节，**LZ4**（`02 21 4c 18`），ramdisk 0 | 脚本解析 |
| vendor_boot.img | header v4，cmdline `bootopt=64S3,32N2,64N2`，kernel_addr `0x40000000`，ramdisk_addr `0x66F00000`，tags_addr/dtb_addr `0x47C80000`，dtb 0x6C7C7 | 脚本解析 |
| dtbo.img | 1 个 entry，DTB 0x1BE16 字节 | 脚本解析 |
| LK | 支持 gzip inflate 与 lz4 解压；内嵌同一份 DTB/DTBO；`videolfb`/`fb_pa` 字符串存在 | lk.img 字符串 |
| 面板 | `n12_42_02_0a_dsc_cmd` / `n12_36_02_0b_dsc_cmd` | lk.img 字符串 |

## 5. 从原厂 DTB 读出的硬件表（源码/数据确认）

来源：`work/extracted/vendor_boot_dtb0.dtb`（444 KB）+ `dtbo_entry0.dtb`

| 子系统 | 值 | 证据 |
|---|---|---|
| GIC | GICv3；GICD `0x0C000000` size `0x400000`；GICR `0x0C400000` size `0x40000` + `0x0C440000` size `0x200000` | `/interrupt-controller@c400000`, `/gic500@c000000` |
| Timer | `arm,armv8-timer`，`clock-frequency = 0xC65D40` = **13 MHz** | `/timer` |
| PSCI | `arm,psci-1.0`，method `smc` | `/psci` |
| CPU | 8 核 / 3 cluster；MPIDR 0x0,0x100,0x200,0x300 / 0x400,0x500,0x600 / 0x700 | `/cpus` |
| 内存 | `/memory@40000000` 只声明 1 GB（占位，LK 运行时修正） | `/memory@40000000` |
| UFS | HCI `0x112B0000` size `0x2A00`，compatible `mediatek,mt8183-ufshci`，16 个 clock，3 个 reset | `/ufshci@112b0000` |
| UART | `0x11001000` / `0x11002000` / `0x11003000` / `0x11004000`，`mediatek,mt6577-uart` | `/serial@...` |
| Watchdog | `0x1C00B000`（**不是** MT6789 的 `0x10007000`） | `/watchdog@1c00b000` |
| PMIC | MT6363（SPMI）；`MT6358PmicDxe` 不适用 | `/mt6363-*` 节点 |
| 显示 | `mtkfb@0` 无固定 reg；OVL 在 `0x14402000/0x14403000/0x14404000`，disp1 在 `0x14602000...` | `/mtkfb@0`, aliases |
| Framebuffer | 静态 DTB 中**没有** fb_base/vramSize；由 LK 运行时写入 ATAG/DTB | `/chosen` 只有 bootargs |

## 6. 代码分类

| 分类 | 内容 | 本阶段处理 |
|---|---|---|
| SoC-common | `MediaTekPkg/Library/RamManagerLib`、SiliciumPkg 的 SEC/GIC/timer/GOP/BDS | 复用 |
| MT6989 专用 | GIC 地址、核数、timer 频率、watchdog、PMIC/clock/UFS | 新建 `MT6989Pkg`（本轮只做 SEC + 内存表） |
| MT6789-only | `MT6789Pkg/*`、`MT6358PmicDxe`、`MsdcDxe` | 不复用数值 |
| Qualcomm / Apple | 其余 | 不涉及 |

## 7. 许可证

- Mu-Silicium / SiliciumPkg / 新建 MT6989Pkg：BSD-2-Clause-Patent。
- 小米内核（GPL-2.0）本轮未复制任何代码；只从镜像/DTB 读取硬件事实。
